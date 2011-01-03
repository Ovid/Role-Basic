#!/usr/bin/env perl

use Test::Most;
use lib 'lib', 't/lib';

{

    package RoleC;
    use Role::Basic;
    sub baz { 'baz' }
}
{

    package RoleB;
    use Role::Basic;
    with 'RoleC';
    sub bar { 'bar' }
}
{

    package RoleA;
    use Role::Basic;
    with 'RoleC';
    sub foo { 'foo' }
}
eval <<'END';
package Foo;
use strict;
use warnings;
use Role::Basic 'with';
with 'RoleA', 'RoleB';
sub new { bless {} => shift }
END
my $error = $@;
ok !$error,
  'Composing multiple roles which use the same role should not have conflicts'
  or diag $error;

my $object = Foo->new;
foreach my $method (qw/foo bar baz/) {
    can_ok $object, $method;
    is $object->$method, $method,
      '... and all methods should be composed in correctly';
}
done_testing;
