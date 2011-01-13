#!/usr/bin/perl

use strict;
use warnings;

use MyTests 'no_plan';
#use MyTests skip_all => 'Not yet converted';

{
    # test no conflicts here
    package Role::A;
    use Role::Basic;

    sub bar { 'Role::A::bar' }

    package Role::B;
    use Role::Basic;

    sub xxy { 'Role::B::xxy' }

    package Role::C;
    use Role::Basic;

    ::is( ::exception {
        with qw(Role::A Role::B); # no conflict here
    }, undef, "define role C" );

    sub foo { 'Role::C::foo' }
    sub zot { 'Role::C::zot' }

    package Class::A;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    ::is( ::exception {
        with qw(Role::C);
    }, undef, "define class A" );

    sub zot { 'Class::A::zot' }
}

can_ok( Class::A->new, qw(foo bar xxy zot) );

is( Class::A->new->foo, "Role::C::foo",  "... got the right foo method" );
is( Class::A->new->zot, "Class::A::zot", "... got the right zot method" );
is( Class::A->new->bar, "Role::A::bar",  "... got the right bar method" );
is( Class::A->new->xxy, "Role::B::xxy",  "... got the right xxy method" );

{
    # check that when a role is added to another role
    # and they conflict and the method they conflict
    # with is then required.

    package Role::A::Conflict;
    use Role::Basic;

    with 'Role::A';

    sub bar { 'Role::A::Conflict::bar' }

    package Class::A::Conflict;
    use Role::Basic 'with';

    ::like( ::exception {
        with 'Role::A::Conflict';
    }, qr/Due to a method name conflict in roles 'Role::A' and 'Role::A::Conflict', the method 'bar' must be implemented or excluded by 'Class::A::Conflict'/, '... did not fufill the requirement of &bar method' );

    package Class::A::Resolved;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    ::is( ::exception {
        with 'Role::A::Conflict';
    }, undef, '... did fufill the requirement of &bar method' );

    sub bar { 'Class::A::Resolved::bar' }
}

TODO: {
    local $TODO = 'Check to see why this is done and if we need it';
    ok(
        Role::Basic->requires_method( 'Role::A::Conflict', 'bar' ),
        '... Role::A::Conflict created the bar requirement'
    );
}

can_ok( Class::A::Resolved->new, qw(bar) );

is( Class::A::Resolved->new->bar, 'Class::A::Resolved::bar', "... got the right bar method" );

{
    # check that when two roles are composed, they conflict
    # but the composing role can resolve that conflict

    package Role::D;
    use Role::Basic;

    sub foo { 'Role::D::foo' }
    sub bar { 'Role::D::bar' }

    package Role::E;
    use Role::Basic;

    sub foo { 'Role::E::foo' }
    sub xxy { 'Role::E::xxy' }

    package Role::F;
    use Role::Basic;

    ::is( ::exception {
        with qw(Role::D Role::E); # conflict between 'foo's here
    }, undef, "define role Role::F" );

    sub foo { 'Role::F::foo' }
    sub zot { 'Role::F::zot' }

    package Class::B;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    # XXX this is different from Moose. Traits are required, amongst other
    # things, as being "associative". Moose breaks with that. We keep this
    # behavior (for now) as it's easier to be restrictive and let up than the
    # other way around. See
    # http://blogs.perl.org/users/ovid/2011/01/rolebasic-what-is-a-conflict.html
    # for more detail.
    ::like( ::exception {
        with qw(Role::F);
    }, qr/\QDue to a method name conflict in roles 'Role::D' and 'Role::E' and 'Role::F', the method 'foo' must be implemented or excluded by 'Class::B'/, "define class Class::B" );

    sub zot { 'Class::B::zot' }
}

# XXX lots of Moose tests deleted as they don't apply to Role::Basic

{
    # conflict propagation

    package Role::H;
    use Role::Basic;

    sub foo { 'Role::H::foo' }
    sub bar { 'Role::H::bar' }

    package Role::J;
    use Role::Basic;

    sub foo { 'Role::J::foo' }
    sub xxy { 'Role::J::xxy' }

    package Role::I;
    use Role::Basic;

    # XXX another difference with Moose. Originally we deferred conflicts to
    # the consuming class, but their was no syntax to allow the class to
    # understand the role's composition and pick it apart (i.e., exclude
    # methods from the roles this role consumed). Thus, we throw an exception
    # as it's safer.
    ::isnt( ::exception {
        with qw(Role::J Role::H); # conflict between 'foo's here
    }, undef, "define role Role::I" );

    sub zot { 'Role::I::zot' }
    sub zzy { 'Role::I::zzy' }

    package Class::C;
    use Role::Basic 'with';

    ::like( ::exception {
        with qw(Role::I);
    }, qr/Due to a method name conflict in roles 'Role::H' and 'Role::J', the method 'foo' must be implemented or excluded by 'Class::C'/, "defining class Class::C fails" );

    sub zot { 'Class::C::zot' }

    package Class::E;
    use Role::Basic 'with';
    sub new { bless {} => shift }

    ::is( ::exception {
        with qw(Role::I);
    }, undef, "resolved with method" );

    sub foo { 'Class::E::foo' }
    sub zot { 'Class::E::zot' }
}

can_ok( Class::E->new, qw(foo bar xxy zot) );

is( Class::E->new->foo, "Class::E::foo", "... got the right &foo method" );
is( Class::E->new->zot, "Class::E::zot", "... got the right &zot method" );
is( Class::E->new->bar, "Role::H::bar",  "... got the right &bar method" );
is( Class::E->new->xxy, "Role::J::xxy",  "... got the right &xxy method" );

TODO: {
    local $TODO = 'We do not convert conflicts to requirements. Should we?';
    ok(
        Role::Basic->requires_method( 'Role::I', 'foo' ),
        '... Role::I still have the &foo requirement'
    );
}

{
    is( exception {
        package Class::D;
        use Role::Basic 'with';
        sub new { bless {} => shift }

        sub foo { "Class::D::foo" }

        sub zot { 'Class::D::zot' }

        with qw(Role::I);

    }, undef, "resolved with attr" );

    can_ok( Class::D->new, qw(foo bar xxy zot) );
    is( eval { Class::D->new->bar }, "Role::H::bar", "bar" );
    is( eval { Class::D->new->zzy }, "Role::I::zzy", "zzy" );

    is( eval { Class::D->new->foo }, "Class::D::foo", "foo" );
    is( eval { Class::D->new->zot }, "Class::D::zot", "zot" );

}
