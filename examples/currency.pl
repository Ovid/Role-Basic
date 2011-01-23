#!/usr/bin/env perl

use strict;
use warnings;

{

    package Eq;
    use Role::Basic;

    requires 'equal_to';

    sub not_equal_to {
        my ( $self, $other ) = @_;
        not $self->equal_to($other);
    }

    package Comparable;
    use Role::Basic;

    with 'Eq';

    requires 'compare';

    sub equal_to {
        my ( $self, $other ) = @_;
        $self->compare($other) == 0;
    }

    sub greater_than {
        my ( $self, $other ) = @_;
        $self->compare($other) == 1;
    }

    sub less_than {
        my ( $self, $other ) = @_;
        $self->compare($other) == -1;
    }

    sub greater_than_or_equal_to {
        my ( $self, $other ) = @_;
        $self->greater_than($other) || $self->equal_to($other);
    }

    sub less_than_or_equal_to {
        my ( $self, $other ) = @_;
        $self->less_than($other) || $self->equal_to($other);
    }

    package Printable;
    use Role::Basic;

    requires 'to_string';

    package US::Currency;
    use Role::Basic 'with';

    with 'Comparable', 'Printable';

    # note that writing this constructor would not be needed with Moose and it
    # would have better validation
    sub new {
        my ( $class, $arg_for ) = @_;
        $arg_for ||= {};
        my $amount = $arg_for->{amount} || 0;
        bless { amount => $amount } => $class;
    }

    sub amount {
        my $self = shift;
        return $self->{amount} unless @_;
        $self->{amount} = shift;
    }

    sub compare {
        my ( $self, $other ) = @_;
        $self->amount <=> $other->amount;
    }

    sub to_string {
        my $self = shift;
        sprintf '$%0.2f USD' => $self->amount;
    }
}

my $first = US::Currency->new({ amount => 3.12 });
my $second = US::Currency->new({ amount => 1 });
print $first->to_string,  "\n";
print $second->to_string, "\n";
print $first->greater_than($second) ? 'yes' : 'no';
