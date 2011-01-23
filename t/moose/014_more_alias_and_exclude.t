#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib', 't/lib';
use MyTests tests => 9;

{
    package Foo;
    use Role::Basic;

    sub foo   { 'Foo::foo'   }
    sub bar   { 'Foo::bar'   }
    sub baz   { 'Foo::baz'   }
    sub gorch { 'Foo::gorch' }

    package Bar;
    use Role::Basic;

    sub foo   { 'Bar::foo'   }
    sub bar   { 'Bar::bar'   }
    sub baz   { 'Bar::baz'   }
    sub gorch { 'Bar::gorch' }

    package Baz;
    use Role::Basic;

    sub foo   { 'Baz::foo'   }
    sub bar   { 'Baz::bar'   }
    sub baz   { 'Baz::baz'   }
    sub gorch { 'Baz::gorch' }

    package Gorch;
    use Role::Basic;

    sub foo   { 'Gorch::foo'   }
    sub bar   { 'Gorch::bar'   }
    sub baz   { 'Gorch::baz'   }
    sub gorch { 'Gorch::gorch' }
}

{
    package My::Class;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    ::is( ::exception {
        with 'Foo'   => { -excludes => [qw/bar baz gorch/], -alias => { gorch => 'foo_gorch' } },
             'Bar'   => { -excludes => [qw/foo baz gorch/] },
             'Baz'   => { -excludes => [qw/foo bar gorch/], -alias => { foo => 'baz_foo', bar => 'baz_bar' } },
             'Gorch' => { -excludes => [qw/foo bar baz/] };
    }, undef, '... everything works out all right' );
}

my $c = My::Class->new;
isa_ok($c, 'My::Class');

is($c->foo, 'Foo::foo', '... got the right method');
is($c->bar, 'Bar::bar', '... got the right method');
is($c->baz, 'Baz::baz', '... got the right method');
is($c->gorch, 'Gorch::gorch', '... got the right method');

is($c->foo_gorch, 'Foo::gorch', '... got the right method');
is($c->baz_foo, 'Baz::foo', '... got the right method');
is($c->baz_bar, 'Baz::bar', '... got the right method');


