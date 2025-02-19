package MyTests;

use strict;
use warnings;

use Test::More ();

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

    my $result;
    eval {
        $code->();
        $result = undef;
        1;
    }
    or do {
        if ( $result = $@ ) {
            # do nothing
        }
        else {
            my $problem = defined $_ ? 'false' : 'undef';
            Carp::confess("$problem exception caught by Test::Fatal::exception");
        }
    };
    return $result;
}

1;
