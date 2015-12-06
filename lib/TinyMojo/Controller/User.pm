package TinyMojo::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Crypt::Passwd::XS 'unix_sha512_crypt';

#
# Authentication and admin bridges
#

sub check_auth {
    my $c = shift;

    return 1 if $c->logged_in;

    $c->bs_flash( danger => $c->loc('Not authorized'), class => 'danger' );
    $c->redirect_to('user#login');

    return undef;
}

sub check_admin {
    my $c = shift;

    return 1 if $c->admin;
    
    $c->bs_flash_to(
        danger => $c->loc('Not authorized'),
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
    my $rows = $self->param('rows') // 100;
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
    );
}


sub list_urls {
    my ($self) = @_;
    my $offset = $self->param('offset') // 0;
    my $rows = $self->param('rows') // 100;
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
        hits => \%hits
    );
}

sub logout {
    my ($self) = @_;

    $self->session( user => undef );
    $self->bs_flash_to( success => $self->loc('Logged out!'), 'user#login' );
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
            return $self->bs_flash_to( success => $self->loc('Logged in!'), 'user#dashboard' );
        }

        $self->bs_notify( danger => $self->loc('Invalid login') );
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

    unless( $validation->has_error ) {
        my %data = %{ $validation->output };
        delete $data{password_again};
        if( my $user = $self->db('User')->create( \%data ) ) {
            my $sdata = { $user->get_inflated_columns };
            delete $sdata->{password};
            $self->session( user => $sdata );
            $self->bs_flash_to( success => $self->loc('User created!'), 'user#dashboard' );
        } else {
            $self->render->exception;
        }
    }
}

sub profile {
    my ($self) = @_;
    my $sdata = $self->session('user');
    my $user = $self->db('User')->find( $sdata->{id} );

    my $validation = $self->validation;

    unless( $user ) {
        # Something really wrong.. deleted user?
        $self->session( user => undef );
        return $self->bs_flash_to( danger => $self->loc('Something wrong, sorry!'), 'user#login' );
    }

    if( $validation->has_data ) {
        $validation->required('login')->like(qr/^\w+$/);
        $validation->required('email')->email;
        $validation->required('password_again')->equal_to('password')
            if $validation->optional('password')->password->is_valid;

        unless( $validation->has_error ) {
            my %values = %{ $validation->output };
            delete $values{password_again};
            if( $user->update( \%values ) ) {
                $self->bs_notify( success => $self->loc('Profile updated!') );
            } else {
                $self->bs_notify( danger => $self->loc('Error updating profile') );
            }
        }
    }

    $self->stash( user => $user );

    $self->param( login => $user->login )
        unless $self->param("login");

    $self->param( email => $user->email )
        unless $self->param("email");
}



1;
