package My::Does::Basic;

use Role::Basic;

requires 'turbo_charger';

use constant FOO => 'bar';

sub no_conflict {
    return "My::Does::Basic::no_conflict";
}

1;
