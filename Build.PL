use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name        => 'Role::Basic',
    license            => 'perl',
    dist_author        => q{Curtis 'Ovid' Poe <ovid@cpan.org>},
    dist_version_from  => 'lib/Role/Basic.pm',
    build_requires     => { 'Test::More' => 0, },
    add_to_cleanup     => ['Role-Basic-*'],
    create_makefile_pl => 'traditional',
    meta_merge =>
      { resources => { repository => 'https://github.com/Ovid/Role-Basic' } },
);

$builder->create_build_script();
