package MySchema::ResultSet::MyTree;

use strict;
use warnings;
use parent qw( DBIx::Class::ResultSet );

__PACKAGE__->load_components(qw( NestedSet::ResultSet ));

1;
