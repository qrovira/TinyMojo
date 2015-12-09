package TinyMojo::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw/ encode_json decode_json /;
use Mojo::Util qw/ b64_encode b64_decode /;

use Crypt::Passwd::XS 'unix_sha512_crypt';

#
# Authentication and admin bridges
#

sub check_auth {
    my $c = shift;

    return 1 if $c->logged_in;

    $c->bs_flash( danger => $c->l('Not authorized'), class => 'danger' );
    $c->redirect_to('user#login');

    return undef;
}

sub check_admin {
    my $c = shift;

    return 1 if $c->admin;
    
    $c->bs_flash_to(
        danger => $c->l('Not authorized'),
        ($c->logged_in ? 'main#shorten' : 'user#login')
    );

    return undef;
}


#
# Actual actions
#

sub dashboard {
    my ($self) = @_;
    my $offset = $self->param('offset') // 0;
    my $rows = $self->param('rows') // 10;
    $rows = 100 if $rows > 100;

    my $urls = $self->db('Url')->search({
        user_id => $self->session->{user}{id}
    },{
        order_by => { -desc => 'id' },
        offset => $offset,
        rows => $rows,
        cache => 1,
    });

    my %hits = map { $_->url_id => $_->get_column('hits') } $urls->hits;

    $self->stash(
        urls => [ $urls->all ],
        hits => \%hits,
        rows => $rows,
    );
}


sub list_urls {
    my ($self) = @_;
    my $offset = $self->param('offset') // 0;
    my $rows = $self->param('rows') // 10;
    $rows = 100 if $rows > 100;

    my $urls = $self->db('Url')->search({},{
        order_by => { -desc => 'me.id' },
        offset => $offset,
        rows => $rows,
        cache => 1,
        prefetch => [ "user" ],
    });

    my %hits = map { $_->url_id => $_->get_column('hits') } $urls->hits;

    $self->stash(
        urls => [ $urls->all ],
        hits => \%hits,
        rows => $rows,
    );
}

sub logout {
    my ($self) = @_;

    $self->session( user => undef );
    $self->bs_flash_to( success => $self->l('Logged out!'), 'user#login' );
}

sub login {
    my ($self) = @_;
    my $login = $self->param('login');
    my $password = $self->param('password');

    if( $login && $password ) {
        my $user = $self->db('User')->find({ login => $login });

        if( $user && $user->check_password($password) ) {
            my $sdata = { $user->get_inflated_columns };
            delete $sdata->{password};
            $self->session( user => $sdata );
            return $self->bs_flash_to( success => $self->l('Logged in!'), 'user#dashboard' );
        }

        $self->bs_notify( danger => $self->l('Invalid login') );
    }

}

sub signup {
    my $self = shift;
    my $validation = $self->validation;

    return $self->render unless $validation->has_data;

    $validation->required('login')->size(3,30)->like(qr#^[0-9a-z]+$#i)->username_not_taken;
    $validation->required('email')->email;
    $validation->required('password_again')->equal_to('password')
        if $validation->required('password')->password->is_valid;

    return $self->render if $validation->has_error || !$self->valid_recaptcha;

    my %data = %{ $validation->output };
    delete $data{password_again};

    if( my $user = $self->db('User')->create( \%data ) ) {
        my $sdata = { $user->get_inflated_columns };
        delete $sdata->{password};
        $self->session( user => $sdata );
        $self->_send_email_validation;
        $self->bs_flash_to( success => $self->l('User created! Please check your inbox for activation instructions.'), 'user#dashboard' );
    }
    else {
        $self->render->exception;
    }
}

sub activate {
    my $self = shift;
    my $code = $self->param('code');

    if( $code =~ m#^(?<checksum>.+)--(?<data>.+)$# ) {
        my $checksum = Mojo::Util::hmac_sha1_sum( $+{data}, $self->app->secrets->[0] );
        if( $+{checksum} eq $checksum ) {
            my $data = eval { decode_json( b64_decode( $+{data} ) ); };
            if( $data && $data->{email} eq $self->session->{user}{email} ) {
                $self->db('User')->find( $self->session->{user}{id} )->update({ email_verified => 1 });
                return $self->bs_flash_to( success => $self->l('eMail address verified! Thanks!'), 'user#profile' );
            }
        }
    }

    $self->bs_flash_to( danger => $self->l('Wrong activation code'), 'user#profile' );
}

sub profile {
    my ($self) = @_;
    my $sdata = $self->session('user');
    my $user = $self->db('User')->find( $sdata->{id} );

    my $validation = $self->validation;

    unless( $user ) {
        # Something really wrong.. deleted user?
        $self->session( user => undef );
        return $self->bs_flash_to( danger => $self->l('Something wrong, sorry!'), 'user#login' );
    }

    if( $validation->has_data ) {
        $validation->required('login')->like(qr/^\w+$/);
        $validation->required('email')->email;
        $validation->required('password_again')->equal_to('password')
            if $validation->optional('password')->password->is_valid;

        unless( $validation->has_error ) {
            my %values = %{ $validation->output };
            delete $values{password_again};

            my $email_changed = $values{email} ne $user->email;
            $values{email_verified} = 0
                if $email_changed;

            if( $user->update( \%values ) ) {
                $self->_send_email_validation( $user )
                    if( $email_changed );
                my $sdata = { $user->get_inflated_columns };
                delete $sdata->{password};
                $self->session( user => $sdata );
                $self->bs_flash_to( success => $self->l('Profile updated!'), 'user#profile' );
            } else {
                $self->bs_notify( danger => $self->l('Error updating profile') );
            }
        }
    }

    $self->stash( user => $user );

    $self->param( login => $user->login )
        unless $self->param("login");

    $self->param( email => $user->email )
        unless $self->param("email");
}

sub resend_email_validation {
    my $self = shift;
    my $user = $self->db('User')->find( $self->session->{user}{id} );

    $self->_send_email_validation( $user );
    $self->bs_flash_to( success => $self->l('Activation email sent to [_1]. Please check your inbox within a few minutes.'), 'user#profile' );
}


sub _send_email_validation {
    my ($self, $user) = @_;
    my $activation = b64_encode( encode_json( { email => $user->email } ), '' );
    my $checksum = Mojo::Util::hmac_sha1_sum( $activation, $self->app->secrets->[0] );
    $self->stash( activation_token => $checksum."--".$activation );
    $self->mail(
        to       => $user->email,
        subject  => $self->l("Welcome to TinyMojo!"),
        template => 'email/signup',
        type     => 'text/html',
    );
}

1;
