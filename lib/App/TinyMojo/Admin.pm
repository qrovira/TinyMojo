package App::TinyMojo::Admin;
use Mojo::Base 'Mojolicious::Controller';

# By now, let's put just a dummy list of the last 100 shortened URLs
sub dashboard {
    my ($self) = @_;

    $self->stash(
      rows => $self->db->selectall_arrayref(
        'SELECT id, longurl FROM url ORDER BY id DESC LIMIT 100',
        { Slice => { id => 1, longurl => 2 } }
      )
    );
}

1;
