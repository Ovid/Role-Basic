package MyTests;

use strict;
use warnings;

use Test::More ();

sub import {
    my $class = shift;
    my $caller = caller;

    no strict 'refs';
    *{"${caller}::fake_load"} = sub (;$) {
        my $package = caller || shift;
        $package =~ s{::}{/}g;
        $INC{"$package.pm"} = 'fake_load';
    };
    local $" = ", ";
    use Data::Dumper;
    $Data::Dumper::Terse = 1;
    @_ = Dumper(@_);
    eval <<"    END";
    package $caller;
    no strict;
    use Test::More @_;
    END
    die $@ if $@;
}

1;
