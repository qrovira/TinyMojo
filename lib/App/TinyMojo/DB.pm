use utf8;
package App::TinyMojo::DB;

use strict;
use warnings;

our $VERSION = 1;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;

1;
