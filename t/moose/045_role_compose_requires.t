# See https://rt.cpan.org/Ticket/Display.html?id=46347

use strict;
use warnings;

use MyTests skip_all => 'Not yet converted';


{
    package My::Role1;
    use Role::Basic;
    requires 'test_output';
}

{
    package My::Role2;
    use Role::Basic;
    has test_output => ( is => 'rw' );
    with 'My::Role1';
}

{
    package My::Role3;
    use Role::Basic;
    sub test_output { }
    with 'My::Role1';
}

{
    package My::Role4;
    use Role::Basic;
    has test_output => ( is => 'rw' );
}

{
    package My::Role5;
    use Role::Basic;
    sub test_output { }
}

{
    package My::Base1;
    use Role::Basic 'with';
    has test_output => ( is => 'rw' );
}

{
    package My::Base2;
    use Role::Basic 'with';
    sub test_output { }
}

# Roles providing attributes/methods should satisfy requires() of other
# roles they consume.
{
    local $TODO = "role attributes don't satisfy method requirements";
    is( exception { package My::Test1; use Role::Basic 'with'; with 'My::Role2'; }, undef, 'role2(provides attribute) consumes role1' );
}

is( exception { package My::Test2; use Role::Basic 'with'; with 'My::Role3'; }, undef, 'role3(provides method) consumes role1' );

# As I understand the design, Roles composed in the same with() statement
# should NOT demonstrate ordering dependency. Alter these tests if that
# assumption is false. -Vince Veselosky
{
    local $TODO = "role attributes don't satisfy method requirements";
    is( exception { package My::Test3; use Role::Basic 'with'; with 'My::Role4', 'My::Role1'; }, undef, 'class consumes role4(provides attribute), role1' );
}

{
    local $TODO = "role attributes don't satisfy method requirements";
    is( exception { package My::Test4; use Role::Basic 'with'; with 'My::Role1', 'My::Role4'; }, undef, 'class consumes role1, role4(provides attribute)' );
}

is( exception { package My::Test5; use Role::Basic 'with'; with 'My::Role5', 'My::Role1'; }, undef, 'class consumes role5(provides method), role1' );

is( exception { package My::Test6; use Role::Basic 'with'; with 'My::Role1', 'My::Role5'; }, undef, 'class consumes role1, role5(provides method)' );

# Inherited methods/attributes should satisfy requires(), as long as
# extends() comes first in code order.
is( exception {
    package My::Test7;
    use Role::Basic 'with';
    extends 'My::Base1';
    with 'My::Role1';
}, undef, 'class extends base1(provides attribute), consumes role1' );

is( exception {
    package My::Test8;
    use Role::Basic 'with';
    extends 'My::Base2';
    with 'My::Role1';
}, undef, 'class extends base2(provides method), consumes role1' );

# Attributes/methods implemented in class should satisfy requires()
is( exception {

    package My::Test9;
    use Role::Basic 'with';
    has 'test_output', is => 'rw';
    with 'My::Role1';
}, undef, 'class provides attribute, consumes role1' );

is( exception {

    package My::Test10;
    use Role::Basic 'with';
    sub test_output { }
    with 'My::Role1';
}, undef, 'class provides method, consumes role1' );

# Roles composed in separate with() statements SHOULD demonstrate ordering
# dependency. See comment with tests 3-6 above.
is( exception {
    package My::Test11;
    use Role::Basic 'with';
    with 'My::Role4';
    with 'My::Role1';
}, undef, 'class consumes role4(provides attribute); consumes role1' );

isnt( exception { package My::Test12; use Role::Basic 'with'; with 'My::Role1'; with 'My::Role4'; }, undef, 'class consumes role1; consumes role4(provides attribute)' );

is( exception {
    package My::Test13;
    use Role::Basic 'with';
    with 'My::Role5';
    with 'My::Role1';
}, undef, 'class consumes role5(provides method); consumes role1' );

isnt( exception { package My::Test14; use Role::Basic 'with'; with 'My::Role1'; with 'My::Role5'; }, undef, 'class consumes role1; consumes role5(provides method)' );


