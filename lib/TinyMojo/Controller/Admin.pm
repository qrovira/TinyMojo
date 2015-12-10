package TinyMojo::Controller::Admin;
use Mojo::Base 'Mojolicious::Controller';

#
# Authentication and admin bridges
#

sub check_admin {
    my $c = shift;

    return 1 if $c->admin;
    
    $c->bs_flash_to(
        danger => $c->l('Not authorized'),
        ($c->logged_in ? 'url#shorten' : 'user#login')
    );

    return undef;
}


#
# Actual actions
#

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
