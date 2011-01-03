#!/usr/bin/env perl

use Test::Most;
use lib 'lib', 't/lib';

{
    package RoleC;
    use Role::Basic;
    sub baz { }
}
{
    package RoleB;
    use Role::Basic;
    with 'RoleC';
    sub bar { }
}
{
    package RoleA;
    use Role::Basic;
    with 'RoleC';
    sub foo { }
}
eval <<'END';
package Foo;
use strict;
use warnings;
use Role::Basic 'with';
with 'RoleA', 'RoleB';
END
my $error = $@;
ok !$error,
    'Composing multiple roles which use the same role should not have conflicts'
    or diag $error;
done_testing;
