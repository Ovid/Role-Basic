#!/usr/bin/env perl

use lib 'lib', 't/lib';
use MyTests tests => 12;
require Role::Basic;

{
    package My::Does::Basic;

    use Role::Basic;

    requires 'turbo_charger';

    sub conflict {
        return "My::Does::Basic::conflict";
    }
}

eval { Role::Basic->_load_role('My::Example') };
my $error = $@;
like $error, qr/Only roles defined with Role::Basic may be loaded/,
  'Trying to load non-roles should fail';

eval <<'END_PACKAGE';
package My::Bad::MultipleWith;
use Role::Basic 'with';
with 'My::Does::Basic';
with 'My::Does::Basic';  # can't use with() more than once
sub turbo_charger {}
END_PACKAGE
like $@,
  qr/with\(\) may not be called more than once for My::Bad::MultipleWith/,
  'Trying to use with() more than once in a package should fail';

eval <<'END_PACKAGE';
package My::Bad::Import; 
use Role::Basic 'wtih';  # with, not 'wtih'
END_PACKAGE
like $@, qr/\QMultiple or unknown argument(s) in import list: (wtih)/,
'Trying to use Role::Basic with an import argument other than "with" should fail';

eval <<'END_PACKAGE';
package My::Bad::MultipleArgsToImport; 
use Role::Basic qw(with this);
END_PACKAGE
like $@, qr/\QMultiple or unknown argument(s) in import list: (with, this)/,
  'Trying to use Role::Basic multiple arguments to the import list should fail';

eval <<'END_PACKAGE';
package My::Bad::Requirement;
use Role::Basic 'with';
with 'My::Does::Basic'; # requires turbo_charger
END_PACKAGE
like $@,
qr/'My::Does::Basic' requires the method 'turbo_charger' to be implemented by 'My::Bad::Requirement'/,
  'Trying to use a role without providing required methods should fail';

{
    local $ENV{PERL_ROLE_OVERRIDE_DIE} = 1;
    eval <<'    END_PACKAGE';
    package My::Bad::Override;
    use Role::Basic 'with';
    with 'My::Does::Basic'; # requires turbo_charger
    sub turbo_charger {}
    sub conflict {}
    END_PACKAGE
    like $@,
qr/Role 'My::Does::Basic' not overriding method 'conflict' in 'My::Bad::Override'/,
'Trying to override methods with roles should die if PERL_ROLE_OVERRIDE_DIE is set';
}

{
    {
        package My::Conflict;
        use Role::Basic;
        sub conflict {};
    }
    eval <<'    END_PACKAGE';
    package My::Bad::MethodConflicts;
    use Role::Basic 'with';
    with qw(My::Does::Basic My::Conflict);
    sub turbo_charger {}
    END_PACKAGE
    like $@,
    qr/Due to a method name conflict in roles 'My::Conflict' and 'My::Does::Basic', the method 'conflict' must be implemented or excluded by 'My::Bad::MethodConflicts'/,
      'Trying to use multiple roles with the same method should fail';
}

{
    local $ENV{PERL_ROLE_OVERRIDE_DIE} = 1;
    {
        package My::Conflict2;
        use Role::Basic;
        sub conflict {};
    }
    eval <<'    END_PACKAGE';
    package My::Bad::MethodConflicts2;
    use Role::Basic 'with';
    with 'My::Does::Basic',
         'My::Conflict2' => { -alias => { conflict => 'turbo_charger' } };
    sub turbo_charger {}
    END_PACKAGE
    like $@,
    qr/\QCannot alias 'conflict' to 'turbo_charger' as a method of that name already exists in My::Bad::MethodConflicts2/,
      'Trying to alias a conflicting method to an existing one in the package should fail';
}

{
    eval <<'    END_PACKAGE';
    {
        package My::Does::AnotherConflict;
        use Role::Basic;
        sub conflict {};
    }
    package My::Bad::NoMethodConflicts;
    use Role::Basic 'with';
    with 'My::Does::Basic'           => { -excludes => 'conflict' },
         'My::Does::AnotherConflict';
    sub turbo_charger {}
    END_PACKAGE
    ok !$@, 'Excluding role methods should succeed' or diag $@;
}

{
    {
        package Role1;
        use Role::Basic;
        requires 'missing_method';
        sub method1 { 'method1' }
    }
    {
        package Role2;
        use Role::Basic;
        with 'Role1';
        sub method2 { 'method2' }
    }
    eval <<"    END";
    package My::Class::Missing1;
    use Role::Basic 'with';
    with 'Role2';
    END
    like $@,
    qr/'Role1|Role2' requires the method 'missing_method' to be implemented by 'My::Class::Missing1'/,
      'Roles composed from roles should propogate requirements upwards';
}
{
    {
        package Role3;
        use Role::Basic;
        requires qw(this that);
    }
    eval <<"    END";
    package My::Class::Missing2;
    use Role::Basic 'with';
    with 'Role3';
    END
    like $@,
    qr/'Role3' requires the method 'this' to be implemented by 'My::Class::Missing2'/,
      'Roles should be able to require multiple methods';
    like $@,
    qr/'Role3' requires the method 'that' to be implemented by 'My::Class::Missing2'/,
      '... and have all of them provided in the error messages';
}
