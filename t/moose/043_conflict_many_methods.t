#!/usr/bin/perl
use strict;
use warnings;

use MyTests tests => 3;

{
    package Bomb;
    use Role::Basic;

    sub fuse { }
    sub explode { }

    package Spouse;
    use Role::Basic;

    sub fuse { }
    sub explode { }

    package Caninish;
    use Role::Basic;

    sub bark { }

    package Treeve;
    use Role::Basic;

    sub bark { }
}

{
    package PracticalJoke;
    use Role::Basic 'with';

    my $exception = ::exception { with 'Bomb', 'Spouse' };
    ::like( $exception,
qr/Due to a method name conflict in roles 'Bomb' and 'Spouse', the method 'fuse' must be implemented or excluded by 'PracticalJoke'/
    );

    ::like $exception, qr/Due to a method name conflict in roles 'Bomb' and 'Spouse', the method 'explode' must be implemented or excluded by 'PracticalJoke'/,
        '... and all methods will be listed in the exception';

    package PracticalJoke2;
    use Role::Basic 'with';
    ::like( ::exception {
        with (
            'Bomb', 'Spouse',
            'Caninish', 'Treeve',
        );
    }, qr/Due to a method name conflict in roles 'Caninish' and 'Treeve', the method 'bark' must be implemented or excluded by 'PracticalJoke2'/ );
}
