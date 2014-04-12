package App::TinyMojo::Main;
use Mojo::Base 'Mojolicious::Controller';

# Could use Cryp::Skipjack for 64 bit block sizes
use Crypt::Skip32;



sub redirect {
    my $self = shift;
    my $shorturl = $self->param('shorturl');
    my $id = $self->_token_to_id( $shorturl );
    my $sth = $self->db->prepare('SELECT * FROM url WHERE id = ?');

    say("shorturl request for $shorturl ($id).");
    $sth->execute( $id );

    if( my $entry = $sth->fetchrow_hashref ) {
        $self->redirect_to( $entry->{longurl} );
    } else {
        $self->render_not_found;
    }
}

sub shorten {
    my $self = shift;
    my $longurl = $self->param('longurl');
    my $sth = $self->db->prepare('INSERT INTO url (longurl) VALUES (?)');

    if( $sth->execute($longurl) ) {
        my $token = $self->_id_to_token( $sth->{mysql_insertid} );
        my $shorturl = $self->url_for( '/'.$token )->to_abs;
        say("shorten request for $longurl (id $sth->{mysql_insertid}), token $token.");

        $self->respond_to( 
            json => { json => { shorturl => $shorturl } },
            html => { shorturl => $shorturl },
        );
    } else {
        $self->render_exception;
    }

}


#
# the shortening wrappers
#

sub _id_to_token {
    my ($self, $id) = @_;

    # So tiny urls can't be sequentially checked
    $id = $self->_encrypt($id);

    # Now transform int to new url-friendly base
    return $self->_int_to_base_X( $id );
}

sub _token_to_id {
    my ($self, $token) = @_;

    # So tiny urls can't be sequentially checked
    my $int = $self->_base_X_to_int($token);

    # Now transform int to new url-friendly base
    return $self->_decrypt( $int );
}

#
# the real stuff
#

our @BASE = ('a'..'z', 'A'..'Z', '0'..'9', qw/ $ - _ . + ! * ' ( ) /);

our %REVERSE = map { $BASE[$_] => $_ } 0..$#BASE;

sub _int_to_base_X {
    my ($self, $int10) = @_;
    my $intX = "";

    while($int10) {
        $intX = $BASE[ $int10 % @BASE ] . $intX;
        $int10 = int( $int10 / @BASE );
    }

    return $intX;
}

sub _base_X_to_int {
    my $self = shift;
    my @intX = split '', shift;
    my $int10 = 0;

    while( my $d = shift @intX ) {
        $int10 *= @BASE;
        return -1 unless exists $REVERSE{ $d };
        $int10 += $REVERSE{ $d };
    }

    return $int10;
}

sub _encrypt {
    my ($self, $int) = @_;
    my $sj = Crypt::Skip32->new($self->config->{crypt_key});

    return unpack "L", $sj->encrypt( pack "L", $int );
}

sub _decrypt {
    my ($self, $int) = @_;
    my $sj = Crypt::Skip32->new($self->config->{crypt_key});

    return unpack "L", $sj->decrypt( pack "L", $int );
}


1;
