use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Dir::Split',
    VERSION_FROM => 'lib/Dir/Split.pm',
    PREREQ_PM    => { Exporter       => 0,
                      File::Basename => 0,
                      File::Copy     => 0,
		      File::Find     => 0,
                      File::Path     => 0,
                      File::Spec     => 0, },
    ($] >= 5.005 
      ? (ABSTRACT_FROM => 'lib/Dir/Split.pm') : ()
    ),
);
