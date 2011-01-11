use strict;
use warnings;
use MyTests skip_all => 'Not yet converted';

{
    package Foo;
    use Role::Basic;

    use overload
        q{""}    => sub { 42 },
        fallback => 1;

    no Role::Basic;
}

{
    package Bar;
    use Role::Basic 'with';
    with 'Foo';
    sub new { bless {} => shift }
    no Role::Basic;
}

my $bar = Bar->new;

TODO: {
    local $TODO = "the special () method isn't properly composed into the class";
    is("$bar", 42, 'overloading can be composed');
}


