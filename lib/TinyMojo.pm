package TinyMojo;
use Mojo::Base 'Mojolicious';

# Could use Cryp::Skipjack for 64 bit block sizes
use Crypt::Skip32;

use DBIx::Connector;
use TinyMojo::DB;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Configuration
    $self->plugin('config');

    # Database
    my $dbconf = delete( $self->config->{database} );
    my $connector = DBIx::Connector->new( map { $dbconf->{$_} } qw/ dsn username password / );
    $self->helper( db => sub {
        my ($self, $resultset) = @_;
        my $dbh = TinyMojo::DB->connect( sub { return $connector->dbh } );
        return $resultset ? $dbh->resultset($resultset) : $dbh;
    } );

    # Translations
    $self->plugin('wolowitz');
    $self->defaults( language => $self->config->{language} );

    # Bootstrap helpers
    $self->plugin('BootstrapHelpers', layout => 1);

    # Debugging stuff
    $self->plugin('DevPanels') if $self->config->{debugging};

    # Session secret token
    $self->secrets( delete $self->config->{secrets} );

    # Controller namespace
    $self->routes->namespaces(['TinyMojo::Controller']);

    # Helpers to map IDs to tokens and back
    my $hex_cryptokey = delete $self->config->{crypt_key};
    die "Invalid cryptokey: it should be 20 hexadecimal chars"
        unless $hex_cryptokey =~ m#^[0-9a-f]{20}$#;
    my $cryptokey = pack("H20", $hex_cryptokey);
    $self->helper( id_to_token => sub { _id_to_token(@_, $cryptokey); } );
    $self->helper( token_to_id => sub { _token_to_id(@_, $cryptokey); } );
    $self->helper( short_url => sub {
        my $c = shift;
        my $id = shift;
        return $c->url_for('/'.$c->id_to_token($id))->to_abs;
    } );

    # Helpers for logged in and admin user checks
    $self->helper( logged_in => sub { defined shift->session('user') } );
    $self->helper( admin => sub { my $u = shift->session('user'); defined $u && $u->{admin} } );

    # If we're tracking, provide the UUID generation helper (to use faster iters)
    if( $self->config->{track_visits} ) {
        require Data::UUID::MT;

        my $mt = Data::UUID::MT->new;
        my $next = $mt->iterator;
        $self->helper( generate_uuid => sub { return uc join "-", unpack("H8H4H4H4H12", $next->());  } );
    }

    # Router
    my $r = $self->routes;
    $r->add_shortcut( to_named => sub { return shift->to(@_)->name($_[0]); });

    my $auth_r = $r->under->to( 'user#check_auth' );
    my $admin_r = $r->under->to( 'user#check_admin' );

    # Normal route to controller
    $r->get('/')->to_named('main#index');

    # Actions
    if( $self->config->{allow_anonymous_shorten} ) {
        $r->post('/do/shorten')->to_named('main#shorten');
    }
    else {
        $auth_r->post('/do/shorten')->to_named('main#shorten');
    }

    # User
    $r->route('/user/login')->to_named('user#login');
    $auth_r->get('/user/logout')->to_named('user#logout');
    $auth_r->get('/user/dashboard')->to_named('user#dashboard');
    $auth_r->route('/user/profile')->to_named('user#profile');
    $admin_r->get('/user/admin/list_urls')->to_named('user#list_urls');

    # Handle short url
    $r->get('/:shorturl')->to_named('main#redirect');
}



#
# the shortening wrappers
#

sub _id_to_token {
    my ($self, $id, $key) = @_;

    # So tiny urls can't be sequentially checked
    $id = _encrypt( $id, $key );

    # Now transform int to new url-friendly base
    return _int_to_base_X( $id );
}

sub _token_to_id {
    my ($self, $token, $key) = @_;

    # So tiny urls can't be sequentially checked
    my $int = _base_X_to_int($token);

    # Now transform int to new url-friendly base
    return _decrypt( $int, $key );
}

#
# the real stuff
#

our @BASE = ('a'..'z', 'A'..'Z', '0'..'9', qw/ - _ . /);

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

    while( @intX ) {
        my $d = shift @intX;
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

TinyMojo - URL shortener application

=for markdown [![Build Status](https://travis-ci.org/qrovira/TinyMojo.svg?branch=master)](https://travis-ci.org/qrovira/TinyMojo)

=head1 SYNOPSIS

Small proof of concept L<Mojolicious> app for URL shortening.

The approach taken for the shortening relies entirely on the auto_increment
primary key on the database backend, which avoids all kinds of messy queries
during shortening or lookup.

It also avoids sequentiality on the generated URLs by using L<Crypt::Skip32>.

=head2 DOCKER DEPLOY

Docker files are provided to bootstrap a working Tinymojo, including an image for
the webapp that will run on hypnotoad, and a separate instance for the database,
initialized with empty tables and a I<admin>/I<password> user.

You can manage it via C<docker-compose> (eg. C<docker-compose up -d>).

Remember to update all configuration, session, datbase and user secrets!

=head2 CONFIGURATION

All configuration is done through the default L<Mojolicious::Plugin::Config> plugin,
which you can see on the F<app-tiny_mojo.conf> file.

There you can set the encryption key (10 bytes, 20 hex chars), along with the database settings.

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

      # Block size for Skip32 or Skipjack is 10 bytes. Key in hex.
      crypt_key => '1337b33f0000feeb7331',
      
      # Some site vars
      language => 'en',
      site_name => 'TinyMojo',
      site_mission => 'Short URLs made simple.',

      # Allow non-logged-in users to shorten URLs
      allow_anonymous_shorten => 1, 

      # Enable visitor tracking
      track_visits => 1,
  };

=head1 SHORTENING METHOD

The shortening works like follows:

=over

=item Insert to database, and retrieve the auto_increment $id

=item Encrypt the id using L<Crypt::Skip32>

This assumes 32 bit ints as IDs, but you can switch to 64 bits and L<Crypt::Skipjack>.

=item Apply a naive base change using a hardcoded dictionary of URL-friendly characters

=back

The lookup of shortened URLs is prety straight forward given the above method.

=head1 DATABASE

The database only requires two tables: I<url> and I<user>

=head3 URL table

  CREATE TABLE url (
    id int auto_increment primary key,
    longurl varchar(4096),
    user_id int not null default 0
  );

=head3 User table

  CREATE TABLE `user` (
    id int auto_increment primary key,
    login varchar(255) not null,
    password varchar(512),
    admin bool not null default 0,
  );

=head3 Tracking table

  CREATE TABLE `redirect` (
    id int auto_increment primary key,
    url_id int not null,
    time timestamp not null default current_timestamp,
    visitor_ip varchar(39) not null,
    visitor_forwarded_for varchar(255) default null,
    visitor_uuid varchar(100) default null,
    visitor_ua varchar(1024) default null,
  )

=head1 CAVEATS

All of them. This is just a proof of concept :)

Do not use on the wild under any circumstances.. it does not check pretty much anything.

=cut
