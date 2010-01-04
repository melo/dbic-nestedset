package DBIx::Class::NestedSet::Source;

use strict;
use warnings;
use base qw( DBIx::Class );

###############################################
# Setup all the stuff we need to be a NestedSet

sub setup_nested_set {
  my ($class, %mix) = @_;

  my %cols = (
    "lft" => {
      data_type   => "INT",
      is_nullable => 0,
      extra       => {comment => 'Lower limit for our children',},
    },

    "rgt" => {
      data_type   => "INT",
      is_nullable => 0,
      extra       => {comment => 'Upper limit for our children',},
    },

    "parent_id" => {
      data_type   => "INT",
      is_nullable => 1,
      extra       => {comment => 'ID of our immediate parent',},
    },

    "depth" => {
      data_type   => "INT",
      is_nullable => 0,
      extra       => {
        comment => 'Distance of this node to the root (which has depth == 0)',
      },
    },

    "child_count" => {
      data_type   => "INT",
      is_nullable => 0,
      extra       => {comment => 'Number of childs we have',},
    },
  );

  while (my ($col, $attrs) = each %mix) {
    _merge_hash($attrs, $cols{$col});
  }

  $class->add_columns(%cols);
  $class->has_many(
    'child_nodes' => $class,
    {'foreign.parent_id' => 'self.id'},
  );
  $class->might_have(
    'parent_node' => $class,
    {'foreign.id' => 'self.parent_id'},
  );
}

# little helper
sub _merge_hash {
  my ($src, $dst) = @_;

  foreach my $f (keys %$src) {
    my $v = $src->{$f};
    if (ref($v) eq 'HASH') {
      my $ov = $dst->{$f} ||= {};
      croak("CFG ERROR: attr '$f' has HASH value, but dst has '$ov', ")
        unless ref($ov) eq 'HASH';
      _merge_hash($v, $ov);
    }
    elsif (exists $dst->{$f}) {
      croak(
        "CFG ERRROR: attr '$f' present in src and dst but not a HASH ref, will not override"
      );
    }
    else {
      $dst->{$f} = $v;
    }
  }
}

# make sure we have the proper indexes
sub sqlt_deploy_hook {
  my ($class, $table) = @_;

  # Index important fields
  my %index;
  $index{$_} = 1 for qw( lft rgt parent_id );

  # Remove fields already indexed by other means
  for my $index ($table->get_indices) {
    my $first_field = ($index->fields)[0];
    delete $index{$first_field};
  }
  for my $field ($table->unique_fields) {
    delete $index{$field};
  }

  return unless %index;

  foreach my $col (keys %index) {
    $table->add_index(
      name   => $col,
      fields => [$col],
    );
  }
}


############
# DBIC hooks

sub insert {
  my ($self, @args) = @_;
  my $schema = $self->result_source->schema;
  my $r;

  my $meth = $self->next::can;

  $schema->txn_do(
    sub {

      # sane defaults: we are root
      $self->lft(1)              unless defined $self->lft;
      $self->rgt($self->lft + 1) unless defined $self->rgt;
      $self->child_count(0)      unless defined $self->child_count;
      $self->depth(0)            unless defined $self->depth;

      # create it
      $r = $meth->($self, @args);

      # make sure parents count is sane
      $r->parents->update({child_count => \'child_count + 1'});
    }
  );

  return $r;
}

sub delete {
  my ($self, @args) = @_;
  my $meth = $self->next::can;

  return $self->result_source->schema->txn_do(
    sub {
      my $children = $self->children;
      while (my $child = $children->next) {
        $child->delete;
      }

      return $meth->($self, @args);
    }
  );
}


####################################
# insert a node anywhere in the tree

sub _insert_node {
  my ($self, $args) = @_;
  my $rs     = $self->result_source;
  my $schema = $rs->schema;

  # our special arguments
  my $o_args = delete $args->{other_args};
  my $pivot  = $args->{lft};

  # Use same parent and depth as self by default
  $args->{depth}     = $self->depth     unless defined $args->{depth};
  $args->{parent_id} = $self->parent_id unless defined $args->{parent_id};

  # make room and create it
  my $new_record;
  $schema->txn_do(
    sub {
      $rs->resultset->search({'me.rgt' => {'>=', $pivot}})
        ->update({rgt => \'rgt + 2'});
      $rs->resultset->search({'me.lft' => {'>=', $pivot}})
        ->update({lft => \'lft + 2'});
      $new_record = $rs->resultset->create({%$o_args, %$args});
    }
  );

  return $new_record;
}

# special case: insert as a child of $self
sub _child_node {
  my ($self, $args) = @_;

  $args->{depth}     = $self->depth + 1;
  $args->{parent_id} = $self->id;

  return $self->_insert_node($args);
}


##########################
# Utils to manage our tree

# Add as first child of self
sub prepend_child {
  my ($self, $args) = @_;

  return $self->_child_node(
    { lft        => $self->lft + 1,
      other_args => $args,
    }
  );
}


# Add as last child of self
sub append_child {
  my ($self, $args) = @_;

  return $self->_child_node(
    { lft        => $self->rgt,
      other_args => $args,
    }
  );
}


# add a new node after self
sub add_sibling_after {
  my ($self, $args) = @_;

  return $self->_insert_node(
    { lft        => $self->rgt + 1,
      other_args => $args,
    }
  );
}

# add a new node before self
sub add_sibling_before {
  my ($self, $args) = @_;

  return $self->_insert_node(
    { lft        => $self->lft,
      other_args => $args,
    }
  );
}


###############
# Introspection

# is this the root?
sub is_root {
  my ($self) = @_;

  return 1 if $self->depth == 0;
  return 0;
}


###############
# Sets of nodes

# result_set of children
sub children {
  my ($self) = @_;

  return $self->result_source->resultset->search(
    {'me.parent_id' => $self->id,},
    {order_by       => 'me.lft',},
  );
}

# result_set of parents
sub parents {
  my ($self) = @_;

  return $self->result_source->resultset->search(
    { 'me.lft' => {'<', $self->lft},
      'me.rgt' => {'>', $self->rgt},
    },
    {order_by => 'me.lft'},
  );
}

# result_set of path to root
sub path {
  my ($self) = @_;

  return $self->result_source->resultset->search(
    { 'me.lft' => {'<=', $self->lft},
      'me.rgt' => {'>=', $self->rgt},
    },
    {order_by => 'me.lft'},
  );
}

# result_set of subtree
sub subtree {
  my ($self) = @_;

  return $self->result_source->resultset->search(
    {'me.lft' => {'between' => [$self->lft, $self->rgt]},},
    {order_by => 'me.lft',});
}


1;
