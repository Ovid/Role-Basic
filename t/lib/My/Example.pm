package My::Example;

use Role::Basic 'with';

with 'My::Does::Basic';

sub new { bless {} => shift }

sub turbo_charger {}
$My::Example::foo = 1;
sub foo() {}

1;
