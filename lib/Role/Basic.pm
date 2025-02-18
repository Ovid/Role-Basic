package Role::Basic;

sub _getglob { \*{ $_[0] } }

use strict;
use warnings FATAL => 'all';

use B qw/svref_2object/;
use Storable ();
use Carp ();
use Data::Dumper ();

our $VERSION = '0.13';

# eventually clean these up
my ( %IS_ROLE, %REQUIRED_BY, %HAS_ROLES, %ALLOWED_BY, %PROVIDES );

sub import {
    my $class  = shift;
    my $target = caller;

    # everybody gets 'with' and 'DOES'
    *{ _getglob "${target}::with" } = sub {
        $class->apply_roles_to_package( $target, @_ );
    };
    # everybody gets 'with' and 'DOES'
    *{ _getglob "${target}::DOES" } = sub {
        my ( $proto, $role ) = @_;
        my $class_or_role = ref $proto || $proto;
        return 1 if $class_or_role eq $role;
        return exists $HAS_ROLES{$class_or_role}{$role} ? 1 : 0;
    };
    if ( 1 == @_ && 'with' eq $_[0] ) {

        # this is a class which is consuming roles
        return;
    }
    elsif ( 2 == @_ && 'allow' eq $_[0] ) {

        # this is a role which allows methods from a foreign class
        my $foreign_class = $_[1];
        push @{ $ALLOWED_BY{$foreign_class} } => $target;
        $class->_declare_role($target);
    }
    elsif (@_) {
        my $args = join ', ' => @_;    # more explicit than $"
        Carp::confess(
            "Multiple or unknown argument(s) in import list: ($args)");
    }
    else {
        $class->_declare_role($target);
    }
}

sub _declare_role {
    my ($class, $target) = @_;
    $IS_ROLE{$target} = 1;
    *{ _getglob "${target}::requires" } = sub {
        $class->add_to_requirements( $target, @_ );
    };
}

sub add_to_requirements {
    my ( $class, $role, @methods ) = @_;

    $REQUIRED_BY{$role} ||= [];
    push @{ $REQUIRED_BY{$role} } => @methods;
    my %seen;
    @{ $REQUIRED_BY{$role} } =
      grep { not $seen{$_}++ } @{ $REQUIRED_BY{$role} };
}

sub get_required_by {
    my ( $class, $role ) = @_;
    return unless my $requirements = $REQUIRED_BY{$role};
    return @$requirements;
}

sub requires_method {
    my ( $class, $role, $method ) = @_;
    return unless $IS_ROLE{$role};
    my %requires = map { $_ => 1 } $class->get_required_by($role);
    return $requires{$method};
}

sub _roles {
    my ( $class, $target ) = @_;
    return unless $HAS_ROLES{$target};
    my @roles;
    my %seen;
    foreach my $role ( keys %{ $HAS_ROLES{$target} } ) {
        my $modifiers = $HAS_ROLES{$target}{$role};
        my $role_name = $class->_get_role_name($role,$modifiers);
        unless ( $seen{$role_name} ) {
            push @roles => $role_name, $class->_roles($role);
        }
    }
    return @roles;
}

sub apply_roles_to_package {
    my ( $class, $target, @roles ) = @_;

    if ( $HAS_ROLES{$target} ) {
        Carp::confess("with() may not be called more than once for $target");
    }

    my ( %provided_by, %requires );

    my %is_applied;

    # these are roles which a class does not use directly, but are contained in
    # the roles the class consumes.
    my %contained_roles;

    while ( my $role = shift @roles ) {

        # will need to verify that they're actually a role!

        my $role_modifiers = shift @roles if ref $roles[0];
        $role_modifiers ||= {};
        my $role_name = $class->_get_role_name( $role, $role_modifiers );
        $is_applied{$role_name} = 1;
        $class->_load_role( $role, $role_modifiers->{'-version'} );

        # XXX this is awful. Don't tell anyone I wrote this
        my $role_methods = $class->_add_role_methods_to_target(
            $role,
            $target,
            $role_modifiers
        );

        # DOES() in some cases
        if ( my $roles = $HAS_ROLES{$role} ) {
            foreach my $role ( keys %$roles ) {
                $HAS_ROLES{$target}{$role} = $roles->{$role};
            }
        }

        foreach my $method ( $class->get_required_by($role) ) {
            push @{ $requires{$method} } => $role;
        }

        # roles consuming roles should have the same requirements.
        if ( $IS_ROLE{$target} ) {
            $class->add_to_requirements( $target,
                $class->get_required_by($role) );
        }

        while ( my ( $method, $data ) = each %$role_methods ) {
            $PROVIDES{$role_name}{$method} ||= $data;
        }

        # any extra roles contained in applied roles must be added
        # (helps with conflict resolution)
        $contained_roles{$role_name} = 1;
        foreach my $contained_role ( $class->_roles($role) ) {
            next if $is_applied{$contained_role};
            $contained_roles{$contained_role} = 1;
            $is_applied{$contained_role}      = 1;
        }
    }
    foreach my $contained_role (keys %contained_roles) {
        my ( $role, $modifiers ) = split /-/ => $contained_role, 2;
        foreach my $method ( $class->get_required_by($role) ) {
            push @{ $requires{$method} } => $role;
        }
        # a role is not a name. A role is a role plus its alias/exclusion. We
        # now store those in $HAS_ROLE so pull from them
        if ( my $methods = $PROVIDES{$contained_role} ) {
            foreach my $method (keys %$methods) {
                push @{ $provided_by{$method} } => $methods->{$method};
            }
        }
    }

    $class->_check_conflicts( $target, \%provided_by );
    $class->_check_requirements( $target, \%requires );
}

sub _uniq (@) {
    my %seen = ();
    grep { not $seen{$_}++ } @_;
}

sub _check_conflicts {
    my ( $class, $target, $provided_by ) = @_;
    my @errors;
    foreach my $method (keys %$provided_by) {
        my $sources = $provided_by->{$method};
        next if 1 == @$sources;

        my %seen;
        # what we're doing here is checking to see if code references point to
        # the same reference. If they do, they can't possibly be in conflict
        # because they're the same method. This seems strange, but it does
        # follow the original spec.
        my @sources = do {
            no warnings 'uninitialized';
            map    { $_->{source} }
              grep { !$seen{ $_->{code} }++ } @$sources;
        };

        # more than one role provides the method and it's not overridden by
        # the consuming class having that method
        if ( @sources > 1 && $target ne _sub_package( $target->can($method) ) )
        {
            my $sources = join "' and '" => sort @sources;
            push @errors =>
"Due to a method name conflict in roles '$sources', the method '$method' must be implemented or excluded by '$target'";
        }
    }
    if ( my $errors = join "\n" => @errors ) {
        Carp::confess($errors);
    }
}

sub _check_requirements {
    my ( $class, $target, $requires ) = @_;

    # we return if the target is a role because requirements can be deferred
    # until final composition
    return if $IS_ROLE{$target};
    my @errors;
    foreach my $method ( keys %$requires ) {
        unless ( $target->can($method) ) {
            my $roles = join '|' => _uniq sort @{ $requires->{$method} };
            push @errors =>
"'$roles' requires the method '$method' to be implemented by '$target'";
        }
    }
    if (@errors) {
        Carp::confess( join "\n" => @errors );
    }
}

sub _get_role_name {
    my ( $class, $role, $modifiers ) = @_;
    local $Data::Dumper::Indent   = 0;
    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Sortkeys = 1;
    return "$role-" . Data::Dumper::Dumper($modifiers);
}

sub _add_role_methods_to_target {
    my ( $class, $role, $target, $role_modifiers) = @_;

    my $copied_modifiers = Storable::dclone($role_modifiers);
    my $role_name = $class->_get_role_name( $role, $copied_modifiers );

    my $target_methods    = $class->_get_methods($target);
    my $is_loaded         = $PROVIDES{$role_name};
    my $code_for          = $is_loaded || $class->_get_methods($role);
    my %original_code_for = %$code_for;

    delete $role_modifiers->{'-version'};
    my ( $is_excluded, $aliases ) =
      $class->_get_excludes_and_aliases( $target, $role, $role_modifiers );

    my $stash = do { no strict 'refs'; \%{"${target}::"} };
    while ( my ( $old_method, $new_method ) = each %$aliases ) {
        if ( !$is_loaded ) {
            if ( exists $code_for->{$new_method} && !$is_excluded->{$new_method} ) {
                Carp::confess(
    "Cannot alias '$old_method' to existing method '$new_method' in $role"
                );
            }
            else {
                $code_for->{$new_method} = $original_code_for{$old_method};
            }
        }

        # We do this because $target->can($new_method) wouldn't be appropriate
        # since it's OK for a role method to -alias over an inherited one. You
        # can -alias directly on top of an existing method, though.
        if ( exists $stash->{$new_method} ) {
            Carp::confess("Cannot alias '$old_method' to '$new_method' as a method of that name already exists in $target");
        }
    }

    my %was_aliased = reverse %$aliases;
    foreach my $method ( keys %$code_for ) {
        if ( $is_excluded->{$method} ) {
            unless ($was_aliased{$method}) {
                delete $code_for->{$method};
                $class->add_to_requirements( $target, $method );
                next;
            }
        }

        if ( exists $target_methods->{$method} ) {
            if ( $ENV{PERL_ROLE_OVERRIDE_DIE} ) {
                Carp::confess(
                    "Role '$role' not overriding method '$method' in '$target'"
                );
            }
            if ( $ENV{PERL_ROLE_OVERRIDE_WARN} ) {
                Carp::carp(
                    "Role '$role' not overriding method '$method' in '$target'"
                );
            }
            next;
        }
        # XXX we're going to handle this ourselves
        no strict 'refs';
        no warnings 'redefine';
        *{"${target}::$method"} = $code_for->{$method}{code};
    }
    $HAS_ROLES{$target}{$role} = $copied_modifiers;
    return $code_for;
}

sub _get_excludes_and_aliases {
    my ( $class, $target, $role, $role_modifiers ) = @_;
    # figure out which methods to exclude
    my $excludes = delete $role_modifiers->{'-excludes'} || [];
    my $aliases  = delete $role_modifiers->{'-alias'}    || {};
    my $renames  = delete $role_modifiers->{'-rename'}   || {};

    $excludes = [$excludes] unless ref $excludes;
    my %is_excluded = map { $_ => 1 } @$excludes;

    while ( my ( $old_method, $new_method ) = each %$renames ) {
        $is_excluded{$old_method} = 1;
        $aliases->{$old_method} = $new_method;
    }

    unless ( 'ARRAY' eq ref $excludes ) {
        Carp::confess(
"Argument to '-excludes' in package $target must be a scalar or array reference"
        );
    }

    # rename methods to alias
    unless ( 'HASH' eq ref $aliases ) {
        Carp::confess(
            "Argument to '-alias' in package $target must be a hash reference"
        );
    }

    if ( my $unknown = join ', ' => keys %$role_modifiers ) {
        Carp::confess("Unknown arguments in 'with()' statement for $role");
    }
    return ( \%is_excluded, $aliases );
}

# We can cache this at some point, but for now, the return value is munged
sub _get_methods {
    my ( $class, $target ) = @_;

    my $stash = do { no strict 'refs'; \%{"${target}::"} };

    my %methods;
    foreach my $name ( keys %$stash ) {
        my $item = $stash->{$name};

        next unless my $code = _get_valid_method( $target, $item );

        # this prevents a "modification of read-only value" error.
        my $source = _sub_package($code);
        $methods{$name} = {
            code   => $code,
            source => $source,
        };
    }
    return \%methods;
}

sub _get_valid_method {
    my ( $target, $item ) = @_;
    my $code = ref $item eq 'CODE' ? $item
             : ref \$item eq 'GLOB' ? *$item{CODE}
             : undef;
    return if !defined $code;

    my $source = _sub_package($code) or return;

    # XXX There's a potential bug where some idiot could use Role::Basic to
    # create exportable functions and those get exported into a role. That's
    # far-fetched enough that I'm not worried about it.
    my $is_valid =
      # declared in package, not imported
      $target eq $source
      ||
      # unless we're a role and they're composed from another role
      $IS_ROLE{$target} && $IS_ROLE{$source};

    unless ($is_valid) {
        foreach my $role (@{ $ALLOWED_BY{$source} }) {
            return $code if $target->DOES($role);
        }
    }
    return $is_valid ? $code : ();
}

sub _sub_package {
    my ($code) = @_;
    my $source_package;
    eval {
        my $stash = svref_2object($code)->STASH;
        if ( $stash && $stash->can('NAME') ) {
            $source_package = $stash->NAME;
        }
        else {
            $source_package = '';
        }
    };
    if ( my $error = $@ ) {
        warn "Could not determine calling source_package: $error";
    }
    return $source_package || '';
}

sub _load_role {
    my ( $class, $role, $version ) = @_;

    $version ||= '';
    my $stash = do { no strict 'refs'; \%{"${role}::"} };
    if ( exists $stash->{requires} ) {
        my $package = $role;
        $package =~ s{::}{/}g;
        $package .= ".pm";
        if ( not exists $INC{$package} ) {

            # embedded role, not a separate package
            $INC{"$package"} = "added to inc by $class";
        }
    }
    eval "use $role $version";
    Carp::confess($@) if $@;

    return 1 if $IS_ROLE{$role};

    my $requires = $role->can('requires');
    if ( !$requires || $class ne _sub_package($requires) ) {
        Carp::confess(
            "Only roles defined with $class may be loaded with _load_role.  '$role' is not allowed.");
    }
    $IS_ROLE{$role} = 1;
    return 1;
}

1;

__END__

=head1 NAME

Role::Basic - Just roles. Nothing else.

=head1 VERSION

Version 0.13

=head1 SYNOPSIS

In a role:

    package Does::Serialize::AsYAML;
    use Role::Basic;
    use YAML::Syck;
    requires 'as_hash';

    sub serialize {
        my $self = shift;
        return Dump( $self->as_hash );
    }

    1;

In your class:

    package My::Class;
    use Role::Basic 'with';

    with qw(
        Does::Serialize::AsYAML
    );

    sub as_hash { ... } # because the role requires it

=head1 BETA CODE

This code appears to be stable and currently passes over 300 tests. We've not
(yet) heard of any bugs. There are no functional changes with this release.
It's merely here to let early-adopters know it's safe to give it a spin.

=head1 DESCRIPTION

For an extended discussion, see
L<http://blogs.perl.org/users/ovid/2010/12/rolebasic---when-you-only-want-roles.html>.

Sometimes you want roles. You're not sure about L<Moose>, L<Mouse>, L<Moo> and
what I<was> that damned L<Squirrel> thing anyway?  Then there's
L<Class::Trait>, but it has a funky syntax and the maintainer's deprecated it
in favor of L<Moose::Role> and you really don't care that it handles
overloading, instance application or has a workaround for the SUPER:: bug.
You think a meta-object protocol sounds nifty, but you don't understand it.
Maybe you're not sure you want the syntactic sugar for object declaration.
Maybe you've convinced your colleagues that roles are a good idea but they're
leery of dragging in Moose (your author has had this happen more than once and
heard of others making the same complaint). Sometimes you just want good
old-fashioned roles which let you separate class responsibility from code
reuse.

Whatever your reasons, this is the module you're looking for. It only provides
roles and its major design goals are safety and simplicity.  It also aims to
be a I<subset> of L<Moose::Role> behavior so that when/if you're ready to
upgrade, there will be minimal pain.

=head1 DECLARING A ROLE

To declare the current package as a role, simply add the following line
to the package:

    use Role::Basic;

You can then use C<with> to consume other roles and C<requires> to list the
methods this role requires.  Note that the I<only> methods the role will
provide are methods declared directly in the role or consumed from other
roles. Thus:

    package My::Role;
    use Role::Basic;
    use List::Util 'sum'; # this will not be provided by the role
    with 'Some::Other::Role'; # any methods from this role will be provided

    sub some_method {...} # this will be provided by the role

=head2 Allowed methods in roles

B<Warning>: this functionality is experimental and is subject to change with
no warning.

As mentioned, methods imported into a role are not provided by that role.
However, this can make it very hard when you want to provide simple
getters/setters. To get around this limitation, a role (and only roles, not
classes) may specify one class which they 'allow' to provide additional
methods:

    package My::Role;
    use Role::Basic allow => 'Class::BuildMethods';
    use Class::BuildMethods qw/foo bar/;

    # your role will now provide foo and bar methods
    # rest of role definition here

Please note that if you do this, the code which provides these 'extra' methods
should not provide them in a way which is incompatible with your objects. For
example, many getter/setters generation classes assume you're using a blessed
hashref. Most objects are, but the role should not make such an assumption
about the class which consumes it. In the above example, we use
L<Class::BuildMethods>. It's agnostic about your object implementation, but
it's slow.

See L<http://blogs.perl.org/users/ovid/2011/01/happy-new-yearroles.html> and
search for 'glue' to understand why this is important.

=head1 CONSUMING ROLES

To declare the current package as a class that will use roles, simply add
the following line to the package:

    use Role::Basic 'with';

Just as with L<Moose>, you can have C<-alias>, C<-excludes>, and C<-version>.

Unlike Moose, we also provide a C<-rename> target.  It combines C<-alias> and
C<-excludes>. This code:

    package My::Class;
    use Role::Basic 'with';

    with 'My::Role' => {
        -rename => { foo => 'baz', bar => 'gorch' },
    };

Is identical to this code:

    package My::Class;
    use Role::Basic 'with';

    with 'My::Role' => {
        -alias    => { foo => 'baz', bar => 'gorch' },
        -excludes => [qw/foo bar/],
    };

=head1 EXPORT

Both roles and classes will receive the following methods:

=over 4

=item * C<with>

C<with> accepts a list and may only be called B<once> per role or class. This
is because calling it multiple times removes composition safety.  Just as with
L<Moose::Role>, any class may also have C<-alias> or C<-excludes>.

    package My::Class;
    use Role::Basic 'with';

    with 'Does::Serialize::AsYAML' => { -alias => { serialize => 'as_yaml' } };

And later:

    print $object->as_yaml;

=item * C<DOES>

Returns true if the class or role consumes a role of the given name:

 if ( $class->DOES('Does::Serialize::AsYAML') ) {
    ...
 }

Every role "DOES" itself.

=back

Further, if you're a role, you can also specify methods you require:

=over 4

=item * C<requires>

    package Some::Role;
    use Role::Basic;

    # roles can consume other roles
    with 'Another::Role';

    requires qw(
        first_method
        second_method
        another_method
    );

In the example above, if C<Another::Role> has methods it requires, they will
be added to the requirements of C<Some::Role>.

=back

=head1 DESIGN GOALS AND LIMITATIONS

There are two overriding design goals for C<Role::Basic>: B<simplicity> and
B<safety>.  We make it a bit harder to shoot yourself in the foot and we aim to
keep the code as simple as possible.  Feature requests are welcomed, but will
not be acted upon if they violate either of these two design goals.

Thus, if you need something which C<Role::Basic> does not support, you're
strongly encouraged to consider L<Moose> or L<Mouse>.

The following list details the outcomes of this module's goals.

=over 4

=item * Basic role support

This includes composing into your class, composing roles from other roles,
roles declaring requirements and conflict resolution.

=item * Moose-like syntax

To ease migration difficulties, we use a Moose-like syntax. If you wish to
upgrade to Moose later, or you find that others on your project are already
familiar with Moose, this should make C<Role::Basic> easier to learn.

=item * No handling of SUPER:: bug

A well-known bug in OO Perl is that a SUPER:: method is invoked against the class
its declared in, not against the class of the invocant. Handling this properly
generally involves eval'ing a method directly into the correct package:

    eval <<"END_METHOD";
    package $some_package;

    sub some_method { ... }
    END_METHOD

Or using a different method resolution order (MRO) such as with L<Class::C3>
or friends. We alert you to this limitation but make no attempt to address it.
We consider this a feature because roles should not know or care how they are
composed and probably should not know if a superclass exists.  This helps to
keep this module simple, a primary design goal.

=item * Composition Safety

In addition to the normal conflict resolution, only one C<with> statement is
allowed:

    package Foo;
    use Role::Basic;
    with 'Some::Role';
    with 'Another::Role'; # boom!

This is because when you have more than one C<with> statement, the latter will
ignore conflicts with the first. We could work around this, but this would
be significantly different from the behavior of L<Moose>.

=item * Override Safety

By default, we aim to behave like L<Moose::Role>.  This means that if a class
consuming a role has a method with the same name the role provides, the class
I<silently> wins.  This has been a somewhat contentious issue in the C<Moose>
community and the "silent" behaviour has won. However, there are those who
prefer that they don't have their methods silently ignored. We provide two
optional environment variables to handle this:

    $ENV{PERL_ROLE_OVERRIDE_WARN}
    $ENV{PERL_ROLE_OVERRIDE_DIE}

If you prefer, you can set one of those to true and a class overridding a
role's method will C<warn> or C<die>, as appropriate.  As you might expect,
you can handle this with normal role behaviour or exclusion or aliasing.

    package My::Class;
    use Role::Basic 'with';
    with 'My::Role' => { -excludes => 'conflicting_method' };

From your author's email exchanges with the authors of the original traits
paper (referenced here with permission), the "class silently wins" behaviour
was not intended.  About this, Dr. Andrew P. Black wrote the following:

    Yes, it is really important that a programmer can see clearly when a trait
    method is being overridden -- just as it is important that it is clear
    when an inherited method is being overridden.

    In Smalltalk, where a program is viewed as a graph of objects, the obvious
    solution to this problem is to provide an adequate tool to show the
    programmer interesting properties of the program.  The original traits
    browser did this for Smalltalk; the reason that we implemented it is that
    traits were really NOT a good idea (that is,they were not very usable or
    maintainable) without it.  Since then, the same sort of "virtual
    protocols" have been built into the browser for other properties, like
    "overridden methods".

Note that those are provided as environment variables and not as syntax in the
code itself to help keep the code closer to the L<Moose> syntax.

=item * No instance application

C<Role::Basic> does not support applying roles to object instances.  This may
change in the future.

=item * No method modifiers

These have been especially problematic.  Consider a "before" modifier which
multiplies a value by 2 and another before modifier which divides a value by
3. The order in which those modifiers are applied becomes extremely important.
and role-consumption is no longer entirely declarative, but becomes partially
procedural. This causes enough problems that on Sep 14, 2010 on the
Moose mailing list, Stevan Little wrote:

    I totally agree [with the described application order problems], and if I
    had to do it over again, I would not have allowed method modifiers in
    roles. They ruin the unordered-ness of roles and bring about edge cases
    like this that are not so easily solved.

Thus, C<Role::Basic> does not and I<will not> support method modifiers. If you
need them, consider L<Moose>.

=back

=head1 AUTHOR

Curtis 'Ovid' Poe, C<< <ovid at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-role-basic at rt.cpan.org>,
or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Role-Basic>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Role::Basic

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Role-Basic>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Role-Basic>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Role-Basic>

=item * Search CPAN

L<http://search.cpan.org/dist/Role-Basic/>

=back

=head1 SEE ALSO

=over 4

=item * L<Role::Tiny>

=item * L<Moose::Role>

=item * L<Mouse::Role>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Curtis 'Ovid' Poe.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;    # End of Role::Basic
