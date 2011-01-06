#!/usr/bin/env perl

use Test::More tests => 20;
use lib 'lib';
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
    package Test::Make::Method;

    sub import {
        my $class = shift;
        my $target = caller;
        my @methods = @_;

        foreach my $method (@methods) {
            my $fq_method = $target . "::$method";
            no strict 'refs';
            *$fq_method = sub {
                my $self = shift;
                return $self->{$method} unless @_;
                $self->{$method} = shift;
                return $self;
            };
        }
    }

    # required in BEGIN lest the later 'use' fails
    BEGIN { $INC{'Test/Make/Method.pm'} = 1 }
}

{
    {
        package Role::Which::Imports;
        use Role::Basic allow => 'Test::Make::Method';
        use Test::Make::Method qw(this that);
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
