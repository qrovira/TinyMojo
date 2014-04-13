package App::TinyMojo;
use Mojo::Base 'Mojolicious';

# Could use Cryp::Skipjack for 64 bit block sizes
use Crypt::Skip32;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Router
  my $r = $self->routes;

  # Configuration
  $self->plugin('config');

  # Database
  $self->plugin( database => { databases => { db => $self->config->{database} } } );

  # Translations
  $self->plugin('wolowitz');
  $self->defaults( language => $self->config->{language} );

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

  # Normal route to controller
  $r->get('/')->to('main#index');

  # Actions
  $r->post('/do/shorten')->to('main#shorten');

  # Admin
  $r->get('/admin/')->to('admin#dashboard');

  # Handle short url
  $r->get('/:shorturl')->to('main#redirect');
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
