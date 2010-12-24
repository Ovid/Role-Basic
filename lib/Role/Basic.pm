package Role::Basic;

sub _getglob { \*{ $_[0] } }

use strict;
use warnings FATAL => 'all';

use B qw/svref_2object/;
use Carp ();

our $VERSION = '0.01';

my %IS_ROLE;
my %REQUIRED_BY;
my %REQUIRES;
my %HAS_ROLES;

sub add_to_requirements {
    my ( $class, $role, @methods ) = @_;

    $REQUIRES{$role} = \@methods;
    foreach my $method (@methods) {
        $REQUIRED_BY{$method}{$role} = 1;
    }
}

sub apply_roles_to_package {
    my ( $class, $package, @roles ) = @_;
    if ( $HAS_ROLES{$package} ) {
        Carp::confess("with() may not be called more than once for $package");
    }
    while ( my $role = shift @roles ) {
        # will need to verify that they're actually a role!
        $class->_load_role($role);
        $class->_add_role_methods_to_package($role, $package);
    }
    $HAS_ROLES{$package} = 1;
}

sub _add_role_methods_to_package {
    my ($class, $role, $package) = @_;
    my $code_for = $class->_get_methods($role);

    foreach my $method (keys %$code_for) {
        no strict 'refs';
        *{"${package}::$method"} = $code_for->{$method};
    }
}

sub _get_methods {
    my ( $class, $target ) = @_;

    my $stash = do { no strict 'refs'; \%{"${target}::"} };

    my %methods =
      map { local $_ = $_; my $code = *$_{CODE}; s/^\*$target\:://; $_ => $code }
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
    if (my $error = $@) {
        warn "Could not determine calling package: $error";
    }
    return $package;
}

sub import {
    my $class = shift;
    my $target = caller;

    if ( 1 == @_ && 'with' eq $_[0] ) {
        *{ _getglob "${target}::with" } = sub {
            $class->apply_roles_to_package( $target, @_ );
        };
        return;
    }
    elsif (@_) {
        my $args = join ', ' => @_;    # more explicit than $"
        Carp::confess("Multiple or unknown argument(s) in import list: ($args)");
    }

    # this is a role
    *{ _getglob "${target}::requires" } = sub {
        $class->add_to_requirements($target, @_);
    };
}

sub END {
    use Data::Dumper::Simple;
    $Data::Dumper::Indent   = 1;
    $Data::Dumper::Sortkeys = 1;
    print STDERR Dumper( %IS_ROLE, %REQUIRED_BY, %REQUIRES, %HAS_ROLES );
}

sub _load_role {
    my ( $class, $role ) = @_;
    return 1 if $IS_ROLE{$role};
    ( my $filename = $role ) =~ s/::/\//g;
    require "${filename}.pm";
    no strict 'refs';
    my $requires = $role->can('requires');

    if ( !$requires || $class ne _sub_package($requires) ) {
        Carp::confess(
            "Only roles defined with $class may be loaded with _load_role");
    }
    # die if not role? XXX
    $IS_ROLE{$role} = 1;
    return 1;
}

1;
__END__
our %INFO;
our %APPLIED_TO;
our %COMPOSED;




sub import {
    my $class  = $_[0];
    my $target = caller;
    if ( 'with' eq ( $_[1] || '' ) ) {
        return if $INFO{$target};    # already exported into this package
        *{ _getglob "${target}::with" } = sub {
            die "Only one role supported at a time by with" if @_ > 1;
            $class->apply_role_to_package( $target, $_[0] );
        };
        return;
    }
    strictures->import;
    my $stash = do { no strict 'refs'; \%{"${target}::"} };

    *{ _getglob "${target}::requires" } = sub {
        push @{ $INFO{$target}{requires} ||= [] }, @_;
    };
    # grab all *non-constant* (ref eq 'SCALAR') subs present
    # in the symbol table and store their refaddrs (no need to forcibly
    # inflate constant subs into real subs) - also add '' to here (this
    # is used later)
    @{ $INFO{$target}{not_methods} = {} }{ '',
        map { *$_{CODE} || () } grep !( ref eq 'SCALAR' ), values %$stash } =
      ();

    # a role does itself
    $APPLIED_TO{$target} = { $target => undef };
}

sub apply_role_to_package {
    my ( $me, $to, $role ) = @_;

    _load_module($role);

    Carp::confess("Role::Basic will only apply roles to classes") if ref($to);
    Carp::confess("${role} is not a Role::Basic")
      unless my $info = $INFO{$role};

    $me->_check_requires( $to, $role, @{ $info->{requires} || [] } );
    $me->_install_methods( $to, $role );

    # only add does() method to classes and only if they don't have one
    if ( not $INFO{$to} and not $to->can('does') ) {
        *{ _getglob "${to}::does" } = \&does_role;
    }

    # copy our role list into the target's
    @{ $APPLIED_TO{$to} ||= {} }{ keys %{ $APPLIED_TO{$role} } } = ();
}

sub _check_requires {
    my ( $me, $to, $name, @requires ) = @_;
    if ( my @requires_fail = grep !$to->can($_), @requires ) {

        # role -> role, add to requires, role -> class, error out
        if ( my $to_info = $INFO{$to} ) {
            push @{ $to_info->{requires} ||= [] }, @requires_fail;
        }
        else {
            die "Can't apply ${name} to ${to} - missing "
              . join( ', ', @requires_fail );
        }
    }
}

sub _install_methods {
    my ( $me, $to, $role ) = @_;

    my $info = $INFO{$role};

    my $methods = $me->_concrete_methods_of($role);

    # grab target symbol table
    my $stash = do { no strict 'refs'; \%{"${to}::"} };

    # determine already extant methods of target
    my %has_methods;
    @has_methods{
        grep +(
            ( ref( $stash->{$_} ) eq 'SCALAR' ) || ( *{ $stash->{$_} }{CODE} )
        ),
        keys %$stash
      }
      = ();

    foreach my $i ( grep !exists $has_methods{$_}, keys %$methods ) {
        no warnings 'once';
        *{ _getglob "${to}::${i}" } = $methods->{$i};
    }
}

sub _concrete_methods_of {
    my ( $me, $role ) = @_;
    my $info = $INFO{$role};
    $info->{methods} ||= do {

        # grab role symbol table
        my $stash = do { no strict 'refs'; \%{"${role}::"} };
        my $not_methods = $info->{not_methods};
        +{

            # grab all code entries that aren't in the not_methods list
            map {
                my $code = *{ $stash->{$_} }{CODE};

                # rely on the '' key we added in import for "no code here"
                exists $not_methods->{ $code || '' } ? () : ( $_ => $code )
              } grep !( ref( $stash->{$_} ) eq 'SCALAR' ),
            keys %$stash
        };
    };
}

1;
__END__

sub apply_roles_to_object {
    my ( $me, $object, @roles ) = @_;
    die "No roles supplied!" unless @roles;
    my $class = ref($object);
    bless( $object, $me->create_class_with_roles( $class, @roles ) );
    $object;
}

sub create_class_with_roles {
    my ( $me, $superclass, @roles ) = @_;

    die "No roles supplied!" unless @roles;

    my $new_name =
      join( '+', $superclass, my $compose_name = join '+', @roles );
    return $new_name if $COMPOSED{class}{$new_name};

    foreach my $role (@roles) {
        _load_module($role);
        die "${role} is not a Role::Basic" unless my $info = $INFO{$role};
    }

    if ( $] >= 5.010 ) {
        require mro;
    }
    else {
        require MRO::Compat;
    }

    my @composable = map $me->_composable_package_for($_), reverse @roles;

    *{ _getglob("${new_name}::ISA") } = [ @composable, $superclass ];

    my @info = map +( $INFO{$_} ? $INFO{$_} : () ), @roles;

    $me->_check_requires(
        $new_name, $compose_name,
        do { my %h; @h{ map @{ $_->{requires} || [] }, @info } = (); keys %h }
    );

    *{ _getglob "${new_name}::does" } = \&does_role
      unless $new_name->can('does');

    @{ $APPLIED_TO{$new_name} ||= {} }{ map keys %{ $APPLIED_TO{$_} },
        @roles } = ();

    $COMPOSED{class}{$new_name} = 1;
    return $new_name;
}

sub _composable_package_for {
    my ( $me, $role ) = @_;
    my $composed_name = 'Role::Basic::_COMPOSABLE::' . $role;
    return $composed_name if $COMPOSED{role}{$composed_name};
    $me->_install_methods( $composed_name, $role );
    my $base_name = $composed_name . '::_BASE';
    *{ _getglob("${composed_name}::ISA") } = [$base_name];
    my @mod_base;

    eval( my $code = join "\n", "package ${base_name};", @mod_base );
    die "Evaling failed: $@\nTrying to eval:\n${code}" if $@;
    $COMPOSED{role}{$composed_name} = 1;
    return $composed_name;
}

sub methods_provided_by {
    my ( $me, $role ) = @_;
    die "${role} is not a Role::Basic" unless my $info = $INFO{$role};
    ( keys %{ $me->_concrete_methods_of($role) },
        @{ $info->{requires} || [] } );
}

sub does_role {
    my ( $proto, $role ) = @_;
    return exists $APPLIED_TO{ ref($proto) || $proto }{$role};
}

1;

__END__

=head1 NAME

Role::Basic - Minimal role support with a Moose-like syntax

=head1 VERSION

Version 0.01

=cut


=head1 SYNOPSIS


    use Role::Basic;

    my $foo = Role::Basic->new();
    ...

=head1 EXPORT

=head1 SUBROUTINES/METHODS

=cut

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

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Curtis 'Ovid' Poe.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;    # End of Role::Basic
