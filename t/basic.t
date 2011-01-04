#!/usr/bin/env perl

use Test::More tests => 3;
use lib 'lib', 't/lib';

use_ok 'My::Example' or BAIL_OUT 'Could not load test module My::Example';
can_ok 'My::Example', 'no_conflict';
is +My::Example->no_conflict, 'My::Does::Basic::no_conflict',
    '... and it should return the correct value';
