#!/usr/bin/perl

use strict;
use warnings;

use MyTests tests => 19;

{
    package My::Role;
    use Role::Basic;

    sub foo { 'Foo::foo' }
    sub bar { 'Foo::bar' }
    sub baz { 'Foo::baz' }

    package My::Class;
    use Role::Basic 'with';

    with 'My::Role' => { -excludes => 'bar' };
}

ok(My::Class->can($_), "we have a $_ method") for qw(foo baz);
ok(!My::Class->can('bar'), '... but we excluded bar');

{
    package My::OtherRole;
    use Role::Basic;

    with 'My::Role' => { -excludes => 'foo' };

    sub foo { 'My::OtherRole::foo' }
    sub bar { 'My::OtherRole::bar' }
}

ok(My::OtherRole->can($_), "we have a $_ method") for qw(foo bar baz);

TODO: {
    local $TODO = 'Why is one required and the other not?';
    ok(!Role::Basic->requires_method("My::OtherRole", 'foo'), '... and the &foo method is not required');
    ok(Role::Basic->requires_method("My::OtherRole", 'bar'), '... and the &bar method is required');
}

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
        with 'Foo::Role' => { -excludes => 'foo' },
             'Bar::Role' => { -excludes => 'foo' },
             'Baz::Role';
    }, undef, '... composed our roles correctly' );

    package My::Foo::Class::Broken;
    use Role::Basic 'with';

    ::like( ::exception {
        with 'Foo::Role',
             'Bar::Role' => { -excludes => 'foo' },
             'Baz::Role';
    }, qr/Due to a method name conflict in roles 'Baz::Role' and 'Foo::Role', the method 'foo' must be implemented or excluded by 'My::Foo::Class::Broken'/, '... composed our roles correctly' );
}

{
    my $foo = My::Foo::Class->new;
    isa_ok($foo, 'My::Foo::Class');
    can_ok($foo, 'foo');
    is($foo->foo, 'Baz::Role::foo', '... got the right method');
}

{
    package My::Foo::Role;
    use Role::Basic;

    ::is( ::exception {
        with 'Foo::Role' => { -excludes => 'foo' },
             'Bar::Role' => { -excludes => 'foo' },
             'Baz::Role';
    }, undef, '... composed our roles correctly' );
}

ok(My::Foo::Role->can('foo'), "we have a foo method");
ok(!Role::Basic->requires_method("My::Foo::Role", 'foo'), '... and the &foo method is not required');

{
    package My::Foo::Role::Other;
    use Role::Basic;

    # XXX again, a difference with Moose. We guarantee the property of
    # associativity in roles, Moose does not.
    ::like( ::exception {
        with 'Foo::Role',
             'Bar::Role' => { -excludes => 'foo' },
             'Baz::Role';
    }, qr/Due to a method name conflict in roles 'Baz::Role' and 'Foo::Role', the method 'foo' must be implemented or excluded by 'My::Foo::Role::Other'/, '... composed our roles correctly' );
}

TODO: {
    local $TODO = 'We probably should make no guarantees about these failures';
    ok(!My::Foo::Role::Other->can('foo'), "we dont have a foo method");
    ok(Role::Basic->requires_method("My::Foo::Role::Other", 'foo'), '... and the &foo method is required');
}
