use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    DISTNAME     => 'Dir-Split',
    NAME         => 'Dir::Split',
    VERSION_FROM => 'lib/Dir/Split.pm', # finds $VERSION
    PREREQ_PM    => { Carp        => 0,
                      File::Copy  => 0,
                      File::Path  => 0,
                      Test::More  => 0,
                   },
    'dist'       => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
       (ABSTRACT   => 'Splits the files of a directory to subdirectories.',
        AUTHOR     => 'Steven Schubiger') : ()),
);
