package App::TinyMojo::Admin;
use Mojo::Base 'Mojolicious::Controller';

use String::Random;
use Crypt::Passwd::XS 'unix_sha512_crypt';

#
# Authentication and admin bridges
#

sub check_auth {
    my $c = shift;

    return 1 if $c->logged_in;

    $c->bs_flash( danger => $c->loc('Not authorized'), class => 'danger' );
    $c->redirect_to('admin#login');

    return undef;
}

sub check_admin {
    my $c = shift;

    return 1 if $c->admin;
    
    $c->bs_flash( danger => $c->loc('Not authorized'), class => 'danger' );

    if($c->logged_in) {
        $c->redirect_to('main#index');
    }
    else {
        $c->redirect_to('admin#login');
    }

    return undef;
}


#
# Actual actions
#

sub dashboard {
    my ($self) = @_;

    $self->stash(
      rows => $self->db->selectall_arrayref(
        'SELECT id, longurl FROM url ORDER BY id DESC LIMIT 100',
        { Slice => { id => 1, longurl => 2 } }
      )
    );
}


sub list_urls {
    my ($self) = @_;

    $self->stash(
      rows => $self->db->selectall_arrayref(
        'SELECT id, longurl FROM url ORDER BY id DESC LIMIT 100',
        { Slice => { id => 1, longurl => 2 } }
      )
    );
}

sub login {
    my ($self) = @_;

    if( my $login = $self->param('login') ) {
        my $sth = $self->db->prepare('SELECT * FROM user WHERE login = ?');
        $sth->execute( $login );

        if( my $user = $sth->fetchrow_hashref ) {
            my $password = $self->param('password') // "";
            my $salt = (split '\$', $user->{password})[2];
            if( Crypt::Passwd::XS::unix_sha512_crypt($password, $salt) eq $user->{password} ) {
                $self->session( user => $user );
                $self->bs_flash_to( success => $self->loc('Logged in!'), 'admin#dashboard' );
            }
        }
        $self->bs_notify( danger => $self->loc('Invalid login') );
    }
}

sub logout {
    my ($self) = @_;

    $self->session( user => undef );
    $self->bs_flash_to( success => $self->loc('Logged out!'), 'admin#login' );
}

sub profile {
    my ($self) = @_;
    my $user = $self->session('user');

    my $validation = $self->validation;

    if( $validation->has_data ) {
        $validation->required('id')->like(qr/^$user->{id}$/);
        $validation->required('login')->like(qr/^\w+$/);
        $validation->required('password')->size(6,200);
        $validation->required('password_again')->equal_to('password');

        unless( $validation->has_error ) {
            my $salt = String::Random::random_string('s' x 16);
            my $password = Crypt::Passwd::XS::unix_sha512_crypt($self->param('password'), $salt);

            my $sth = $self->db->prepare('UPDATE user SET password = ?, login = ? WHERE id = ?');
            if( $sth->execute( $password, map { $self->param($_) } qw/ login id / ) ) {
                $self->bs_notify( success => $self->loc('Profile updated!') );
            } else {
                $self->bs_notify( danger => $self->loc('Error updating profile') );
            }
        }
    }

    my $sth = $self->db->prepare('SELECT * FROM user WHERE id = ?');
    $sth->execute( $user->{id} );

    if( my $user = $sth->fetchrow_hashref ) {
        $self->stash( user => $user );
        $self->param( login => $user->{login} )
            unless $self->param("login");
    } else {
        # Something really wrong.. deleted user?
        $self->session( user => undef );
        $self->bs_flash_to( danger => $self->loc('Something wrong, sorry!'), 'admin#login' );
    }
}



1;
