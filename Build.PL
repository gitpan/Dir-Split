## Created by make2build 0.16

use Module::Build;

my $b = Module::Build->new
  (
   module_name => 'Dir::Split',
   dist_version_from => 'lib/Dir/Split.pm',
   license => 'unknown',
   requires => {
                 'Carp' => 0,
                 'File::Basename' => 0,
                 'File::Copy' => 0,
                 'File::Find' => 0,
                 'File::Path' => 0,
                 'File::Spec' => 0,
                 'SelfLoader' => 0,
               },
   create_makefile_pl => 'passthrough',
  );
  
$b->create_build_script;
