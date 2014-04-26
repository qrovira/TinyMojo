package App::TinyMojo::DB::ResultSet::Url;

use strict;
use warnings;

use base qw/DBIx::Class::ResultSet/;

sub hits {
    my $rs = shift;

    return $rs->result_source->schema->resultset('Redirect')->search({
        url_id => [ map { $_->id } $rs->all ],
    }, {
        select => [ 'url_id', { count => 'id' } ],
        as => [ qw/ url_id hits /],
        group_by => [ qw/url_id/ ],
    });
}

1;
