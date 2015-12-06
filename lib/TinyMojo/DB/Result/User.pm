use utf8;
package TinyMojo::DB::Result::User;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components(qw/ EncodedColumn InflateColumn::DateTime Core /);
__PACKAGE__->table('user');

__PACKAGE__->add_columns(
    'id',
    {
        data_type         => 'integer',
        is_auto_increment => 1,
        is_nullable       => 0,
        sequence          => 'user_id_seq',
    },
    'login',
    {
        data_type => 'varchar',
        is_nullable => 0,
        size => 255,
    },
    'email',
    {
        data_type => 'varchar',
        is_nullable => 0,
        size => 100,
    },
    'password',
    {
        data_type => 'varchar',
        is_nullable => 0,
        size => 255,
        encode_column => 1,
        encode_class => 'Digest',
        encode_args => { algorithm => 'SHA-512', format => 'hex', salt_length => 16 },
        encode_check_method => 'check_password',
    },
    'admin',
    {
        data_type => 'boolean',
        is_nullable => 0,
        default => 0
    },
);


__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint('user_login_key', ['login']);

1;
