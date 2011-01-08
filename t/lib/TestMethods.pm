package TestMethods;

use strict;
use warnings;

sub import {
    my ( $class, @methods ) = @_;
    my $target = caller;

    foreach my $method (@methods) {
        my $fq_method = $target . "::$method";
        no strict 'refs';
        *$fq_method = sub {
            local *__ANON__ = "__ANON__$fq_method";
            my $self = shift;
            return $self->{$method} unless @_;
            $self->{$method} = shift;
            return $self;
        };
    }
}

1;
