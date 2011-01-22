#!/usr/bin/perl

use strict;
use warnings;

use MyTests tests => 21;

{

    package Foo::Role;
    use Role::Basic;

    requires 'foo';
}

is_deeply( [ Role::Basic->get_required_by('Foo::Role') ],
    ['foo'], '... the Foo::Role has a required method (foo)' );

# classes which does not implement required method
{

    package Foo::Class;
    use Role::Basic 'with';

    ::isnt( ::exception { with('Foo::Role') }, undef, '... no foo method implemented by Foo::Class' );
}

# class which does implement required method
{

    package Bar::Class;
    use Role::Basic 'with';

    ::isnt( ::exception { with('Foo::Class') }, undef, '... cannot consume a class, it must be a role' );
    ::is( ::exception { with('Foo::Role') }, undef, '... has a foo method implemented by Bar::Class' );

    sub foo {'Bar::Class::foo'}
}

# role which does implement required method
{

    package Bar::Role;
    use Role::Basic;

    ::is( ::exception { with('Foo::Role') }, undef, '... has a foo method implemented by Bar::Role' );

    sub foo {'Bar::Role::foo'}
}

# XXX this is different from Moose. In Moose, roles can be applied
# dynamically, so sharing the requirements on a class basis is bad. We don't
# allow this in Role::Basic, so it's OK. 
is_deeply(
    [ sort Role::Basic->get_required_by('Bar::Role') ],
    ['foo'],
    '... the Bar::Role has inherited the required method from Foo::Role'
);

# role which does not implement required method
{

    package Baz::Role;
    use Role::Basic;

    ::is( ::exception { with('Foo::Role') }, undef, '... no foo method implemented by Baz::Role' );
}

is_deeply(
    [ Role::Basic->get_required_by('Baz::Role') ],
    ['foo'],
    '... the Baz::Role has inherited the required method from Foo::Role'
);

# classes which does not implement required method
{

    package Baz::Class;
    use Role::Basic 'with';

    ::isnt( ::exception { with('Baz::Role') }, undef, '... no foo method implemented by Baz::Class2' );
}

# class which does implement required method
{

    package Baz::Class2;
    use Role::Basic 'with';

    ::is( ::exception { with('Baz::Role') }, undef, '... has a foo method implemented by Baz::Class2' );

    sub foo {'Baz::Class2::foo'}
}


{
    package Quux::Role;
    use Role::Basic;

    requires qw( meth1 meth2 meth3 meth4 );
}

# RT #41119
{

    package Quux::Class;
    use Role::Basic 'with';

    my $exception = ::exception { with('Quux::Role') };
    ::like( $exception, qr/\Q'Quux::Role' requires the method 'meth1' to be implemented by 'Quux::Class'/, 'exception mentions all the missing required methods at once' );
    ::like( $exception, qr/\Q'Quux::Role' requires the method 'meth2' to be implemented by 'Quux::Class'/, 'exception mentions all the missing required methods at once' );
    ::like( $exception, qr/\Q'Quux::Role' requires the method 'meth3' to be implemented by 'Quux::Class'/, 'exception mentions all the missing required methods at once' );
    ::like( $exception, qr/\Q'Quux::Role' requires the method 'meth4' to be implemented by 'Quux::Class'/, 'exception mentions all the missing required methods at once' );
}

{
    package Quux::Class2;
    use Role::Basic 'with';

    sub meth1 { }

    my $exception = ::exception { with('Quux::Role') };
    ::like( $exception, qr/'Quux::Role' requires the method 'meth2' to be implemented by 'Quux::Class2'/, 'exception mentions all the missing required methods at once, but not the one that exists' );
    ::like( $exception, qr/'Quux::Role' requires the method 'meth3' to be implemented by 'Quux::Class2'/, 'exception mentions all the missing required methods at once, but not the one that exists' );
    ::like( $exception, qr/'Quux::Role' requires the method 'meth4' to be implemented by 'Quux::Class2'/, 'exception mentions all the missing required methods at once, but not the one that exists' );
}

{
    package Quux::Class3;
    use Role::Basic 'with';

    my $exception = ::exception { with('Quux::Role') };
    ::like( $exception, qr/'Quux::Role' requires the method 'meth3' to be implemented by 'Quux::Class3'/, 'exception mentions all the missing methods at once, but not the accessors' );
    ::like( $exception, qr/'Quux::Role' requires the method 'meth4' to be implemented by 'Quux::Class3'/, 'exception mentions all the missing methods at once, but not the accessors' );
}

{
    package Quux::Class4;
    use Role::Basic 'with';

    sub meth1 { }

    my $exception = ::exception { with('Quux::Role') };
    ::like( $exception, qr/'Quux::Role' requires the method 'meth3' to be implemented by 'Quux::Class4'/, 'exception mentions all the missing methods at once, but not the accessors' );
    ::like( $exception, qr/'Quux::Role' requires the method 'meth4' to be implemented by 'Quux::Class4'/, 'exception mentions all the missing methods at once, but not the accessors' );
}
