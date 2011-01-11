#!/usr/bin/perl

use strict;
use warnings;

use MyTests skip_all => 'Not yet converted';

use Scalar::Util 'blessed';


{
    package Dog;
    use Role::Basic;

    sub talk { 'woof' }

    package Foo;
    use Role::Basic 'with';

    has 'dog' => (
        is   => 'rw',
        does => 'Dog',
    );

    no Moose;

    package Bar;

    sub new {
      return bless {}, shift;
    }
}

my $bar = Bar->new;
isa_ok($bar, 'Bar');

my $foo = Foo->new;
isa_ok($foo, 'Foo');

ok(!$bar->can( 'talk' ), "... the role is not composed yet");

isnt( exception {
    $foo->dog($bar)
}, undef, '... and setting the accessor fails (not a Dog yet)' );

Dog->meta->apply($bar);

ok($bar->can('talk'), "... the role is now composed at the object level");

is($bar->talk, 'woof', '... got the right return value for the newly composed method');

is( exception {
    $foo->dog($bar)
}, undef, '... and setting the accessor is okay' );


