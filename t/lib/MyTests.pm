package MyTests;

use strict;
use warnings;

use Test::More ();
use Try::Tiny;

sub import {
    my $class  = shift;
    my $caller = caller;

    no strict 'refs';
    *{"${caller}::exception"} = \&exception;
    local $" = ", ";
    use Data::Dumper;
    $Data::Dumper::Terse = 1;
    @_                   = Dumper(@_);
    eval <<"    END";
    package $caller;
    no strict;
    use Test::More @_;
    END
    die $@ if $@;
}

sub exception (&) {
    my ($code) = @_;

    return try {
        $code->();
        return undef;
    }
    catch {
        return $_ if $_;

        my $problem = defined $_ ? 'false' : 'undef';
        Carp::confess("$problem exception caught by Test::Fatal::exception");
    };
}

1;
