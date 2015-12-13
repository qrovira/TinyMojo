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
    my $page = $self->param('page') // 1;
    my $rows = $self->param('rows') // 10;
    $rows = 100 if $rows > 100;

    my ($urls, $pager) = $self->db('Url')->urls_with_hits({},
        {
            rows     => $rows,
            page     => $page,
        },
        { prefetch => [ "user" ] }
    );

    $self->stash(
        urls  => $urls,
        pager => $pager,
        rows  => $rows,
    );
}



1;
