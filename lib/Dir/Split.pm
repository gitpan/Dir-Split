# $Id: Split.pm,v 0.64 2004/01/19 09:58:57 sts Exp $

package Dir::Split;

use 5.006;
use base qw(Exporter);
use strict 'vars';
use warnings;

our $VERSION = '0.64';

our @EXPORT_OK = qw(split_dir);

use File::Basename;
use File::Copy 'cp';
use File::Find;
use File::Path;
use File::Spec;
use SelfLoader;

our (# external opts
        $Traverse,
        $Traverse_unlink,
        $Traverse_rmdir,
	
     # external data
        @exists,
        %failure,
        %track,

     # return
        $ret_state,

     # data
        %o,
        @dirs,
        @files,
        %f_names_char,
	$path,
        $suffix,
);

sub ACTION    {  1 }
sub NO_ACTION {  0 }
sub EXISTS    { -1 }
sub FAILURE   { -2 }

sub croak {
    require Carp;
    &Carp::croak;
}

sub split_dir {
    local %o = _tie_var(@_);
    undef @_;

    local ($ret_state, @dirs, @files);

    _sanity_input();
    _gather_files();

    if (@files) {
        $ret_state = ACTION;
	
	local (%f_names_char, $path, $suffix, $_);
        
        _sort_files() if $o{mode} eq 'num';
        _suffix();
        _move();
        _traversed_rmdir() if $Traverse;

        $ret_state = FAILURE if %failure;
    }
    else { $ret_state = NO_ACTION }

    return $ret_state;
}

sub _tie_var {
    my %opt = @_;

    my %assign;
    $assign{mode}       = $opt{mode};
    $assign{source}     = $opt{source};
    $assign{target}     = $opt{target};
    $assign{verbose}    = $opt{options}{verbose};
    $assign{override}   = $opt{options}{override};
    $assign{ident}      = $opt{sub_dir}{identifier};
    $assign{f_limit}    = $opt{sub_dir}{file_limit};
    $assign{f_sort}     = $opt{sub_dir}{file_sort};
    $assign{sep}        = $opt{suffix}{separator};
    $assign{num_contin} = $opt{suffix}{continue};
    $assign{length}     = $opt{suffix}{length};
    $assign{case}       = $opt{suffix}{case};
    
    return %assign;
};

sub _sanity_input {
    my %err_msg = (  mode        =>    'No mode specified.',
                     source      =>    'No source dir specified.',
                     target      =>    'No target dir specified.',
                     verbose     =>    'No verbosity specified.',
                     override    =>    'No override mode specified.',
                     ident       =>    'No subdir identifier specified.',
                     sep         =>    'No suffix separator specified.',
                     length      =>    'No suffix length specified.',
                     f_limit     =>    'No file limit specified.',
                     f_sort      =>    'No file sort mode specified.',
                     num_contin  =>    'No continuation mode specified.',
                     case        =>    'No suffix case mode specified.',
    );

    my $err_input;
    {    
        no warnings;
        # generic opts
        unless ($o{mode} eq 'num' || $o{mode} eq 'char') {
            $err_input = $err_msg{mode}; last;
        }
        unless ($o{source}) {
            $err_input = $err_msg{source}; last;
        }
        unless ($o{target}) {
            $err_input = $err_msg{target}; last;
        }
        unless ($o{verbose} =~ /^(?:0|1)$/) {
            $err_input = $err_msg{verbose}; last;
        }
        unless ($o{override} =~ /^(?:0|1)$/) {
            $err_input = $err_msg{override}; last;
        }
        unless ($o{ident} =~ /\w/) {
            $err_input = $err_msg{ident}; last;
        }
        unless ($o{sep}) {
            $err_input = $err_msg{sep}; last;
        }
        unless ($o{length} > 0) {
            $err_input = $err_msg{length}; last;
        }
        # num opts
        if ($o{mode} eq 'num') {
            unless ($o{f_limit} > 0) {
                $err_input = $err_msg{f_limit}; last;
            }
            unless ($o{f_sort} eq '+' || $o{f_sort} eq '-') {
                $err_input = $err_msg{f_sort}; last;
            }
            unless ($o{num_contin} =~ /^(?:0|1)$/) {
                $err_input = $err_msg{num_contin}; last;
            }
        }
        # char opts
        else {
            unless ($o{case} eq 'lower' || $o{case} eq 'upper') {
                $err_input = $err_msg{case}; last;
            }
        }
    }
    croak $err_input if $err_input;
}

sub _gather_files {
    if ($Traverse) {
        _traverse(\@dirs, \@files);
    }
    else {
        _read_dir(\@files, $o{source});
        @files = grep !-d File::Spec->catfile($o{source}, $_), @files;
    }

    $track{source}{files} = @files;
}

sub _sort_files {
    my $cmp = 
      $Traverse 
        ? $o{f_sort} eq '+'
          ? 'lc(basename($a)) cmp lc(basename($b))'
	  : 'lc(basename($b)) cmp lc(basename($a))'
	: $o{f_sort} eq '+'
	  ? 'lc($a) cmp lc($b)'
	  : 'lc($b) cmp lc($a)';

    @files = sort { eval $cmp } @files;
}

sub _suffix {
    if ($o{mode} eq 'num') {
        _suffix_num_contin() if $o{num_contin};
        _suffix_num_sum_up();
    } 
    else { _suffix_char() }
}

sub _suffix_num_contin {
    my @dirs;
    _read_dir(\@dirs, $o{target});
    @dirs = grep -d File::Spec->catfile($o{target}, $_), @dirs;

    $suffix = 0;
    my $sep = quotemeta $o{sep};
    for (@dirs) {
        # extract exist. identifier
	my $suff_cmp;
        ($_, $suff_cmp) = /(.+?)$sep(.*)/;
        # increase suffix to highest number
        if ($o{ident} eq $_ && $suff_cmp =~ /[0-9]/o) {
            $suffix = $suff_cmp if $suff_cmp > $suffix;
        }
    }
}

sub _suffix_num_sum_up {
    $suffix++;
    if (length $suffix < $o{length}) {
        $suffix = sprintf "%0.$o{length}".'d', $suffix;
    }
}

sub _suffix_char {
    for my $file (@files) {
        $_ = $Traverse ? basename($file) : $file;
        s/\s//g if /\s/; # whitespaces
        ($_) = /^(.{$o{length}})/;
        if ($_ =~ /\w/) {
            $_ = $o{case} eq 'lower' ? lc : uc;
        }
        push @{$f_names_char{$_}}, $file;
    }
    undef @files;
}

sub _move {
    $track{target}{dirs} = 0;
    $track{target}{files} = 0;

    &{"_move_$o{mode}"}();
}

sub _move_num {
    for (; @files; $suffix++) {
       _mkpath(\$suffix);

        for (my $i = 0; $i < $o{f_limit} && @files; $i++) {
            my $file = shift @files;
            _cp_unlink(\$file);
        }
    }
}

sub _move_char {
    for (sort keys %f_names_char) {
        _mkpath(\$_);

        while (my $file = shift @{$f_names_char{$_}}) {
            _cp_unlink(\$file);
        }
    }
}

sub _read_dir {
    my ($items, $dir) = @_;

    local *D;
    opendir D, $dir
      or croak qq~couldn't open dir $dir for read-access: $!~;
    @$items = readdir D; splice @$items, 0, 2;
    closedir D or croak qq~couldn't close dir $dir: $!~;
}

sub _mkpath {
    my $suffix = $_[0];

    $path = File::Spec->catfile($o{target}, "$o{ident}$o{sep}$$suffix");

    return if -e $path;
    mkpath $path, $o{verbose}
      or croak qq~dir $path could not be created: $!~;

    $track{target}{dirs}++;
}

sub _cp_unlink {
    my $file = $_[0];

    my $target_path;
    if ($Traverse) {
        $target_path = File::Spec->catfile($path, basename($$file));
    }
    else {
        $target_path = File::Spec->catfile($path, $$file);
        $$file = File::Spec->catfile($o{source}, $$file);
    }

    if (_exists_and_not_override(\$target_path)) {
        push @exists, $target_path;
        return;
    }

    unless (cp $$file, $target_path) {
        push @{$failure{copy}}, $target_path;
        return;
    }
    $track{target}{files}++;

    if ($Traverse) {
        return unless $Traverse_unlink;
    }

    unless (unlink $$file) {
        push @{$failure{unlink}}, $$file;
        return;
    }
}

sub _exists_and_not_override {
    my $path = $_[0];

    if (-e $$path && !$o{override}) {
        $ret_state = EXISTS;
        return 1;
    }

    return 0;
}

1;
__DATA__

sub _traverse {
    no strict 'vars';
    local ($dirs, $files) = @_;

    my %opts = (  wanted       =>    \&_eval_files,
	          postprocess  =>     \&_eval_dirs,
    );

    finddepth(\%opts, $o{source});
    
    sub _eval_files {
        push @$files, $File::Find::name
	  if -f $File::Find::name;
    }

    sub _eval_dirs {
        push @$dirs, $File::Find::dir 
	  if $File::Find::dir ne $o{source};
    }    
}

sub _traversed_rmdir {
    if ($Traverse_rmdir && $Traverse_unlink) {
        for (@dirs) { 
	    rmtree $_,1,1;
	}
    }
}

__END__

=head1 NAME

Dir::Split - split files of a directory to subdirectories.

=head1 SYNOPSIS

 use Dir::Split qw(split_dir);

 $return = split_dir(
     mode    =>    'num',

     source  =>    '/source',
     target  =>    '/target',

     options => {  verbose      =>        1,
                   override     =>        0,
     },
     sub_dir => {  identifier   =>    'sub',
                   file_limit   =>        2,
                   file_sort    =>      '+',
     },
     suffix  => {  separator    =>      '-',
                   continue     =>        1,
                   length       =>        5,
     },
 ); 

=head1 DESCRIPTION

C<Dir::Split> moves files to either numbered or characteristic subdirectories.

=head2 numeric splitting

Numeric splitting is an attempt to gather files from a source directory and
split them to numbered subdirectories within a target directory. Its purpose is
to automate the archiving of a great amount of files, that are likely to be indexed
by numbers.

=head2 characteristic splitting

Characteristic splitting allows indexing by using leading characters of filenames.
While numeric splitting is being characterised by dividing file amounts, characteristic
splitting tries to keep up the contentual recognition of data.

=cut

=head1 FUNCTIONS

=head2 split_dir

Splits files to subdirectories.

 $return = split_dir(
     mode    =>    'num',

     source  =>    '/source',
     target  =>    '/target',

     options => {  verbose      =>         1,
                   override     =>         0,
     },
     sub_dir => {  identifier   =>     'sub',
                   file_limit   =>         2,
                   file_sort    =>       '+',
     },
     suffix  => {  separator    =>       '-',
                   continue     =>         1,
                   length       =>         5,
     },
 ); 

It is of tremendous importance to notice that checking the return code is a B<must>.
Leaving the return code untouched will not allow appropriate gathering of harmless
debug data (such as existing files) and system operations that failed. C<split_dir()>
does only report verbose output of mkpath to STDOUT. See B<OPTIONS / debug> on how to
become aware of existing files and failed system operations (I<copy> & I<unlink>).

B<RETURN CODES>

=over 4

=item (1)

Files moved successfully.

=item (0)

No action.

=item (-1)

Exists.

(see OPTIONS / debug)

=item (-2)

Failure.

(see OPTIONS / debug)

=back

=cut

=head1 OPTIONS

=head2 numeric

Split files to subdirectories with a numeric suffix.

 %options = (  mode    =>    'num',

               source  =>    '/source',
               target  =>    '/target',

               options => {  verbose     =>         1,
                             override    =>         0,
               },
               sub_dir => {  identifier  =>     'sub',
                             file_limit  =>         2,
                             file_sort   =>       '+',
               },
               suffix  => {  separator   =>       '-',
                             continue    =>         1,
                             length      =>         5,
               },
 );

B<options> (mandatory)

=over 4

=item *

=item B<mode>

I<num> for numeric.

=item B<source>

source directory.

=item B<target>

target directory.

=item B<options / verbose>

If enabled, mkpath will output the pathes on creating
subdirectories.

 MODES
   1  enabled
   0  disabled

=item B<options / override>

overriding of existing files.

 MODES
   1  enabled
   0  disabled

=item B<sub_dir / identifier>

prefix of each subdirectory created.

=item B<sub_dir / file_limit>

limit of files per subdirectory.

=item B<sub_dir / file_sort>

sort order of files.

 MODES
   +  ascending
   -  descending

=item B<suffix / separator>

suffix separator.

=item B<suffix / continue>

numbering continuation.

 MODES
   1  enabled
   0  disabled    (will start at 1)

If numbering continuation is enabled, and numeric subdirectories are found
within target directory which match the given identifier and separator,
then the suffix numbering will be continued. Disabling numbering continuation
may cause interfering with existing files.

=item B<suffix / length>

character length of the suffix.

This option will have no effect if its smaller than the current length
of the highest suffix number.

=back

=head2 characteristic

Split files to subdirectories with a characteristic suffix. Files
are assigned to subdirectories which suffixes equal the leading character (s)
of their filenames.

 %options = (  mode    =>    'char',

               source  =>    '/source',
               target  =>    '/target',

               options => {  verbose     =>         1,
                             override    =>         0,
               },
               sub_dir => {  identifier  =>     'sub',
               },
               suffix  => {  separator   =>       '-',
                             case        =>   'upper',
                             length      =>         1,
               },
 );

B<options> (mandatory)

=over 4

=item *

=item B<mode>

I<char> for characteristic.

=item B<source>

source directory.

=item B<target>

target directory.

=item B<options / verbose>

If enabled, mkpath will output the pathes on creating
subdirectories.

 MODES
   1  enabled
   0  disabled

=item B<options / override>

overriding of existing files.

 MODES
   1  enabled
   0  disabled

=item B<sub_dir / identifier>

prefix of each subdirectory created.

=item B<suffix / separator>

suffix separator.

=item B<suffix / case>

lower/upper case of the suffix.

 MODES
   lower
   upper

=item B<suffix / length>

character length of the suffix.

< 4 is highly recommended (26 (alphabet) ^ 3 == 17'576 suffix possibilites).
C<Dir::Split> will not prevent using suffix lengths greater than 3. Imagine
splitting 1'000 files and using a character length > 20. The file rate per
subdirectory will almost certainly approximate 1/1 - which equals 1'000
subdirectories.

Whitespaces in suffixes will be removed.

=back

=head2 tracking

C<%Dir::Split::track> keeps count of how many files the source and directories / files
the target consists of. It may prove its usefulness, if the amount of files that could
not be transferred due to existing ones has to be counted.
Each time a new splitting is attempted, the track will be reseted.

 %Dir::Split::track = (  source  =>    {  files  =>    512,
                         },
                         target  =>    {  dirs   =>    128,
                                          files  =>    512,
                         },
 );

Above example: directory consisting of 512 files successfully splitted to 128 directories.

=head2 debug

B<existing>

If C<split_dir()> returns a EXISTS, this implys that the B<override> option is disabled and
files weren't moved due to existing files within the target subdirectories; they will have
their paths appearing in C<@Dir::Split::exists>.

 file    @Dir::Split::exists    # existing files, not attempted to
                                # be overwritten.

B<failures>

If C<split_dir()> returns a FAILURE, this most often implys that the B<override> option is enabled
and existing files could not be overriden. Files that could not be copied / unlinked,
will have their paths appearing in the according keys in C<%Dir::Split::failure>.

 file    @{$Dir::Split::failure{copy}}      # files that couldn't be copied,
                                            # most often on overriding failures.

         @{$Dir::Split::failure{unlink}}    # files that could be copied but not unlinked,
                                            # rather seldom.

It is recommended to evaluate those arrays on FAILURE.

A C<@Dir::Split::exists> array may coexist.

=head2 traversing

Traversal processing of files within the source directory may not be activated by passing
an argument to the object constructor, it requires the following variable to be set to true:

 # traversal mode
 $Dir::Split::Traverse = 1;

No depth limit e.g. all underlying directories / files will be evaluated.

B<options>

 # unlink files in source
 $Dir::Split::Traverse_unlink = 1;

Unlinks files after they have been moved to their new locations.

 # remove directories in source
 $Dir::Split::Traverse_rmdir = 1;

Removes the directories after the files have been moved. In order to take effect,
this option requires the C<$Dir::Split::Traverse_unlink> to be set.

It is B<not> recommended to turn on the latter options C<$Dir::Split::Traverse_unlink> and
C<$Dir::Split::Traverse_rmdir>, unless you're aware of the consequences they imply.

=head1 EXAMPLES

Assuming F</source> contains 5 files:

 +- _123
 +- abcd
 +- efgh
 +- ijkl
 +- mnop

After splitting the directory tree in F</target> will look as following:

B<numeric splitting>

 +- system-00001
 +-- _123
 +-- abcd
 +- system-00002
 +-- efgh
 +-- ijkl
 +- system-00003
 +-- mnop

B<characteristic splitting>

 +- system-_
 +-- _123
 +- system-a
 +-- abcd
 +- system-e
 +-- efgh
 +- system-i
 +-- ijkl
 +- system-m
 +-- mnop

=head1 EXPORT

C<split_dir()> is exportable.

=head1 SEE ALSO

L<File::Basename>, L<File::Copy>, L<File::Find>, L<File::Path>, L<File::Spec>.

=cut
