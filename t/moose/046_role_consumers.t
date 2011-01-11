use strict;
use warnings;

use MyTests skip_all => 'Not yet converted';

{
    package Foo::Role;
    use Role::Basic;
}

{
    package Bar::Role;
    use Role::Basic;
}

{
    package Foo;
    use Role::Basic 'with';
    with 'Foo::Role';
}

{
    package Bar;
    use Role::Basic 'with';
    extends 'Foo';
    with 'Bar::Role';
}

{
    package FooBar;
    use Role::Basic 'with';
    with 'Foo::Role', 'Bar::Role';
}

{
    package Foo::Role::User;
    use Role::Basic;
    with 'Foo::Role';
}

{
    package Foo::User;
    use Role::Basic 'with';
    with 'Foo::Role::User';
}

is_deeply([sort Foo::Role->meta->consumers],
          ['Bar', 'Foo', 'Foo::Role::User', 'Foo::User', 'FooBar']);
is_deeply([sort Bar::Role->meta->consumers],
          ['Bar', 'FooBar']);
is_deeply([sort Foo::Role::User->meta->consumers],
          ['Foo::User']);


