package TinyMojo::Controller::Admin;
use Mojo::Base 'Mojolicious::Controller';

sub list_urls {
    my ($self) = @_;
    my $offset = $self->param('offset') // 0;
    my $rows = $self->param('rows') // 10;
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
        hits => \%hits,
        rows => $rows,
    );
}



1;
