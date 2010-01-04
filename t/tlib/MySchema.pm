package MySchema;

use strict;
use warnings;
use parent qw( DBIx::Class::Schema );

__PACKAGE__->load_namespaces;

my $schema;

sub schema {
  my ($class) = @_;

  if (!defined $schema) {
    $schema =
      $class->connect('dbi:SQLite:./test.db', undef, undef,
      {AutoCommit => 1});
  }

  return $schema;
}

sub my_tree {
  my $rs = shift->schema->resultset('MyTree');
  return $rs unless @_;    # no parameters, just a resultset
  return $rs->find(@_) if !ref($_[0]);    # use find if it looks like PK
  return $rs->search(@_);                 # search for all other cases
}

sub reset {
  my ($class) = @_;

  unlink('./test.db');
  undef $schema;
  $class->schema->deploy;
}

1;
