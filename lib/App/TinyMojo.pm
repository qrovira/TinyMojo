package App::TinyMojo;
use Mojo::Base 'Mojolicious';

# Could use Cryp::Skipjack for 64 bit block sizes
use Crypt::Skip32;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Configuration
    $self->plugin('config');

    # Database
    $self->plugin( database => { databases => { db => $self->config->{database} } } );

    # Translations
    $self->plugin('wolowitz');
    $self->defaults( language => $self->config->{language} );

    # Bootstrap helpers
    $self->plugin('BootstrapHelpers', layout => 1);

    # Debugging stuff
    $self->plugin('DevPanels') if $self->config->{debugging};

    # Session secret token
    $self->secrets( $self->config->{secrets} );

    # Helpers to map IDs to tokens and back
    $self->helper( id_to_token => \&_id_to_token );
    $self->helper( token_to_id => \&_token_to_id );
    $self->helper( short_url => sub {
        my $c = shift;
        my $id = shift;
        return $c->url_for('/'.$c->id_to_token($id))->to_abs;
    } );

    # Helpers for logged in and admin user checks
    $self->helper( logged_in => sub { defined shift->session('user') } );
    $self->helper( admin => sub { my $u = shift->session('user'); defined $u && $u->{admin} } );

    # Router
    my $r = $self->routes;
    $r->add_shortcut( to_named => sub { return shift->to(@_)->name($_[0]); });
    my $auth_r = $r->bridge->to( 'admin#check_auth' );
    my $admin_r = $r->bridge->to( 'admin#check_admin' );

    # Normal route to controller
    $r->get('/')->to_named('main#index');

    # Actions
    $r->post('/do/shorten')->to_named('main#shorten');


    # Admin
    $r->route('/user/login')->to_named('admin#login');
    $auth_r->get('/user/logout')->to_named('admin#logout');
    $auth_r->get('/user/dashboard')->to_named('admin#dashboard');
    $auth_r->route('/user/profile')->to_named('admin#profile');
    $admin_r->get('/user/admin/list_urls')->to_named('admin#list_urls');

    # Handle short url
    $r->get('/:shorturl')->to_named('main#redirect');
}



#
# the shortening wrappers
#

sub _id_to_token {
    my ($self, $id) = @_;

    # So tiny urls can't be sequentially checked
    $id = _encrypt( $id, $self->config->{crypt_key} );

    # Now transform int to new url-friendly base
    return _int_to_base_X( $id );
}

sub _token_to_id {
    my ($self, $token) = @_;

    # So tiny urls can't be sequentially checked
    my $int = _base_X_to_int($token);

    # Now transform int to new url-friendly base
    return _decrypt( $int, $self->config->{crypt_key} );
}

#
# the real stuff
#

our @BASE = ('a'..'z', 'A'..'Z', '0'..'9', qw/ $ - _ . + ! * ' ( ) /);

our %REVERSE = map { $BASE[$_] => $_ } 0..$#BASE;

sub _int_to_base_X($) {
    my $int10 = shift;
    my $intX = "";

    while($int10) {
        $intX = $BASE[ $int10 % @BASE ] . $intX;
        $int10 = int( $int10 / @BASE );
    }

    return $intX;
}

sub _base_X_to_int($) {
    my @intX = split '', shift;
    my $int10 = 0;

    while( my $d = shift @intX ) {
        $int10 *= @BASE;
        return -1 unless exists $REVERSE{ $d };
        $int10 += $REVERSE{ $d };
    }

    return $int10;
}

sub _encrypt($$) {
    my ($int, $key) = @_;
    my $sj = Crypt::Skip32->new($key);

    return unpack "L", $sj->encrypt( pack "L", $int );
}

sub _decrypt($$) {
    my ($int, $key) = @_;
    my $sj = Crypt::Skip32->new($key);

    return unpack "L", $sj->decrypt( pack "L", $int );
}


1;

=encoding utf8

=head1 NAME

App::TinyMojo - URL shortener application

=head1 SYNOPSIS

Small proof of concept L<Mojolicious> app for URL shortening.

The approach taken for the shortening relies entirely on the auto_increment
primary key on the database backend, which avoids all kinds of messy queries
during shortening or lookup.

It also avoids sequentiality on the generated URLs by using L<Crypt::Skip32>.

=head2 CONFIGURATION

All configuration is done through the default L<Mojolicious::Plugin::Config> plugin,
which you can see on the F<app-tiny_mojo.conf> file.

There you can set the encryption key (10 bytes), along with the database settings.

=head3 Example configuration

  {
      # Database configuration
      database => {
          dsn      => "dbi:mysql:dbname=tinymojo",
          username => "tinymojo",
          password => "tinymojo",
      },

      # Session encryption secret
      secrets => [
          'heregoesyoursecret'
      ],

      # Block size for Skip32 or Skipjack is 10 bytes
      crypt_key => '1234567890',
      
      # Some site vars
      language => 'en',
      site_name => 'TinyMojo',
      site_mission => 'Short URLs made simple.',
  };

=head1 DATABASE

The database only requires two tables: for I<url>s and I<user>s.

=head3 URL table example (MySQL)

  CREATE TABLE url (
    id int auto_increment primary key,
    longurl varchar(4096),
    user_id int not null default 0
  );

  CREATE TABLE `user` (
    id int auto_increment primary key,
    login varchar(255) not null,
    password varchar(512),
    admin bool not null default 0,
  );

=head1 SHORTENING METHOD

The shortening works like follows:

=over

=item 1. Insert to database, and retrieve the auto_increment $id

=item 2. Encrypt the id using L<Crypt::Skip32>

This assumes 32 bit ints as IDs, but you can switch to 64 bits and L<Crypt::Skipjack>.

=item 3. Apply a naive base change using a hardcoded dictionary of URL-friendly characters

=back

The lookup of shortened URLs is prety straight forward given the above method.

=head1 CAVEATS

All of them. This is just a proof of concept :)

Do not use on the wild under any circumstances.. it does not check pretty much anything.

=cut
