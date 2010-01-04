#!perl

use strict;
use warnings;
use Test::More tests => 3;
use lib 't/tlib';

use_ok 'DBIx::Class::NestedSet::ResultSet';
use_ok 'DBIx::Class::NestedSet::Source';

use_ok 'MySchema';
