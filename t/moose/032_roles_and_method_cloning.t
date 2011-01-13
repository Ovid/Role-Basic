#!/usr/bin/perl

use strict;
use warnings;

use MyTests tests => 10;

{
    package Role::Foo;
    use Role::Basic;

    sub foo { (caller(0))[3] }
}

{
    package ClassA;
    use Role::Basic 'with';

    with 'Role::Foo';
}

{
    my $meth = ClassA->can('foo');
    ok( $meth, 'ClassA has a foo method' );
    is( $meth, Role::Foo->can('foo'),
        'ClassA->foo was cloned from Role::Foo->foo' );
}

{
    package Role::Bar;
    use Role::Basic;
    with 'Role::Foo';

    sub bar { }
}

{
    my $meth = Role::Bar->can('foo');
    ok( $meth, 'Role::Bar has a foo method' );
    is( $meth, Role::Foo->can('foo'),
        'Role::Bar->foo was cloned from Role::Foo->foo' );
}

{
    package ClassB;
    use Role::Basic 'with';

    with 'Role::Bar';
}

{
    my $meth = ClassB->can('foo');
    ok( $meth, 'ClassB has a foo method' );
    is( $meth, Role::Bar->can('foo'),
        'ClassA->foo was cloned from Role::Bar->foo' );
    is( $meth, Role::Foo->can('foo'),
        '... which in turn was cloned from Role::Foo->foo' );
}

isnt( ClassA->foo, "ClassB::foo", "ClassA::foo is not confused with ClassB::foo");

is( ClassB->foo, 'Role::Foo::foo', 'ClassB::foo knows its name' );
is( ClassA->foo, 'Role::Foo::foo', 'ClassA::foo knows its name' );


