#!/usr/bin/env perl

use Test::Most;
use Carp::Always;
use lib 'lib', 't/lib';
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
ok !$@, 'We should be able to use two roles with the same requirements';

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

done_testing;
