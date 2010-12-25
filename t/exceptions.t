#!/usr/bin/env perl

use Test::Most;
use Carp::Always;
use lib 'lib', 't/lib';
use Role::Basic ();

throws_ok { Role::Basic->_load_role('My::Example') }
    qr/Only roles defined with Role::Basic may be loaded/,
    'Trying to load non-roles should fail';

eval <<'END_PACKAGE';
package My::Bad::MultipleWith;
use Role::Basic 'with';
with 'My::Does::Basic';
with 'My::Does::Basic';  # can't use with() more than once
sub turbo_charger {}
END_PACKAGE
like $@, qr/with\(\) may not be called more than once for My::Bad::MultipleWith/,
    'Trying to use with() more than once in a package should fail';

eval <<'END_PACKAGE';
package My::Bad::Import; 
use Role::Basic 'wtih';  # with, not 'wtih'
END_PACKAGE
like $@, qr/\QMultiple or unknown argument(s) in import list: (wtih)/,
    'Trying to use Role::Basic with an import argument other than "with" shoudl fail';

eval <<'END_PACKAGE';
package My::Bad::Import; 
use Role::Basic qw(with this);
END_PACKAGE
like $@, qr/\QMultiple or unknown argument(s) in import list: (with, this)/,
    'Trying to use Role::Basic multiple arguments to the import list should fail';

eval <<'END_PACKAGE';
package My::Bad::Requirement;
use Role::Basic 'with';
with 'My::Does::Basic'; # requires turbo_charger
END_PACKAGE
like $@, qr/'My::Does::Basic' requires the method 'turbo_charger' to be implemented by 'My::Bad::Requirement'/,
    'Trying to use with() more than once in a package should fail';
done_testing;
