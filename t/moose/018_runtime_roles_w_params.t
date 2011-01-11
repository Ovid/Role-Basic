#!/usr/bin/perl

use strict;
use warnings;

use MyTests 'no_plan';



{
    package Foo;
    use Role::Basic 'with';
    has 'bar' => (is => 'ro');

    package Bar;
    use Role::Basic;

    has 'baz' => (is => 'ro', default => 'BAZ');
}

# normal ...
{
    my $foo = Foo->new(bar => 'BAR');
    isa_ok($foo, 'Foo');

    is($foo->bar, 'BAR', '... got the expect value');
    ok(!$foo->can('baz'), '... no baz method though');

    is( exception {
        Bar->meta->apply($foo)
    }, undef, '... this works' );

    is($foo->bar, 'BAR', '... got the expect value');
    ok($foo->can('baz'), '... we have baz method now');
    is($foo->baz, 'BAZ', '... got the expect value');
}

# with extra params ...
{
    my $foo = Foo->new(bar => 'BAR');
    isa_ok($foo, 'Foo');

    is($foo->bar, 'BAR', '... got the expect value');
    ok(!$foo->can('baz'), '... no baz method though');

    is( exception {
        Bar->meta->apply($foo, (rebless_params => { baz => 'FOO-BAZ' }))
    }, undef, '... this works' );

    is($foo->bar, 'BAR', '... got the expect value');
    ok($foo->can('baz'), '... we have baz method now');
    is($foo->baz, 'FOO-BAZ', '... got the expect value');
}

# with extra params ...
{
    my $foo = Foo->new(bar => 'BAR');
    isa_ok($foo, 'Foo');

    is($foo->bar, 'BAR', '... got the expect value');
    ok(!$foo->can('baz'), '... no baz method though');

    is( exception {
        Bar->meta->apply($foo, (rebless_params => { bar => 'FOO-BAR', baz => 'FOO-BAZ' }))
    }, undef, '... this works' );

    is($foo->bar, 'FOO-BAR', '... got the expect value');
    ok($foo->can('baz'), '... we have baz method now');
    is($foo->baz, 'FOO-BAZ', '... got the expect value');
}


