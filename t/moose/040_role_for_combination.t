#!/usr/bin/env perl
use strict;
use warnings;
use MyTests skip_all => 'Not yet converted';

my $OPTS;
do {
    package My::Singleton::Role;
    use Role::Basic;

    sub foo { 'My::Singleton::Role' }

    package My::Role::Metaclass;
    use Role::Basic 'with';
    BEGIN { extends 'Moose::Meta::Role' };

    sub _role_for_combination {
        my ($self, $opts) = @_;
        $OPTS = $opts;
        return My::Singleton::Role->meta;
    }

    package My::Special::Role;
    use Moose::Role -metaclass => 'My::Role::Metaclass';

    sub foo { 'My::Special::Role' }

    package My::Usual::Role;
    use Role::Basic;

    sub bar { 'My::Usual::Role' }

    package My::Class;
    use Role::Basic 'with';

    with (
        'My::Special::Role' => { number => 1 },
        'My::Usual::Role' => { number => 2 },
    );
};

is(My::Class->foo, 'My::Singleton::Role', 'role_for_combination applied');
is(My::Class->bar, 'My::Usual::Role', 'collateral role');
is_deeply($OPTS, { number => 1 });


