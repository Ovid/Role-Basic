#!/usr/bin/env perl

use lib 'lib', 't/lib';
use MyTests tests => 30;
require Role::Basic;

{

    package My::Does::Basic1;
    use Role::Basic;
    requires 'turbo_charger';

    sub method {
        return __PACKAGE__ . " method";
    }
}
{

    package My::Does::Basic2;
    use Role::Basic;
    requires 'turbo_charger';

    sub method2 {
        return __PACKAGE__ . " method2";
    }
}

eval <<'END_PACKAGE';
package My::Class1;
use Role::Basic 'with';
with qw(
    My::Does::Basic1
    My::Does::Basic2
);
sub turbo_charger {}
END_PACKAGE
ok !$@, 'We should be able to use two roles with the same requirements'
    or die $@;

is_deeply [ sort My::Class1->ROLES ], [qw/My::Does::Basic1 My::Does::Basic2/],
  'ROLES reports roles in array context';

{

    package My::Does::Basic3;
    use Role::Basic;
    with 'My::Does::Basic2';

    sub method3 {
        return __PACKAGE__ . " method3";
    }
}

eval <<'END_PACKAGE';
package My::Class2;
use Role::Basic 'with';
with qw(
    My::Does::Basic3
);
sub new { bless {} => shift }
sub turbo_charger {}
END_PACKAGE
ok !$@, 'We should be able to use roles which consume roles'
    or die $@;
can_ok 'My::Class2', 'method2';
is My::Class2->method2, 'My::Does::Basic2 method2',
  '... and it should be the correct method';
can_ok 'My::Class2', 'method3';
is My::Class2->method3, 'My::Does::Basic3 method3',
  '... and it should be the correct method';

can_ok 'My::Class2', 'DOES';
ok My::Class2->DOES('My::Does::Basic3'), 'A class DOES roles which it consumes';
ok My::Class2->DOES('My::Does::Basic2'),
  '... and should do roles which its roles consumes';
ok !My::Class2->DOES('My::Does::Basic1'),
  '... but not roles which it never consumed';
is_deeply [sort My::Class2->ROLES], [qw/My::Does::Basic2 My::Does::Basic3/],
  'ROLES reports roles in array context';

my $object = My::Class2->new;
can_ok $object, 'DOES';
ok $object->DOES('My::Does::Basic3'), 'An instance DOES roles which its class consumes';
ok $object->DOES('My::Does::Basic2'),
  '... and should do roles which its roles consumes';
ok !$object->DOES('My::Does::Basic1'),
  '... but not roles which it never consumed';
is_deeply [sort $object->ROLES], [qw/My::Does::Basic2 My::Does::Basic3/],
  'Instance ROLES reports roles in array context';

{
    {
        package Role::Which::Imports;
        use Role::Basic allow => 'TestMethods';
        use TestMethods qw(this that);
    }
    {
       package Class::With::ImportingRole;
       use Role::Basic 'with';
       with 'Role::Which::Imports';
       sub new { bless {} => shift }
    }
    my $o = Class::With::ImportingRole->new;

    foreach my $method (qw/this that/) {
        can_ok $o, $method;
        ok $o->$method($method), '... and calling "allow"ed methods should succeed';
        is $o->$method, $method, '... and it should function correctly';
    }
}

{
    {
        package Role::WithImportsOnceRemoved;
        use Role::Basic;
        with 'Role::Which::Imports';
    }
    {
        package Class::With::ImportingRole2;
        use Role::Basic 'with';
$ENV{DEBUG} = 1;
        with 'Role::WithImportsOnceRemoved';
        sub new { bless {} => shift }
    }
    ok my $o = Class::With::ImportingRole2->new,
        'We should be able to use roles which compose roles which import';

    foreach my $method (qw/this that/) {
        can_ok $o, $method;
        ok $o->$method($method), '... and calling "allow"ed methods should succeed';
        is $o->$method, $method, '... and it should function correctly';
    }
}
