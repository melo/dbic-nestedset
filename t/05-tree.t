#!perl

use strict;
use warnings;
use Test::More;
use lib 't/tlib';
use MySchema;

MySchema->reset;
my $schema = MySchema->schema;

is($schema->my_tree->count, 0, 'Tree start empty');

### Root tests
my $root = $schema->my_tree->create({name => 'My root'});
ok($root, 'Got root');
is($root->name, 'My root', '... with the expected name');
is($root->lft,  1,         '... and the proper lft');
is($root->rgt,  2,         '... and the proper rgt');
ok(!defined($root->parent_id), '... and the NULL parent_id');
is($root->depth, 0, '... and the expected depth');
ok($root->is_root, 'The is_root() method agrees, we are root');

is($root->children->count, 0, 'We are childless for now');
is($root->parents->count,  0, '... and parentless (Dickens would be proud!)');
is($root->subtree->count, 1,
  '... but one nodes in the subtree (self counts)');

my @path = $root->path->all;
is(scalar(@path), 1,         'Path to root has length 1');
is($path[0]->id,  $root->id, '... and it is self');


### First born
my $node = $root->append_child({name => 'First born'});
ok($node, 'Got a node');
is($node->name,      'First born', '... with the expected name');
is($node->lft,       2,            '... and the proper lft');
is($node->rgt,       3,            '... and the proper rgt');
is($node->parent_id, $root->id,    '... and root as the parent_id');
is($node->depth,     1,            '... and the expected depth');
ok(!$node->is_root, 'The is_root() method agrees, we are not a root');

is($node->children->count, 0, 'We are childless for now');

my @parents = $node->parents->all;
@path = $node->path->all;
is(scalar(@parents), 1, 'We have one parent');
is(scalar(@path),    2, '... and the path to root is 2');

is($parents[0]->id, $root->id, 'First parent is root');
is($path[0]->id,    $root->id, '... so is the first path element');
is($path[-1]->id,   $node->id, 'Last path element is self');

$root->discard_changes;    ## refresh from db
is($root->lft, 1, 'Root lft is 1 as always');
is($root->rgt, 4, 'Root rgt is 4 to make room for first born');

is($root->children->count, 1, 'We are no longer childless');
is($root->subtree->count, 2,
  '... and two nodes in the subtree (self counts)');


### First grand-child
my $grand = $node->prepend_child({name => 'Unsafe sex'});
ok($grand, 'Got a new node');
is($grand->name,      'Unsafe sex', '... with the expected name');
is($grand->lft,       3,            '... and the proper lft');
is($grand->rgt,       4,            '... and the proper rgt');
is($grand->parent_id, $node->id,    '... and node as the parent_id');
is($grand->depth,     2,            '... and the expected depth');
ok(!$grand->is_root, 'The is_root() method agrees, we are not a root');

is($grand->children->count, 0, 'We are childless for now');

@parents = $grand->parents->all;
@path    = $grand->path->all;
is(scalar(@parents), 2, 'We have two parents');
is(scalar(@path),    3, '... and the path to root is 3 nodes deep');

is($parents[0]->id, $root->id,  'First parent is root');
is($path[0]->id,    $root->id,  '... so is the first path element');
is($path[-1]->id,   $grand->id, 'Last path element is self');

$node->discard_changes;    ## refresh from db
is($node->lft, 2, 'First born lft is 2');
is($node->rgt, 5, 'First born rgt is 5 to make room for Unsafe sex');

$root->discard_changes;    ## refresh from db
is($root->lft, 1, 'Root lft is 1 as always');
is($root->rgt, 6, 'Root rgt is 6 to make room for childs');

is($root->children->count, 1, 'Root has one child');
is($root->subtree->count,  3, '... but three nodes in the subtree');


### We never learn from our mistakes
$grand = $grand->add_sibling_after({name => 'More unsafe sex'});
ok($grand, 'Got yet another node');
is($grand->name,      'Unsafe sex', '... with the expected name');
is($grand->lft,       5,            '... and the proper lft');
is($grand->rgt,       6,            '... and the proper rgt');
is($grand->parent_id, $node->id,    '... and node as the parent_id');
is($grand->depth,     2,            '... and the expected depth');
ok(!$grand->is_root, 'The is_root() method agrees, we are not a root');

is($grand->children->count, 0, 'We are childless for now');

@parents = $grand->parents->all;
@path    = $grand->path->all;
is(scalar(@parents), 2, 'We have two parents');
is(scalar(@path),    3, '... and the path to root is 3 nodes deep');

is($parents[0]->id, $root->id,  'First parent is root');
is($path[0]->id,    $root->id,  '... so is the first path element');
is($path[-1]->id,   $grand->id, 'Last path element is self');

$node->discard_changes;    ## refresh from db
is($node->lft, 2, 'First born lft is 2');
is($node->rgt, 7,
  'First born rgt is 7 to make room for Unsafe sex and More unsafe sex');

is($node->children->count, 2, 'First born has two children now');
is($node->subtree->count,  3, '... but three nodes in the subtree');

$root->discard_changes;    ## refresh from db
is($root->lft, 1, 'Root lft is 1 as always');
is($root->rgt, 8, 'Root rgt is 8 to make room for childs');

is($root->children->count, 1, 'Root has one child');
is($root->subtree->count,  4, '... but three nodes in the subtree');

done_testing();
