#!/usr/bin/perl

use strict;
use warnings;

use MyTests tests => 46;

{
    package My::Role;
    use Role::Basic;

    sub foo { 'Foo::foo' }
    sub bar { 'Foo::bar' }
    sub baz { 'Foo::baz' }

    requires 'role_bar';

    package My::Class;
    use Role::Basic 'with';

    ::is( ::exception {
        with 'My::Role' => { -alias => { bar => 'role_bar' } };
    }, undef, '... this succeeds' );

    package My::Class::Failure;
    use Role::Basic 'with';

    ::like( ::exception {
        with 'My::Role' => { -alias => { bar => 'role_bar' } };
    }, qr/Cannot alias 'bar' to 'role_bar' as a method of that name already exists in My::Class::Failure/, '... this succeeds' );

    sub role_bar { 'FAIL' }
}

ok(My::Class->can($_), "we have a $_ method") for qw(foo baz bar role_bar);

{
    package My::OtherRole;
    use Role::Basic;

    ::is( ::exception {
        with 'My::Role' => { -alias => { bar => 'role_bar' } };
    }, undef, '... this succeeds' );

    sub bar { 'My::OtherRole::bar' }

    package My::OtherRole::Failure;
    use Role::Basic;

    ::like( ::exception {
        with 'My::Role' => { -alias => { bar => 'role_bar' } };
    }, qr/Cannot alias 'bar' to 'role_bar' as a method of that name already exists in My::OtherRole::Failure/, '... cannot alias to a name that exists' );

    sub role_bar { 'FAIL' }
}

ok(My::OtherRole->can($_), "we have a $_ method") for qw(foo baz role_bar);
TODO: {
    local $TODO = 'Still unsure if this behavior us needed. Failure provides no guarantees';
    ok(Role::Basic->requires_method("My::OtherRole", 'bar'), '... and the &bar method is required');
    ok(!Role::Basic->requires_method("My::OtherRole", 'role_bar'), '... and the &role_bar method is not required');
}

{
    package My::AliasingRole;
    use Role::Basic;

    ::is( ::exception {
        with 'My::Role' => { -alias => { bar => 'role_bar' } };
    }, undef, '... this succeeds' );
}

ok(My::AliasingRole->can($_), "we have a $_ method") for qw(foo baz role_bar);
ok(!Role::Basic->requires_method("My::AliasingRole", 'bar'), '... and the &bar method is not required');

{
    package Foo::Role;
    use Role::Basic;

    sub foo { 'Foo::Role::foo' }

    package Bar::Role;
    use Role::Basic;

    sub foo { 'Bar::Role::foo' }

    package Baz::Role;
    use Role::Basic;

    sub foo { 'Baz::Role::foo' }

    package My::Foo::Class;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    ::is( ::exception {
        with 'Foo::Role' => { -alias => { 'foo' => 'foo_foo' }, -excludes => 'foo' },
             'Bar::Role' => { -alias => { 'foo' => 'bar_foo' }, -excludes => 'foo' },
             'Baz::Role';
    }, undef, '... composed our roles correctly' );

    package My::Foo::Class::Broken;
    use Role::Basic 'with';

    # XXX due to how we're structured, we hit the 'alias' error before the
    # "method conflict" error which Moose gets
    ::like( ::exception {
        with 'Foo::Role' => { -alias => { 'foo' => 'foo_foo' }, -excludes => 'foo' },
             'Bar::Role' => { -alias => { 'foo' => 'foo_foo' }, -excludes => 'foo' },
             'Baz::Role';
    }, qr/Cannot alias 'foo' to 'foo_foo' as a method of that name already exists in My::Foo::Class::Broken/, '... composed our roles correctly' );
}

{
    my $foo = My::Foo::Class->new;
    isa_ok($foo, 'My::Foo::Class');
    can_ok($foo, $_) for qw/foo foo_foo bar_foo/;
    is($foo->foo, 'Baz::Role::foo', '... got the right method');
    is($foo->foo_foo, 'Foo::Role::foo', '... got the right method');
    is($foo->bar_foo, 'Bar::Role::foo', '... got the right method');
}

{
    package My::Foo::Role;
    use Role::Basic;

    ::is( ::exception {
        with 'Foo::Role' => { -alias => { 'foo' => 'foo_foo' }, -excludes => 'foo' },
             'Bar::Role' => { -alias => { 'foo' => 'bar_foo' }, -excludes => 'foo' },
             'Baz::Role';
    }, undef, '... composed our roles correctly' );
}

ok(My::Foo::Role->can($_), "we have a $_ method") for qw/foo foo_foo bar_foo/;;
# XXX [!Moose]
ok(Role::Basic->requires_method("My::Foo::Role", 'foo'), '... and the &foo method is required');


{
    package My::Foo::Role::Other;
    use Role::Basic;

    # XXX again, we propogate errors immediately rather than generating
    # requirements
    ::isnt( ::exception {
        with 'Foo::Role' => { -alias => { 'foo' => 'foo_foo' }, -excludes => 'foo' },
             'Bar::Role' => { -alias => { 'foo' => 'foo_foo' }, -excludes => 'foo' },
             'Baz::Role';
    }, undef, '... composed our roles correctly' );
}

TODO: {
    local $TODO = 'We probably should make no guarantees on failure';
    ok(!My::Foo::Role::Other->can('foo_foo'), "we dont have a foo_foo method");
    ok(Role::Basic->requires_method("My::Foo::Role::Other", 'foo_foo'), '... and the &foo method is required');
}

{
    package My::Foo::AliasOnly;
    use Role::Basic 'with';

    ::is( ::exception {
        with 'Foo::Role' => { -alias => { 'foo' => 'foo_foo' } },
    }, undef, '... composed our roles correctly' );
}

ok(My::Foo::AliasOnly->can('foo'), 'we have a foo method');
ok(My::Foo::AliasOnly->can('foo_foo'), '.. and the aliased foo_foo method');

{
    package Role::Foo;
    use Role::Basic;

    sub x1 {}
    sub y1 {}
}

{
    package Role::Bar;
    use Role::Basic;

    ::is( ::exception {
        with 'Role::Foo' => {
            -alias    => { x1 => 'foo_x1' },
            -excludes => ['y1'],
        };
    }, undef, 'Compose Role::Foo into Role::Bar with alias and exclude' );

    sub x1 {}
    sub y1 {}
}

{
    ok( Role::Bar->can($_), "can $_ method" )
        for qw( x1 y1 foo_x1 );
}

{
    package Role::Baz;
    use Role::Basic;

    ::is( ::exception {
        with 'Role::Foo' => {
            -alias    => { x1 => 'foo_x1' },
            -excludes => ['y1'],
        };
    }, undef, 'Compose Role::Foo into Role::Baz with alias and exclude' );
}

{
    ok( Role::Baz->can($_), "has $_ method" )
        for qw( x1 foo_x1 );
    ok( ! Role::Baz->can('y1'), 'Role::Baz has no y1 method' );
}
