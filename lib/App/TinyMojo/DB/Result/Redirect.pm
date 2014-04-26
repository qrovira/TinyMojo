use utf8;
package App::TinyMojo::DB::Result::Redirect;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime');
__PACKAGE__->table('redirect');

__PACKAGE__->add_columns(
    'id',
    {
        data_type         => 'integer',
        is_auto_increment => 1,
        is_nullable       => 0,
        sequence          => 'redirect_id_seq',
    },
    'url_id',
    {
        data_type         => 'integer',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    'time',
    {
        data_type         => 'timestamp',
        is_auto_increment => 1,
        is_nullable       => 0,
        default           => \"CURRENT_TIMESTAMP",
    },
    'visitor_ip',
    {
        data_type => 'varchar',
        is_nullable => 0,
        size => 39,
    },
    'visitor_forwarded_for',
    {
        data_type => 'varchar',
        is_nullable => 1,
        size => 255,
    },
    'visitor_uuid',
    {
        data_type => 'varchar',
        is_nullable => 1,
        size => 100,
    },
    'visitor_ua',
    {
        data_type => 'varchar',
        is_nullable => 1,
        size => 1024,
    },
);


__PACKAGE__->set_primary_key('id');


1;
