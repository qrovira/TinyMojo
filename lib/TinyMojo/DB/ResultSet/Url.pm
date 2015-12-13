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
    my ($self, $search, $attrs) = @_;

    $attrs //= {};
    $attrs->{rows} = 100 if $attrs->{rows} > 100;

    return $self->search(
        $search,
        {
            '+select'  => [ { count => 'hit.id' } ],
            '+as'      => [ 'hit_count' ],
            'join'     => [ 'hit' ],
            'group_by' => [ 'me.id' ],
            order_by   => { -desc => 'me.id' },
            cache      => 1,
            rows       => 100,
            page       => 1,
            %$attrs,
        }
    );
}

1;
