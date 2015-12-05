package TinyMojo::Controller::Main;
use Mojo::Base 'Mojolicious::Controller';

sub redirect {
    my $self = shift;
    my $shorturl = $self->param('shorturl');
    my $id = $self->token_to_id( $shorturl );
    my $url = $self->db('Url')->find($id);

    return $self->reply->not_found
        unless $url;

    if( $self->app->config->{track_visits} ) {
        # Set evil tracking cookie
        my $cookie = $self->cookie('tmt');
        unless($cookie) {
            $cookie = $self->generate_uuid;
            $self->cookie( tmt => $cookie, { expires => time + 3600 * 24 * 365 * 10 } );
        }

        # Log redirect
        $self->db('Redirect')->create({
            url_id => $id,
            visitor_ip => $self->tx->remote_address,
            visitor_forwarded_for => scalar $self->req->headers->header('X-Forwarded-For'),
            visitor_uuid => $cookie,
            visitor_ua => $self->req->headers->user_agent,
        });

    }

    # Redirect
    $self->redirect_to( $url->longurl );
}

sub shorten {
    my $self = shift;
    my $longurl = $self->param('longurl');
    my $user_id = $self->logged_in ? $self->session('user')->{id} : \"DEFAULT";

    if( my $url = $self->db('Url')->create({ longurl => $longurl, user_id => $user_id }) ) {
        my $token = $self->id_to_token( $url->id );
        my $shorturl = $self->url_for( '/'.$token )->to_abs;

        $self->respond_to( 
            json => { json => { shorturl => $shorturl } },
            html => { url => $url, shorturl => $shorturl },
        );
    } else {
        $self->reply->exception;
    }

}



1;