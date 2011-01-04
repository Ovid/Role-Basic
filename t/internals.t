#!/usr/bin/env perl

use Test::More tests => 5;
use lib 'lib', 't/lib';
use Role::Basic ();

eval { Role::Basic->_load_role('My::Does::Basic') };
ok !$@, 'Role::Basic->_load_role should succeed loading a package';
ok exists $INC{'My/Does/Basic.pm'}, 'and it should be in the %INC hash';
eval { Role::Basic->_load_role('My::Does::Basic') };
ok !$@, 'and trying to load a role more than once should be OK';
eval { Role::Basic->_load_role('No::Such::Role') };
like $@, qr{Can't locate No/Such/Role\.pm in \@INC},
    'but trying to load a non-existent package should fail';

{ 
    package My::Example;

    use Role::Basic 'with';

    with 'My::Does::Basic';

    sub new { bless {} => shift }
    sub turbo_charger {}
    sub foo() {}
}

my $methods = [sort keys %{ Role::Basic->_get_methods('My::Example') } ];
is_deeply $methods, [qw/foo new turbo_charger/],
  'Role::Basic->_get_methods should only return methods defined in the package'
  or do {
    require Data::Dumper;
    diag Data::Dumper::Dumper($methods);
  };
