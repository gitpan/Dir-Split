#
# $Id: Split.pm,v 0.52 2004/01/10 19:31:45 sts Exp $

package Dir::Split;

our $VERSION = '0.52';

use 5.6.1;
use strict 'vars';
use warnings;

use File::Basename;
use File::Copy 'cp';
use File::Path;
use File::Spec;
use SelfLoader;

our (# external data
        @exists,
        %failure,
        %track,

        $traverse,
        $traverse_depth,
        $traverse_unlink,
        $traverse_rmdir,

     # return
        $Ret_status,

     # data
        @Dirs,
        @Files,
        %F_names_case,
        %F_names_char,
        $Path,
        $Suffix,
);

sub ACTION { 1 }
sub NO_ACTION { 0 }
sub EXISTS { -1 }
sub FAILURE { -2 }

sub croak {
    require Carp;
    &Carp::croak;
}

=head1 NAME

Dir::Split - split files of a directory to subdirectories.

=head1 SYNOPSIS

 use Dir::Split;

 %options = (   mode    =>    'num',

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


 $dir = Dir::Split->new (\%options);

 $return = $dir->split();

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

=head1 CONSTRUCTOR

=head2 new

Creates an object. The key / value pairs may be supplied as
hash reference or directly dumped to the constructor.

 $dir = Dir::Split->new (\%options);

 or

 $dir = Dir::Split->new (
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

=cut

sub new {
    my $pkg = shift;

    my $class = ref ($pkg) || $pkg;

    if (ref $_[0]) { return bless _tie_var($_[0]), $class }
    else { return bless _tie_var(@_), $class }
}

#
# _tie_var (\%hash | %hash)
#
# ``Ties" class data as in %assign.
#

sub _tie_var {
    my (%assign, %assigned);

    %assign = (  mode    =>    'mode',

                 source  =>    'source',
                 target  =>    'target',

                 options => {  verbose     =>      'verbose',
                               override    =>     'override',
                 },
                 sub_dir => {  identifier  =>        'ident',
                               file_limit  =>      'f_limit',
                               file_sort   =>       'f_sort',
                 },
                 suffix  => {  separator   =>          'sep',
                               continue    =>   'num_contin',
                               length      =>       'length',
                               case        =>         'case',
                 },
    );

    # hash ref
    if (ref $_[0]) {
        my $opt = $_[0];
        foreach my $key (keys %$opt) {
            if (ref $$opt{$key} eq 'HASH') {
                foreach (keys %{$$opt{$key}}) {
                    $assigned{$assign{$key}{$_}} = $$opt{$key}{$_};
                }
            }
            else { $assigned{$assign{$key}} = $$opt{$key} }
        }
    }
    # hash
    else {
        my %opt = @_;
        foreach my $key (keys %opt) {
            if (ref $opt{$key} eq 'HASH') {
                foreach (keys %{$opt{$key}}) {
                    $assigned{$assign{$key}{$_}} = $opt{$key}{$_};
                }
            }
            else { $assigned{$assign{$key}} = $opt{$key} }
        }
    }

    return \%assigned;
};

=head1 METHODS

=head2 split

Split files to subdirectories.

 $return = $dir->split();

It is of tremendous importance to notice that checking the return code is a B<must>.
Leaving the return code untouched will not allow appropriate gathering of harmless
debug data (such as existing files) and system operations that failed. C<Dir::Split>
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

I<(see OPTIONS / debug / existing)>

=item (-2)

Failure.

I<(see OPTIONS / debug / failures)>

=back

=cut

sub split {
    my $o = $_[0];

    $o->_sanity_input();
    $o->_gather_files();

    # files found, split.
    if (@Files) {
        $Ret_status = ACTION;

        # engine
        $o->_sort_files() if $o->{'mode'} eq 'num';
        $o->_suffix();
        $o->_move();
        $o->_traversed_rm_dir() if $traverse;

        $Ret_status = FAILURE if %failure;
    }
    # no files? exit.
    else { $Ret_status = NO_ACTION }

    _clean_up();

    return $Ret_status;
}

#
# _sanity_input()
#
# Ensures that interface input passes sanity.
#

sub _sanity_input {
    my $o = $_[0];

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
    {   no warnings;

        # generic opts
        unless ($o->{'mode'} eq 'num' || $o->{'mode'} eq 'char') {
            $err_input = $err_msg{'mode'}; last;
        }
        unless ($o->{'source'}) {
            $err_input = $err_msg{'source'}; last;
        }
        unless ($o->{'target'}) {
            $err_input = $err_msg{'target'}; last;
        }
        unless ($o->{'verbose'} =~ /^0|1$/) {
            $err_input = $err_msg{'verbose'}; last;
        }
        unless ($o->{'override'} =~ /^0|1$/) {
            $err_input = $err_msg{'override'}; last;
        }
        unless ($o->{'ident'} =~ /\w/) {
            $err_input = $err_msg{'ident'}; last;
        }
        unless ($o->{'sep'}) {
            $err_input = $err_msg{'sep'}; last;
        }
        unless ($o->{'length'} > 0) {
            $err_input = $err_msg{'length'}; last;
        }
        # numeric opts
        if ($o->{'mode'} eq 'num') {
            unless ($o->{'f_limit'} > 0) {
                $err_input = $err_msg{'f_limit'}; last;
            }
            unless ($o->{'f_sort'} eq '+' || $o->{'f_sort'} eq '-') {
                $err_input = $err_msg{'f_sort'}; last;
            }
            unless ($o->{'num_contin'} =~ /^0|1$/) {
                $err_input = $err_msg{'num_contin'}; last;
            }
        }
        # characteristic opts
        elsif ($o->{'mode'} eq 'char') {
            unless ($o->{'case'} eq 'lower' || $o->{'case'} eq 'upper') {
                $err_input = $err_msg{'case'}; last;
            }
        }
    }
    croak $err_input if $err_input;
}

#
# _gather_files()
#
# Gathers files.
#

sub _gather_files {
    my $o = $_[0];

    if ($traverse) {
        $o->_traverse(\@Dirs, \@Files);
    }
    else {
        $o->_dir_read($o->{'source'}, \@Files);
        @Files = grep !-d File::Spec->catfile($o->{'source'}, $_), @Files;
    }

    $track{'source'}{'files'} = @Files;
}

#
# _sort_files()
#
# Sorts files.
#

sub _sort_files {
    my $o = $_[0];

    if ($o->{'f_sort'} eq '+' || $o->{'f_sort'} eq '-') {
        # preserve case-sensitive filenames.
        foreach (@Files) {
           $F_names_case{lc($_)} = $_;
        }
        @Files = map lc, @Files;

        if ($o->{'f_sort'} eq '+') { @Files = sort @Files }
        else { @Files = reverse @Files }
    }
}

#
# _suffix()
#
# Sub handler for suffixes.
#

sub _suffix {
    my $o = $_[0];

    if ($o->{'mode'} eq 'num') {
        $o->_suffix_num_contin() if $o->{'num_contin'};
        $o->_suffix_num_sum_up();
    } else {
        $o->_suffix_char();
    }
}

#
# _suffix_num_contin()
#
# Evaluates the highest existing subdir suffix number.
#

sub _suffix_num_contin {
    my $o = $_[0];

    my @dirs;
    $o->_dir_read($o->{'target'}, \@dirs);
    @dirs = grep -d File::Spec->catfile($o->{'target'}, $_), @dirs;

    # surpress warnings
    $Suffix = 0;
    my $sep = quotemeta $o->{'sep'};
    foreach (@dirs) {
        # extract exist. identifier
	my $suff_cmp;
        ($_, $suff_cmp) = /(.+?)$sep(.*)/;
        # increase suffix to highest number
        if ($o->{'ident'} eq $_ && $suff_cmp =~ /[0-9]/o) {
            $Suffix = $suff_cmp if $suff_cmp > $Suffix;
        }
    }
}

#
# _suffix_num_sum_up()
#
# Sums the numeric suffix with zeros up if required.
#

sub _suffix_num_sum_up {
    my $o = $_[0];

    $Suffix++;
    if (length $Suffix < $o->{'length'}) {
        my $format = "%0.$o->{'length'}".'d';
        $Suffix = sprintf $format, $Suffix;
    }
}

#
# _suffix_char()
#
# Evaluates filenames and stores them
# in a hash associated with the leading
# characters of their filenames.
#

sub _suffix_char {
    my $o = $_[0];

    foreach my $file (@Files) {
        if ($traverse) { $_ = basename($file) }
        else { $_ = $file }
        s/\s//g if /\s/; # whitespaces
        ($_) = /^(.{$o->{'length'}})/;
        if ($_ =~ /\w/) {
            if ($o->{'case'} eq 'lower') { $_ = lc $_ }
            else { $_ = uc $_ }
        }
        push @{$F_names_char{$_}}, $file;
    }
    undef @Files;
}

#
# _move()
#
# Sub handler for moving files.
#

sub _move {
    my $o = $_[0];

    # initalize tracking
    $track{'target'}{'dirs'} = 0;
    $track{'target'}{'files'} = 0;

    my $sub_move = "_move_$o->{'mode'}";
    $o->$sub_move();
}

#
# _move_num()
#
# Moves files to numeric subdirs.
#

sub _move_num {
    my $o = $_[0];

    for (; @Files; $Suffix++) {
       $o->_mkpath($Suffix);

        for (my $i = 0; $i < $o->{'f_limit'}; $i++) {
            last unless my $file = shift @Files;
            $o->_cp_unlink($F_names_case{$file});
        }
    }
}

#
# _move_char()
#
# Moves files to characteristic subdirs.
#

sub _move_char {
    my $o = $_[0];

    foreach (sort keys %F_names_char) {
        $o->_mkpath($_);

        while (my $file = shift @{$F_names_char{$_}}) {
            $o->_cp_unlink($file);
        }
    }
}

#
# _dir_read (\$dir, \@files)
#
# Reads files of a directory.
#

sub _dir_read {
    shift; my ($dir, $files_ref) = @_;

    opendir D, $dir
      or croak qq~Could not open dir $dir for read-access: $!~;
    @$files_ref = readdir D; splice @$files_ref, 0, 2;
    closedir D or croak qq~Could not close dir $dir: $!~;
}

#
# _mkpath ($suffix)
#
# Creates subdirs.
#

sub _mkpath {
    my ($o, $suffix) = @_;

    $Path = File::Spec->catfile($o->{'target'}, "$o->{'ident'}$o->{'sep'}$suffix");

    return if -e $Path;
    mkpath $Path, $o->{'verbose'}
      or croak qq~Dir $Path could not be created: $!~;

    $track{'target'}{'dirs'}++;
}

#
# _cp_unlink ($file)
#
# Copies and unlinks files.
# Upon existing files / failures, debug data.
#

sub _cp_unlink {
    my ($o, $file) = @_;

    my $path_target;
    if ($traverse) {
        $path_target = File::Spec->catfile($Path, basename($file));
    }
    else {
        $path_target = File::Spec->catfile($Path, $file);
        $file = File::Spec->catfile($o->{'source'}, $file);
    }

    if ($o->_exists_and_not_override($path_target)) {
        push @exists, $path_target;
        return;
    }

    unless (cp $file, $path_target) {
        push @{$failure{'copy'}}, $path_target;
        return;
    }
    $track{'target'}{'files'}++;

    if ($traverse) {
        return unless $traverse_unlink;
    }

    unless (unlink $file) {
        push @{$failure{'unlink'}}, $file;
        return;
    }
}

#
# _exists_and_not_override ($path)
#
# Looks out for existing files.
#

sub _exists_and_not_override {
    my ($o, $path) = @_;

    if (-e $path && !$o->{'override'}) {
        $Ret_status = EXISTS;
        return 1;
    }

    return 0;
}

#
# _clean_up()
#
# Undef non-class data.
#

sub _clean_up {
    undef @Dirs;
    undef @Files;
    undef %F_names_case;
    undef %F_names_char;
    undef $Path;
    undef $Suffix;
}

1;

__DATA__

#
# _traverse (\@dirs, \@files)
#
# Traversal machinery.
#

sub _traverse {
    my ($o, $dirs_ref, $files_ref) = @_;

    my ($count, @dirs, $eval, @eval, @files,
        $limit, @stack);
    $count = 0;

    $o->_dir_read($o->{'source'}, \@eval);
    @eval =
      map { File::Spec->catfile($o->{'source'}, $_) }
      @eval;

    TRAVERSE:
    while (@eval) {
        if (-d $eval[0]) {
            $eval = shift @eval;
            push @dirs, $eval;
        }
        elsif (-f $eval[0]) {
            my $file = shift @eval;
            push @files, $file;
            next;
        }
        else { croak 'Traversing failed: unknown type' }

        my @items;
        $o->_dir_read($eval, \@items);

        foreach (@items) {
            my $item = File::Spec->catfile($eval, $_);
            if (-d $item) { push @stack, $item }
            else { push @files, $item }
        }

        unless (@eval) {
            if (++$count == $traverse_depth) {
                last TRAVERSE;
            }
            @eval = @stack;
            undef @stack;
        }
    }

    @$dirs_ref  = @dirs;
    @$files_ref = @files;
}

#
# _traversed_rm_dir()
#
# Removes traversed directories.
#

sub _traversed_rm_dir {
    if ($traverse_rmdir) {
        if (!$traverse_depth
          && $traverse_unlink) {
            foreach (@Dirs) {
                rmtree($_, 1, 1);
            }
        }
    }
}

__END__

=head1 OPTIONS

=head2 type indicators

=over 4

=item (c)

character

=item (i)

integer

=item (s)

string

=back

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

(s) - I<num> for numeric.

=item B<source>

(s) - source directory.

=item B<target>

(s) - target directory.

=item B<options / verbose>

(i) - if enabled, mkpath will output the pathes on creating
subdirectories.

 MODES
   1  enabled
   0  disabled

=item B<options / override>

(i) - overriding of existing files.

 MODES
   1  enabled
   0  disabled

=item B<sub_dir / identifier>

(s) - prefix of each subdirectory created.

=item B<sub_dir / file_limit>

(i) - limit of files per subdirectory.

=item B<sub_dir / file_sort>

(c) - sort order of files.

 MODES
   +  ascending
   -  descending

=item B<suffix / separator>

(s) - suffix separator.

=item B<suffix / continue>

(i) - numbering continuation.

 MODES
   1  enabled
   0  disabled    (will start at 1)

If numbering continuation is enabled, and numeric subdirectories are found
within target directory which match the given identifier and separator,
then the suffix numbering will be continued. Disabling numbering continuation
may cause interfering with existing files.

=item B<suffix / length>

(i) - character length of the suffix.

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

(s) - I<char> for characteristic.

=item B<source>

(s) - source directory.

=item B<target>

(s) - target directory.

=item B<options / verbose>

(i) - if enabled, mkpath will output the pathes on creating
subdirectories.

 MODES
   1  enabled
   0  disabled

=item B<options / override>

(i) - overriding of existing files.

 MODES
   1  enabled
   0  disabled

=item B<sub_dir / identifier>

(s) - prefix of each subdirectory created.

=item B<suffix / separator>

(s) - suffix separator.

=item B<suffix / case>

(s) - lower/upper case of the suffix.

 MODES
   lower
   upper

=item B<suffix / length>

(i) - character length of the suffix.

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

Above example: directory consisting 512 files successfully splitted to 128 directories.

=head2 debug

=head3 existing

If C<split()> returns a EXISTS, this implys that the B<override> option is disabled and
files weren't moved due to existing files within the target subdirectories; they will have
their paths appearing in C<@Dir::Split::exists>.

 file    @Dir::Split::exists    # existing files, not attempted to
                                # be overwritten.

=head3 failures

If C<split()> returns a FAILURE, this most often implys that the B<override> option is enabled
and existing files could not be overriden. Files that could not be copied / unlinked,
will have their paths appearing in the according keys in C<%Dir::Split::failure>.

 file    @{$Dir::Split::failure{'copy'}}      # files that couldn't be copied,
                                              # most often on overriding failures.

         @{$Dir::Split::failure{'unlink'}}    # files that could be copied but not unlinked,
                                              # rather seldom.

It is recommended to evaluate those arrays on FAILURE.

A C<@Dir::Split::exists> array may coexist.

=head2 traversing

Traversal processing of files within the source directory may not be activated by passing
an argument to the object constructor, it requires the following variable to be set to true:

 # traversal mode
 $Dir::Split::traverse        = 1;

By default no depth limit e.g. all underlying directories / files will be evaluated.

B<options>

 # traversing depth
 $Dir::Split::traverse_depth  = 3;

The traversal depth equals the directory depth that will be entered.

 # unlink files in source
 $Dir::Split::traverse_unlink = 1;

Unlinks files after they have been moved to their new locations.

 # remove directories in source
 $Dir::Split::traverse_rmdir  = 1;

Removes the directories themselves after the files have been moved. In order to take effect,
this option requires the C<$Dir::Split::traverse_unlink> to be set. Directories will not be
removed if a traversing depth has been set.

It is B<not> recommended to turn on the latter options C<$Dir::Split::traverse_unlink> and
C<$Dir::Split::traverse_rmdir>, unless you're aware of the consequences they imply.

=head1 EXAMPLES

Assuming F</source> contains 5 files:

 +- _12.tmp
 +- abc.tmp
 +- def.tmp
 +- ghi.tmp
 +- jkl.tmp

After splitting the directory tree in F</target> will look as following:

B<numeric splitting>

 +- system-00001
 +-- _12.tmp
 +-- abc.tmp
 +- system-00002
 +-- def.tmp
 +-- ghi.tmp
 +- system-00003
 +-- jkl.tmp

B<characteristic splitting>

 +- system-_
 +-- _12.tmp
 +- system-a
 +-- abc.tmp
 +- system-d
 +-- def.tmp
 +- system-g
 +-- ghi.tmp
 +- system-j
 +-- jkl.tmp

=head1 FAQ

=over 4

=item B<Has the functionality of C<Dir::Split> been tested?>

Yes. I may not have covered all edging cases,
but it should behave I<mostly> sane, if certain options
such as numbering continuation are enabled and others,
like overriding, are disabled.

=item B<Portability?>

Has not yet been extensively tested. C<Dir::Split>
relies mostly upon C<File::> nested modules in spite of
filesystem operations such as copying, unlinking and
selecting an appropriate path separator; thus it should
probably be portable.

=item B<Will you add any additional features?>

Not unless they prove to be of unique usefulness.
C<Dir::Split> is already heavyweight enough and I am rather
careful in terms of new inclusions; proposals towards additions
should be well grounded.

=back

=head1 DEPENDENCIES

C<Perl 5.6.1>; C<File::Basename>, C<File::Copy>, C<File::Path>, C<File::Spec>.

=head1 SEE ALSO

perl(1)

=head1 LICENSE

This program is free software; you may redistribute it and/or modify it under the same terms as Perl itself.

=head1 AUTHOR

Steven Schubiger

=cut
