package App::TinyMojo::Main;
use Mojo::Base 'Mojolicious::Controller';

sub redirect {
    my $self = shift;
    my $shorturl = $self->param('shorturl');
    my $id = $self->token_to_id( $shorturl );
    my $sth = $self->db->prepare('SELECT * FROM url WHERE id = ?');

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
        my $token = $self->id_to_token( $sth->{mysql_insertid} );
        my $shorturl = $self->url_for( '/'.$token )->to_abs;

        $self->respond_to( 
            json => { json => { shorturl => $shorturl } },
            html => { shorturl => $shorturl },
        );
    } else {
        $self->render_exception;
    }

}



1;
