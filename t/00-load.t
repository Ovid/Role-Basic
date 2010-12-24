#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Role::Basic' ) || BAIL_OUT "Could not load Role::Basic: $!";
}

diag( "Testing Role::Basic $Role::Basic::VERSION, Perl $], $^X" );
