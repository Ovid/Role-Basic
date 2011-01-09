#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';
use MyTests tests => 51;

{
    package FooRole;

    our $VERSION = 23;

    use Role::Basic allow => 'TestMethods';
    use TestMethods qw(bar baz);

    sub goo {'FooRole::goo'}
    sub foo {'FooRole::foo'}
}

{
    package BarRole;
    use Role::Basic;;
    sub woot {'BarRole::woot'}
}

{
    package BarClass;

    sub boo {'BarClass::boo'}
    sub foo {'BarClass::foo'}    # << the role overrides this ...
}

{
    
    package FooClass;
    use Role::Basic 'with';

    use base 'BarClass';

    sub new { bless {} => shift }

    eval { with 'FooRole' => { -version => 42 }; 1 }
        or my $error = $@;
    ::like $error, qr/FooRole version 42 required--this is only version 23/,
      'applying role with unsatisfied version requirement';

    $error = '';
    eval { with 'FooRole' => { -version => 13 }; 1 }
        or $error = $@;
    ::ok !$error, 'applying role with satisfied version requirement';

    sub goo {'FooClass::goo'}      # << overrides the one from the role ...
}

{
    package FooBarClass;
    use Role::Basic 'with';

    use base 'FooClass';
    with 'FooRole', 'BarRole';
}


foreach my $method_name (qw(bar baz foo boo goo)) {
    can_ok 'FooBarClass', $method_name;
}

can_ok( 'FooClass', 'DOES' );
ok( FooClass->DOES('FooRole'),    '... the FooClass DOES FooRole' );
ok( !FooClass->DOES('BarRole'),   '... the FooClass DOES not do BarRole' );
ok( !FooClass->DOES('OtherRole'), '... the FooClass DOES not do OtherRole' );

can_ok( 'FooBarClass', 'DOES' );
ok( FooBarClass->DOES('FooRole'), '... the FooClass DOES FooRole' );
ok( FooBarClass->DOES('BarRole'), '... the FooBarClass DOES FooBarRole' );
ok( !FooBarClass->DOES('OtherRole'),
    '... the FooBarClass DOES not do OtherRole' );

my $foo = FooClass->new();
isa_ok( $foo, 'FooClass' );

my $foobar = FooBarClass->new();
isa_ok( $foobar, 'FooBarClass' );

is( $foo->goo,    'FooClass::goo', '... got the right value of goo' );
is( $foobar->goo, 'FooRole::goo',  '... got the right value of goo' );

is( $foo->boo, 'BarClass::boo',
    '... got the right value from ->boo' );
is( $foobar->boo, 'BarClass::boo',
    '... got the right value from ->boo (double wrapped)' );

foreach my $foo ( $foo, $foobar ) {
    can_ok( $foo, 'DOES' );
    ok( $foo->DOES('FooRole'), '... an instance of FooClass DOES FooRole' );
    ok( !$foo->DOES('OtherRole'),
        '... and instance of FooClass DOES not do OtherRole' );

    can_ok( $foobar, 'DOES' );
    ok( $foobar->DOES('FooRole'),
        '... an instance of FooBarClass DOES FooRole' );
    ok( $foobar->DOES('BarRole'),
        '... an instance of FooBarClass DOES BarRole' );
    ok( !$foobar->DOES('OtherRole'),
        '... and instance of FooBarClass DOES not do OtherRole' );

    for my $method (qw/bar baz foo boo goo/) {
        can_ok( $foo, $method );
    }

    is( $foo->foo, 'FooRole::foo', '... got the right value of foo' );

    ok( !defined( $foo->baz ), '... $foo->baz is undefined' );
    ok( !defined( $foo->bar ), '... $foo->bar is undefined' );
}
