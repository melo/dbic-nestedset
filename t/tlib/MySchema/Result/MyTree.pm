package MySchema::Result::MyTree;

use strict;
use warnings;
use parent qw(DBIx::Class::ResultSource);

__PACKAGE__->load_components(qw( NestedSet::Source Core ));

__PACKAGE__->table('my_tree');

__PACKAGE__->add_columns(
  "id" => {
    data_type         => "INT",
    is_nullable       => 0,
    is_auto_increment => 1,
  },

  "name" => {
    data_type   => "CHAR",
    is_nullable => 0,
    size        => 100,
  },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->setup_nested_set();

1;
