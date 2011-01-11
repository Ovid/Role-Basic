use strict;
use warnings;

use MyTests skip_all => 'Not yet converted';

{
    package My::Role1;
    use Role::Basic;

    has foo => (
        is => 'ro',
    );

}

{
    package My::Role2;
    use Role::Basic;

    has foo => (
        is => 'ro',
    );

    ::like( ::exception { with 'My::Role1' }, qr/attribute conflict.+My::Role2.+foo/, 'attribute conflict when composing one role into another' );
}


