#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';
use MyTests tests => 38;

=pod

Mutually recursive roles.

=cut

{
    package Role::Foo;
    use Role::Basic;

    requires 'foo';

    sub bar { 'Role::Foo::bar' }

    package Role::Bar;
    use Role::Basic;

    requires 'bar';

    sub foo { 'Role::Bar::foo' }
}

{
    package My::Test1;
    use Role::Basic 'with';
    sub new { {} => shift }

    ::is( ::exception {
        with 'Role::Foo', 'Role::Bar';
    }, undef, '... our mutually recursive roles combine okay' );

    package My::Test2;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    ::is( ::exception {
        with 'Role::Bar', 'Role::Foo';
    }, undef, '... our mutually recursive roles combine okay (no matter what order)' );
}

my $test1 = My::Test1->new;
isa_ok($test1, 'My::Test1');

ok($test1->DOES('Role::Foo'), '... $test1 does Role::Foo');
ok($test1->DOES('Role::Bar'), '... $test1 does Role::Bar');

can_ok($test1, 'foo');
can_ok($test1, 'bar');

is($test1->foo, 'Role::Bar::foo', '... $test1->foo worked');
is($test1->bar, 'Role::Foo::bar', '... $test1->bar worked');

my $test2 = My::Test2->new;
isa_ok($test2, 'My::Test2');

ok($test2->DOES('Role::Foo'), '... $test2 does Role::Foo');
ok($test2->DOES('Role::Bar'), '... $test2 does Role::Bar');

can_ok($test2, 'foo');
can_ok($test2, 'bar');

is($test2->foo, 'Role::Bar::foo', '... $test2->foo worked');
is($test2->bar, 'Role::Foo::bar', '... $test2->bar worked');

# check some meta-stuff

ok(Role::Foo->can('bar'), '... it still has the bar method');
ok(Role::Basic->requires_method('Role::Foo','foo'), '... it still has the required foo method');

ok(Role::Bar->can('foo'), '... it still has the foo method');
ok(Role::Basic->requires_method('Role::Bar','bar'), '... it still has the required bar method');

=pod

Role method conflicts

=cut

{
    package Role::Bling;
    use Role::Basic;

    sub bling { 'Role::Bling::bling' }

    package Role::Bling::Bling;
    use Role::Basic;

    sub bling { 'Role::Bling::Bling::bling' }
}

{
    package My::Test3;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    ::like( ::exception {
        with 'Role::Bling', 'Role::Bling::Bling';
    }, qr/Due to a method name conflict in roles 'Role::Bling' and 'Role::Bling::Bling', the method 'bling' must be implemented or excluded by 'My::Test3'/, '... role methods conflict and method was required' );

    package My::Test4;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    # XXX Moose allows multiple 'with' statements. Role::Basic does not
    ::like(
        ::exception{ 
            with 'Role::Bling';
            with 'Role::Bling::Bling';
          },
        qr/with\(\) may not be called more than once for My::Test4/,
        '... role methods cannot be manually combined'
    );

    package My::Test6;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    ::is( ::exception {
        with 'Role::Bling::Bling', 'Role::Bling';
    }, undef, '... role methods didnt conflict when manually resolved' );

    sub bling { 'My::Test6::bling' }
}

TODO: {
    local $TODO = 'Do not flatten methods into a class if there are conflicts';
    ok(!My::Test3->can('bling'), '... we didnt get any methods in the conflict');
}
ok(My::Test4->can('bling'), '... we did get the method when manually dealt with');
ok(My::Test6->can('bling'), '... we did get the method when manually dealt with');

TODO: {
    local $TODO = 'Do not compose roles into a class if there are conflicts';
    ok(!My::Test3->DOES('Role::Bling'), '... our class does() the correct roles');
    ok(!My::Test3->DOES('Role::Bling::Bling'), '... our class does() the correct roles');
}
ok(My::Test4->DOES('Role::Bling'), '... our class does() the correct roles');

# XXX another difference from Moose 
ok(!My::Test4->DOES('Role::Bling::Bling'), '... our class does not support multiple with()');
ok(My::Test6->DOES('Role::Bling'), '... our class does() the correct roles');
ok(My::Test6->DOES('Role::Bling::Bling'), '... our class does() the correct roles');

is(My::Test4->bling, 'Role::Bling::bling', '... and we got the first method that was added');
is(My::Test6->bling, 'My::Test6::bling', '... and we got the local method');

# check how this affects role compostion

{
    package Role::Bling::Bling::Bling;
    use Role::Basic;

    with 'Role::Bling::Bling';

    sub bling { 'Role::Bling::Bling::Bling::bling' }
}

ok(Role::Bling::Bling->can('bling'), '... still got the bling method in Role::Bling::Bling');
ok(Role::Bling::Bling->DOES('Role::Bling::Bling'), '... our role correctly does() itself');
ok(Role::Bling::Bling::Bling->can('bling'), '... dont have the bling method in Role::Bling::Bling::Bling');
is(Role::Bling::Bling::Bling->can('bling')->(),
    'Role::Bling::Bling::Bling::bling',
    '... still got the bling method in Role::Bling::Bling::Bling');

# the rest of this is truncated because we make no distinction between
# atttributes and methods
