use utf8;
package TinyMojo::DB::Result::Url;

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

__PACKAGE__->might_have( user => 'TinyMojo::DB::Result::User', { 'foreign.id' => 'self.user_id' } );

__PACKAGE__->has_many( hit => 'TinyMojo::DB::Result::Hit', 'url_id' );


1;
