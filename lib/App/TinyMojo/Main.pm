package App::TinyMojo::Main;
use Mojo::Base 'Mojolicious::Controller';

sub redirect {
    my $self = shift;
    my $shorturl = $self->param('shorturl');
    my $id = $self->token_to_id( $shorturl );
    my $sth = $self->db->prepare('SELECT * FROM url WHERE id = ?');

    $sth->execute( $id );

    my $entry = $sth->fetchrow_hashref;

    return $self->render_not_found
        unless $entry;

    if( $self->app->config->{track_visits} ) {
        # Set evil tracking cookie
        my $cookie = $self->cookie('tmt');
        unless($cookie) {
            $cookie = $self->generate_uuid;
            $self->cookie( tmt => $cookie, { expires => time + 3600 * 24 * 365 * 10 } );
        }

        # Log redirect
        my $logsth = $self->db->prepare(<<"EOQ");
INSERT INTO redirect (url_id, visitor_ip, visitor_forwarded_for, visitor_uuid, visitor_ua) VALUES (?,?,?,?,?)
EOQ

        $logsth->execute(
            $id,
            $self->tx->remote_address,
            scalar $self->req->headers->header('X-Forwarded-For'),
            $cookie,
            $self->req->headers->user_agent
        );

    }

    # Redirect
    $self->redirect_to( $entry->{longurl} );
}

sub shorten {
    my $self = shift;
    my $longurl = $self->param('longurl');
    my $sth = $self->db->prepare('INSERT INTO url (longurl, user_id) VALUES (?,?)');
    my $user_id = $self->logged_in ? $self->session('user')->{id} : \"DEFAULT";

    if( $sth->execute($longurl, $user_id ) ) {
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
