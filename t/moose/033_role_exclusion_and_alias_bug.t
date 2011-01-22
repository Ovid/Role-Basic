#!/usr/bin/perl

use strict;
use warnings;

use MyTests tests => 17;

{
    package My::Role;
    use Role::Basic;

    sub foo { "FOO" }
    sub bar { "BAR" }
}

{
    package My::Class;
    use Role::Basic 'with';
    sub new { bless {} => shift }
    with 'My::Role' => { -rename => { foo => 'baz', bar => 'gorch' }, };
}

{
    my $x = My::Class->new;
    isa_ok($x, 'My::Class');
    ok $x->DOES('My::Role'), 'My::Class should do My::Role';

    can_ok($x, $_) for qw[baz gorch];

    ok(!$x->can($_), '... cant call method ' . $_) for qw[foo bar];

    is($x->baz, 'FOO', '... got the right value');
    is($x->gorch, 'BAR', '... got the right value');
}

{
    package My::Role::Again;
    use Role::Basic;

    with 'My::Role' => { -rename => { foo => 'baz', bar => 'gorch' }, };

    package My::Class::Again;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    sub foo {}
    sub bar {}

    with 'My::Role::Again';
}

{
    my $x = My::Class::Again->new;
    isa_ok($x, 'My::Class::Again');
    ok $x->DOES('My::Role::Again'), 'My::Class::Again should do My::Role::Again';
    ok $x->DOES('My::Role'), 'My::Class::Again should do My::Role';

    can_ok($x, $_) for qw[baz gorch];

    # XXX [!Moose] We use -rename above. This is a combination of -alias and
    # -excludes.  Because -excludes adds the methods to requirements, they now
    # much be provided. This guarantess that if a class responds to
    # $class->DOES($role), you can guarantee that methods of the same name as
    # $role methods will exist, even if you can't guarantee that they'll be
    # the same methods.
    ok($x->can($_), '... cant call method ' . $_) for qw[foo bar];

    is($x->baz, 'FOO', '... got the right value');
    is($x->gorch, 'BAR', '... got the right value');
}
