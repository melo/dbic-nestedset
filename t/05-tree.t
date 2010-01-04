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

my @path = $root->path->all;
is(scalar(@path), 1,         'Path to root has length 1');
is($path[0]->id,  $root->id, '... and it is self');


done_testing();
