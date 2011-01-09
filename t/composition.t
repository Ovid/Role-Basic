#!/usr/bin/env perl

use lib 'lib', 't/lib';
use MyTests tests => 27;
require Role::Basic;

{

    package My::Does::Basic1;
    use Role::Basic;
    requires 'turbo_charger';

    sub method {
        return __PACKAGE__ . " method";
    }
    ::fake_load;
}
{

    package My::Does::Basic2;
    use Role::Basic;
    requires 'turbo_charger';

    sub method2 {
        return __PACKAGE__ . " method2";
    }
    ::fake_load;
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
ok !$@, 'We should be able to use two roles with the same requirements';

{

    package My::Does::Basic3;
    use Role::Basic;
    with 'My::Does::Basic2';

    sub method3 {
        return __PACKAGE__ . " method3";
    }
    ::fake_load;
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

my $object = My::Class2->new;
can_ok $object, 'DOES';
ok $object->DOES('My::Does::Basic3'), 'An instance DOES roles which its class consumes';
ok $object->DOES('My::Does::Basic2'),
  '... and should do roles which its roles consumes';
ok !$object->DOES('My::Does::Basic1'),
  '... but not roles which it never consumed';

{
    {
        package Role::Which::Imports;
        use Role::Basic allow => 'TestMethods';
        use TestMethods qw(this that);
        ::fake_load;
    }
    {
       package Class::With::ImportingRole;
       use Role::Basic 'with';
       with 'Role::Which::Imports';
       sub new { bless {} => shift }
        ::fake_load;
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
        ::fake_load;
    }
    {
        package Class::With::ImportingRole2;
        use Role::Basic 'with';
        with 'Role::WithImportsOnceRemoved';
        sub new { bless {} => shift }
        ::fake_load;
    }
    ok my $o = Class::With::ImportingRole2->new,
        'We should be able to use roles which compose roles which import';

    foreach my $method (qw/this that/) {
        can_ok $o, $method;
        ok $o->$method($method), '... and calling "allow"ed methods should succeed';
        is $o->$method, $method, '... and it should function correctly';
    }
}
