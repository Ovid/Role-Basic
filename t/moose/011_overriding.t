#!/usr/bin/perl

use strict;
use warnings;

use MyTests skip_all => 'Not yet converted';

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

    ::is( ::exception {
        with qw(Role::F);
    }, undef, "define class Class::B" );

    sub zot { 'Class::B::zot' }
}

__END__
can_ok( Class::B->new, qw(foo bar xxy zot) );

is( Class::B->new->foo, "Role::F::foo",  "... got the &foo method okay" );
is( Class::B->new->zot, "Class::B::zot", "... got the &zot method okay" );
is( Class::B->new->bar, "Role::D::bar",  "... got the &bar method okay" );
is( Class::B->new->xxy, "Role::E::xxy",  "... got the &xxy method okay" );

ok(!Role::Basic->requires_method('Role::F','foo'), '... Role::F fufilled the &foo requirement');

{
    # check that a conflict can be resolved
    # by a role, but also new ones can be
    # created just as easily ...

    package Role::D::And::E::Conflict;
    use Role::Basic;

    ::is( ::exception {
        with qw(Role::D Role::E); # conflict between 'foo's here
    }, undef, "... define role Role::D::And::E::Conflict" );

    sub foo { 'Role::D::And::E::Conflict::foo' }  # this overrides ...

    # but these conflict
    sub xxy { 'Role::D::And::E::Conflict::xxy' }
    sub bar { 'Role::D::And::E::Conflict::bar' }

}

ok(!Role::Basic->requires_method('Role::D::And::E::Conflict', 'foo'), '... Role::D::And::E::Conflict fufilled the &foo requirement');
ok( Role::Basic->requires_method('Role::D::And::E::Conflict', 'xxy'), '... Role::D::And::E::Conflict adds the &xxy requirement');
ok( Role::Basic->requires_method('Role::D::And::E::Conflict', 'bar'), '... Role::D::And::E::Conflict adds the &bar requirement');

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

    ::is( ::exception {
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

ok(Role::Basic->requires_method('Role::I', 'foo'), '... Role::I still have the &foo requirement');

{
    is( exception {
        package Class::D;
        use Role::Basic 'with';

        sub foo { __PACKAGE__ }

        sub zot { 'Class::D::zot' }

        with qw(Role::I);

    }, undef, "resolved with attr" );

    can_ok( Class::D->new, qw(foo bar xxy zot) );
    is( eval { Class::D->new->bar }, "Role::H::bar", "bar" );
    is( eval { Class::D->new->zzy }, "Role::I::zzy", "zzy" );

    is( eval { Class::D->new->foo }, "Class::D::foo", "foo" );
    is( eval { Class::D->new->zot }, "Class::D::zot", "zot" );

}
