use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    DISTNAME     => 'Dir-Split',
    NAME         => 'Dir::Split',
    VERSION_FROM => 'lib/Dir/Split.pm',
    PREREQ_PM    => { File::Basename => 0,
                      File::Copy     => 0,
		      File::Find     => 0,
                      File::Path     => 0,
                      File::Spec     => 0,
                   },
    'dist'       => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    ($] >= 5.005 ?  
       (ABSTRACT_FROM => 'lib/Dir/Split.pm',
        AUTHOR        => 'Steven Schubiger') : ()),
);
