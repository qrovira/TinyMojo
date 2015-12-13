package TinyMojo::DB::ResultSet::Url;

use strict;
use warnings;

use base qw/DBIx::Class::ResultSet/;

sub hits {
    my $rs = shift;

    return $rs->result_source->schema->resultset('Hit')->search({
        url_id => [ map { $_->id } $rs->all ],
    }, {
        select => [ 'url_id', { count => 'id' } ],
        as => [ qw/ url_id hits /],
        group_by => [ qw/url_id/ ],
    });
}

sub urls_with_hits {
    my ($self, $search, $search_attrs, $fetch_attrs) = @_;

    $search_attrs //= {};
    $fetch_attrs //= {};
    $search_attrs->{rows} = 100 if $search_attrs->{rows} > 100;

    my $rs_ids = $self->search(
        $search,
        {
            select     => [ 'id' ],
            order_by   => { -desc => 'me.id' },
            cache      => 1,
            rows       => 100,
            page       => 1,
            %$search_attrs,
        }
    );
    
    my $rs_urls = $self->search(
        { 'me.id' => { -in => [$rs_ids->get_column('id')->all] } },
        {
            '+select'  => [ { count => 'hit.id' } ],
            '+as'      => [ 'hit_count' ],
            'join'     => [ 'hit' ],
            'group_by' => [ 'me.id' ],
            %$fetch_attrs,
        }
    );
    
    return $rs_urls, $rs_ids->pager;
}

1;
