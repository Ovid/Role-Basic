package My::Does::Basic;

use Role::Basic;

requires 'turbo_charger';

use constant FOO => 'bar';
use constant a_scalar => 2;
use constant a_sub    => sub { 3 };
use constant an_array => [ 4, 5 ];
use constant a_hash   => { 6 => 7 };

sub no_conflict {
    return "My::Does::Basic::no_conflict";
}

1;
