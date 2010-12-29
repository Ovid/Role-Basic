#!/usr/bin/env perl

use Test::Most;
use lib 'lib', 't/lib';
use Role::Basic ();

subtest '_load_role' => sub {
    lives_ok { Role::Basic->_load_role('My::Does::Basic') }
    'Role::Basic->_load_role should succeed loading a package';
    ok exists $INC{'My/Does/Basic.pm'}, 'and it should be in the %INC hash';
    lives_ok { Role::Basic->_load_role('My::Does::Basic') }
    'and trying to load a role more than once should be OK';
    throws_ok { Role::Basic->_load_role('No::Such::Role') }
        qr{Can't locate No/Such/Role\.pm in \@INC},
        'but trying to load a non-existent package should fail';
    done_testing;
};

{ 
    package My::Example;

    use Role::Basic 'with';

    with 'My::Does::Basic';

    sub new { bless {} => shift }
    sub turbo_charger {}
    sub foo() {}
}


eq_or_diff [sort keys %{ Role::Basic->_get_methods('My::Example') } ],
    [qw/foo new turbo_charger/],
    'Role::Basic->_get_methods should only return methods defined in the package';

done_testing;
