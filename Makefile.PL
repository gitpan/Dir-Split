use ExtUtils::MakeMaker;

WriteMakefile(
    'DISTNAME' => 'Dir-Split',
    'NAME'    => 'Dir::Split',
    'VERSION_FROM' => 'lib/Dir/Split.pm',
    ($] >= 5.005 ?
       (ABSTRACT   => 'Splits the files of a directory to subdirectories.',
        AUTHOR     => 'Steven Schubiger <st.schubiger@swissinfo.org>') : ()),
);
