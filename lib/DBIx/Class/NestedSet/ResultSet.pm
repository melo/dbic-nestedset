package DBIx::Class::NestedSet::ResultSet;

use strict;
use warnings;
use Carp qw( croak );

sub root {
  my ($self) = @_;

  return $self->single({parent_id => \'IS NULL'});
}

sub create {
  my $self = shift;
  my ($args) = @_;

  # Common case: lft is defined so we arrived via a cool method
  return $self->next::method(@_) if $args->{lft};

  # no left, no parent_id, a root!
  return $self->next::method(@_) unless $args->{parent_id};

  # no left assume append child of parent
  my $parent_id = $args->{parent_id};
  my $parent    = $self->result_source->resultset->find($parent_id);
  croak("Invalid parent_id $parent_id") unless $parent;
  return $parent->append_child($args);
}

1;
