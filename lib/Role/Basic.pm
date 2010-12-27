package Role::Basic;

sub _getglob { \*{ $_[0] } }

use strict;
use warnings FATAL => 'all';

use B qw/svref_2object/;
use Carp ();

our $VERSION = '0.01';

my %IS_ROLE;
my %REQUIRED_BY;
my %HAS_ROLES;

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
        my $class = ref $proto || $proto;
        return $HAS_ROLES{$class}{$role};
    };
    if ( 1 == @_ && 'with' eq $_[0] ) {

        # this is a class which is consuming roles
        return;
    }
    elsif (@_) {
        my $args = join ', ' => @_;    # more explicit than $"
        Carp::confess(
            "Multiple or unknown argument(s) in import list: ($args)");
    }
    else {
        $IS_ROLE{$target} = 1;
        *{ _getglob "${target}::requires" } = sub {
            $class->add_to_requirements( $target, @_ );
        };
    }
}

sub add_to_requirements {
    my ( $class, $role, @methods ) = @_;

    $REQUIRED_BY{$role} ||= [];
    push @{ $REQUIRED_BY{$role} } => @methods;
    my %seen;
    @{ $REQUIRED_BY{$role} } =
      grep { not $seen{$_}++ } @{ $REQUIRED_BY{$role} };
}

sub apply_roles_to_package {
    my ( $class, $target, @roles ) = @_;
    if ( $HAS_ROLES{$target} ) {
        Carp::confess("with() may not be called more than once for $target");
    }

    my %provided_by;
    my %requires;
    my $target_methods = $class->_get_methods($target);
    while ( my $role = shift @roles ) {

        # will need to verify that they're actually a role!

        my $conflict_handlers = shift @roles if ref $roles[0];
        $class->_load_role($role);

        # XXX this is awful. Don't tell anyone I wrote this
        my $role_methods = $class->_add_role_methods_to_target( 
            $role,
            $target,
            $target_methods,
            $conflict_handlers
        );
        $HAS_ROLES{$target}{$role} = 1;
        if ( my $roles = $HAS_ROLES{$role}) {
            foreach my $role (keys %$roles) {
                $HAS_ROLES{$target}{$role} = 1;
            }
        }

        foreach my $method ( @{ $REQUIRED_BY{$role} } ) {
            push @{ $requires{$method} } => $role;
        }

        # roles consuming roles should have the same requirements.
        if ( $IS_ROLE{$target} ) {
            $class->add_to_requirements( $target, @{ $REQUIRED_BY{$role} } );
        }
        foreach my $method (@$role_methods) {
            push @{ $provided_by{$method} } => $role;
        }
    }

    $class->_check_conflicts( $target, \%provided_by );
    $class->_check_requirements( $target, \%requires );
}

sub _check_conflicts {
    my ( $class, $target, $provided_by ) = @_;
    my @errors;
    while ( my ( $method, $roles ) = each %$provided_by ) {
        if ( @$roles > 1 ) {
            my $roles = join " and " => @$roles;
            push @errors =>
"Due to method name conflicts in $roles, the method '$method' must be included or excluded in $target";
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
            my $roles = join '|' => @{ $requires->{$method} };
            push @errors =>
"'$roles' requires the method '$method' to be implemented by '$target'";
        }
    }
    if (@errors) {
        Carp::confess( join "\n" => @errors );
    }
}

sub _add_role_methods_to_target {
    my ( $class, $role, $target, $target_methods, $conflict_handlers ) = @_;
    my $code_for = $class->_get_methods($role);

    # figure out which methods to exclude
    my $excludes = delete $conflict_handlers->{'-excludes'} || [];
    $excludes = [$excludes] unless ref $excludes;
    unless ( 'ARRAY' eq ref $excludes ) {
        Carp::confess(
"Argument to '-excludes' in package $target must be a scalar or array reference"
        );
    }
    my %is_excluded = map { $_ => 1 } @$excludes;

    # rename methods to alias
    my $aliases = delete $conflict_handlers->{'-aliases'};
    $aliases ||= {};
    unless ( 'HASH' eq ref $aliases ) {
        Carp::confess(
            "Argument to '-aliases' in package $target must be a hash reference"
        );
    }
    while ( my ( $old_method, $new_method ) = each %$aliases ) {
        if ( exists $code_for->{$new_method} ) {
            Carp::confess(
"Cannot alias '$old_method' to existing method '$new_method' in $role"
            );
        }
        else {
            $code_for->{$new_method} = delete $code_for->{$old_method};
        }
    }
    if ( my $unknown = join ', ' => keys %$conflict_handlers ) {
        Carp::confess("Unknown arguments in 'with()' statement for $role");
    }

    # XXX Apply roles to roles!

    foreach my $method ( keys %$code_for ) {
        if ( $is_excluded{$method} ) {
            delete $code_for->{$method};
            next;
        }
        no strict 'refs';

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
        no warnings 'redefine';
        *{"${target}::$method"} = $code_for->{$method};
    }
    return [ keys %$code_for ];
}

sub _get_methods {
    my ( $class, $target ) = @_;

    my $stash = do { no strict 'refs'; \%{"${target}::"} };

    my %methods =
      map {
        local $_ = $_;
        my $code = *$_{CODE};
        s/^\*$target\:://;
        $_ => $code
      }
      grep {
        !( ref eq 'SCALAR' )    # not a scalar
          && *$_{CODE}          # actually have code
          && _is_valid_method( $target, *$_{CODE} )
      } values %$stash;
    return \%methods;
}

sub _is_valid_method {
    my ( $target, $code ) = @_;

    my $source = _sub_package($code);

    # XXX There's a potential bug where some idiot could use Role::Basic to
    # create exportable functions and those get exported into a role. That's
    # far-fetched enough that I'm not worried about it.
    return

      # no imported methods
      $target eq $source
      ||

      # unless we're a role and they're composed from another role
      $IS_ROLE{$target} && $IS_ROLE{$source};
}

sub _sub_package {
    my $package;
    eval {
        my $stash = svref_2object(shift)->STASH;
        if ( $stash && $stash->can('NAME') ) {
            $package = $stash->NAME;
        }
        else {
            $package = '';
        }
    };
    if ( my $error = $@ ) {
        warn "Could not determine calling package: $error";
    }
    return $package;
}

#sub END {
#    use Data::Dumper;
#    $Data::Dumper::Indent   = 1;
#    $Data::Dumper::Sortkeys = 1;
#    print STDERR Data::Dumper->Dump(
#        [ \%IS_ROLE, \%REQUIRED_BY, \%HAS_ROLES],
#        [qw/*IS_ROLE *REQUIRED_BY *HAS_ROLES/],
#    );
#}

sub _load_role {
    my ( $class, $role ) = @_;
    return 1 if $IS_ROLE{$role};
    unless ( $role->can('can') ) {
        ( my $filename = $role ) =~ s/::/\//g;
        require "${filename}.pm";
        no strict 'refs';
    }
    my $requires = $role->can('requires');

    if ( !$requires || $class ne _sub_package($requires) ) {
        Carp::confess(
            "Only roles defined with $class may be loaded with _load_role");
    }

    $IS_ROLE{$role} = 1;
    return 1;
}

1;

__END__

=head1 NAME

Role::Basic - Just roles. Nothing else.

=head1 VERSION

Version 0.01

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

=head1 DESCRIPTION

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

=head1 CONSUMING ROLES

To declare the current package as a class that will use roles, simply add
the following line to the package:

    use Role::Basic 'with';

Just as with L<Moose>, you can have C<-aliases> and list C<-excludes>.

=head1 EXPORT

Both roles and classes will receive the following methods:

=over 4

=item * C<with>

C<with> accepts a list and may only be called B<once> per role or class. This
is because calling it multiple times removes composition safety.  Just as with
L<Moose::Role>, any class may also have C<-aliases> or C<-excludes>.

    package My::Class;
    use Role::Basic 'with';

    with 'Does::Serialize::AsYAML' => { -aliases => { serialize => 'as_yaml' } };

And later:

    print $object->as_yaml;

=item * C<DOES>

Returns true if the class or role consumes a role of the given name:

 if ( $class->DOES('Does::Serialize::AsYAML') ) {
    ...
 }

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

=head1 ACKNOWLEDGEMENTS

Nicked some code from Moo's Role::Tiny.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Curtis 'Ovid' Poe.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;    # End of Role::Basic
