use utf8;
package App::TinyMojo::DB::Result::Url;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime');
__PACKAGE__->table('url');

__PACKAGE__->add_columns(
    'id',
    {
        data_type         => 'integer',
        is_auto_increment => 1,
        is_nullable       => 0,
        sequence          => 'url_id_seq',
    },
    'longurl',
    {
        data_type => 'varchar',
        is_nullable => 0,
        size => 4096,
    },
    'user_id',
    {
        data_type => 'int',
        is_nullable => 0,
        default => 0,
    },
);


__PACKAGE__->set_primary_key('id');


1;
