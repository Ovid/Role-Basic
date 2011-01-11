#!/usr/bin/perl
use strict;
use warnings;

use MyTests skip_all => 'Not yet converted';


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

    ::like( ::exception {
        with 'Bomb', 'Spouse';
    }, qr/Due to method name conflicts in roles 'Bomb' and 'Spouse', the methods 'explode' and 'fuse' must be implemented or excluded by 'PracticalJoke'/ );

    ::like( ::exception {
        with (
            'Bomb', 'Spouse',
            'Caninish', 'Treeve',
        );
    }, qr/Due to a method name conflict in roles 'Caninish' and 'Treeve', the method 'bark' must be implemented or excluded by 'PracticalJoke'/ );
}


