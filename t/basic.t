#!/usr/bin/env perl

use Test::Most;
use Carp::Always;
use lib 'lib', 't/lib';

#eval "use My::Example";
#ok my $error = $@, 'Trying to use My::Example with missing requires() should fail';
#like $error, qr/Can't apply My::Does::Basic to My::Example - missing turbo_charger/,
#    '... with an appropriate error message';
#
#*My::Example::turbo_charger = sub {};
use_ok 'My::Example' or BAIL_OUT 'Could not load test module My::Example';
can_ok 'My::Example', 'no_conflict';
#diag +My::Example->no_conflict;

eq_or_diff [sort +Role::Basic::_get_methods('My::Example') ],
    [qw/foo new turbo_charger/],
    '_get_methods should only return methods defined in the package';

done_testing;
