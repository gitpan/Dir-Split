package Dir::Split;

$VERSION = '0.74';
@EXPORT_OK = qw(split_dir);

use strict 'vars';
use base qw(Exporter);
use Carp 'croak';
use File::Basename;
use File::Copy;
use File::Find ();
use File::Path;
use File::Spec;
use SelfLoader;

our ($Traverse,           # external options
     $Traverse_unlink,    
     $Traverse_rmdir,

     @exists,             # external data
     %failure,
     %track,

     %o,                  # Declarations due to 
     @Dirs,               # the behavior of local().
     @Files,
     %Files,
     $Suffix);

sub NO_ACTION () {  0 }
sub ACTION    () {  1 }
sub EXISTS    () { -1 }
sub FAILURE   () { -2 }

sub split_dir {
    local %o = @_; 
    
    local (@Dirs, @Files);

    _sanity_input();
    _gather_files();
    
    my $RetVal = NO_ACTION;

    if (@Files) {
        $RetVal = ACTION;
	
	local (%Files, $Suffix);
        
        _sort_files()         if ($o{mode} eq 'num');
        _suffix();
        _move();
	_traversed_rmdir()    if $Traverse && not (@exists || %failure); 

        $RetVal = EXISTS      if @exists;
        $RetVal = FAILURE     if %failure;
    }
    
    return $RetVal;
}

sub _sanity_input { 
    my %generic = (
        mode        =>       '^(?:num|char)$',
        source      =>              'defined',    
        target      =>              'defined',   
        verbose     =>               '^[01]$',  
        override    =>               '^[01]$',  
        identifier  =>                  '\w+',   
	separator   =>              'defined',  
	length      =>                  '> 0',
    );
	
    my %num = (
        file_limit  =>                  '> 0',   
        file_sort   =>               '^[+-]$',
	continue    =>               '^[01]$',
    );
	
    my %char = (
        case        =>    '^(?:lower|upper)$',
    ); 
    
    _validate_input( \%generic );
	
    $o{mode} eq 'num'
      ? _validate_input( \%num )
      : _validate_input( \%char );
}

sub _validate_input {
    my ($args) = @_;
    
    while (my ($arg, $prove) = each %$args) {
        my $condition = "\$o{$arg}";
	   
	if ($prove ne 'defined' && $prove !~ /\d+$/) {
	    $condition .= " =~ /$prove/";
	}
	my $match = eval "sub { $condition }" 
	  or die "Couldn't compile $condition: $@";
	       
        croak( 'Option ', $arg, ' not defined or invalid' ) 
	  unless (&$match);
    }
}    
    

sub _gather_files {
    if ($Traverse) {
        _traverse( \@Dirs, \@Files );
    }
    else {
        _read_dir( \@Files, $o{source} );
	
	# Leave directories behind as we are in ``flat", non-traversal mode. 
        @Files = grep { !-d File::Spec->catfile( $o{source}, $_ ) } @Files;
    }
    $track{source}{files} = @Files;
}

sub _sort_files {
    my $cmp = 
      $Traverse 
        ? $o{file_sort} eq '+' 
	  ? 'lc basename( $a ) cmp lc basename( $b )'
	  : 'lc basename( $b ) cmp lc basename( $a )'
	: $o{file_sort} eq '+'
	  ? 'lc $a cmp lc $b'
	  : 'lc $b cmp lc $a';
	  
    @Files = sort { eval $cmp } @Files;
}

sub _suffix {
    if ($o{mode} eq 'num') {
        _suffix_num_contin()    if $o{continue};
        _suffix_num_sum_up();
    } 
    else { 
        _suffix_char();
    }
}

sub _suffix_num_contin {
    my @dirs;
    _read_dir( \@dirs, $o{target} );
    
    # Leave files behind as we need to evaluate names of subdirs.
    @dirs = grep { -d File::Spec->catfile( $o{target}, $_ ) } @dirs;

    $Suffix = 0;
      
    # Search for the highest numerical suffix of given identifier.
    for my $dir (@dirs) {
        my ($ident_cmp, $suff_cmp) = $dir =~ /(.+) \Q$o{separator}\E (.*)/ox;    

        if ($o{identifier} eq $ident_cmp && $suff_cmp =~ /[0-9]/o) {
            $Suffix = $suff_cmp if ($suff_cmp > $Suffix);
        }
    }
}

sub _suffix_num_sum_up {
    # In case, no previous suffix has been found,
    # set to 1, otherwise increment.
    $Suffix++;
    
    if (length $Suffix < $o{length}) {
        $Suffix = sprintf( "%0.$o{length}".'d', $Suffix );
    }
}

sub _suffix_char {
    while (my $file = shift @Files) {
        my $suffix = $Traverse 
	  ? basename( $file ) 
	  : $file; 

	$suffix =~ s/\s//g;
        $suffix =~ s/^(.{ $o{length} })/$1/ox;
	
        if ($suffix =~ /\w/) {
            $suffix = $o{case} eq 'lower' 
	      ? lc $suffix : uc $suffix;
        }
        push @{$Files{$suffix}}, $file;
    }
}

sub _move { 
    $track{target}{dirs}  = 0;
    $track{target}{files} = 0;
    
    &{"_move_$o{mode}"}();
}

sub _move_num {
    for (; @Files; $Suffix++) {
        my $target_path = _mkpath( $Suffix );
	
        for (my $copied = 0; $copied < $o{file_limit} && @Files; $copied++) {
	    my $file = shift @Files;
            _copy_unlink( $file, $target_path );
            
        }
    }
}

sub _move_char {
    for my $suffix (sort keys %Files) {
        my $target_path = _mkpath( $suffix );

	while (my $file = shift @{$Files{$suffix}}) {
            _copy_unlink( $file, $target_path );
        }
    }
}

sub _mkpath {
    my ($suffix) = @_;
    
    my $target_path = File::Spec->catfile
      ( $o{target}, "$o{identifier}$o{separator}$suffix" );
    
    return $target_path if -e $target_path;
    
    mkpath( $target_path, $o{verbose} )
      ? $track{target}{dirs}++
      : croak "Dir $target_path couldn't be created: $!";
      
    return $target_path;
}

sub _copy_unlink {
    my ($file, $target_path) = @_;
    my ($source_file, $target_file);
    
    if ($Traverse) {
        $source_file = $file;
        $target_file = File::Spec->catfile( $target_path, basename( $file ) );
    }
    else {
        $source_file = File::Spec->catfile( $o{source}, $file );
        $target_file = File::Spec->catfile( $target_path, $file );
    }
    
    if (_copy( $source_file, $target_file )) {
        $track{target}{files}++;
       _unlink( $source_file );
    }  
}

sub _copy {
    my ($source_file, $target_file) = @_;

    if (_exists_and_not_override( $target_file )) {
        push @exists, $target_file;
	return 0;
    }
    
    if (not (copy $source_file, $target_file)) {
        push @{$failure{copy}}, $target_file;
        return 0;    
    }
    else { return 1 }
}

sub _unlink {
    my ($source_file) = @_;

    if ($Traverse) {
        return unless $Traverse_unlink;
    }            
    unless (unlink $source_file) {
        push @{$failure{unlink}}, $source_file;
    }
}

sub _exists_and_not_override {
    return (-e $_[0] && not $o{override})
      ? 1 : 0;
}

sub _read_dir {
    my ($items, $dir) = @_;
    
    local *DIR;
    
    opendir DIR, $dir 
      or croak "Couldn't open dir $dir: $!";
      
    @$items = readdir DIR; 
    splice( @$items, 0, 2 );
    
    closedir DIR 
      or croak "Couldn't close dir $dir: $!";
}

1;
__DATA__

sub _traverse {
    local ($dirs, $files) = @_;

    my %opts = (  
        wanted       =>    \&_eval_files,
	postprocess  =>    \&_eval_dirs,
    );

    File::Find::finddepth( \%opts, $o{source} );
} 

sub _eval_files {
    push @$files, $File::Find::name
      if -f $File::Find::name;
}

sub _eval_dirs {
    push @$dirs, $File::Find::dir
      if $File::Find::dir ne $o{source};
} 

sub _traversed_rmdir {
    if ($Traverse_rmdir && $Traverse_unlink) {
        for my $dir (@Dirs) {
	    rmtree( $dir, 1, 1 );    
        }
    }
}

__END__

=head1 NAME

Dir::Split - Split files of a directory to subdirectories

=head1 SYNOPSIS

 use Dir::Split qw(split_dir);

 $return = split_dir(
     mode    =>    'num',

     source  =>    '/source',
     target  =>    '/target',

     verbose     =>        1,
     override    =>        0,
     
     identifier  =>    'sub',
     file_limit  =>        2,
     file_sort   =>      '+',
     
     separator   =>      '-',
     continue    =>        1,
     length      =>        5,
 ); 

=head1 DESCRIPTION

Dir::Split moves files to either numbered or characteristic subdirectories.

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

     verbose     =>        1,
     override    =>        0,

     identifier  =>    'sub',
     file_limit  =>        2,
     file_sort   =>      '+',

     separator   =>      '-',
     continue    =>        1,
     length      =>        5,
 ); 

It is of tremendous importance to notice that checking the return value is a must.
Leaving the return code untouched will not allow appropriate gathering of harmless
debug data (such as existing files) and system operations that failed. C<split_dir()>
does only report verbose output of mkpath to STDOUT. See B<OPTIONS / debug> on how to
become aware of existing files and failed system operations (I<copy> & I<unlink>).

B<RETURN VALUES>

=over 4

=item (1)

Files moved successfully.

=item (0)

No action.

=item (-1)

EXISTS.

(see OPTIONS / debug)

=item (-2)

FAILURE.

(see OPTIONS / debug)

=back

=cut

=head1 OPTIONS

=head2 numeric

Split files to subdirectories with a numeric suffix.

 %options = (  
     mode    =>    'num',

     source  =>    '/source',
     target  =>    '/target',

     verbose     =>        1,
     override    =>        0,
     
     identifier  =>    'sub',
     file_limit  =>        2,
     file_sort   =>      '+',

     separator   =>      '-',
     continue    =>        1,
     length      =>        5,
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

=item B<verbose>

If enabled, mkpath will output the pathes on creating
subdirectories.

 MODES
   1  enabled
   0  disabled

=item B<override>

overriding of existing files.

 MODES
   1  enabled
   0  disabled

=item B<identifier>

prefix of each subdirectory created.

=item B<file_limit>

limit of files per subdirectory.

=item B<file_sort>

sort order of files.

 MODES
   +  ascending
   -  descending

=item B<separator>

suffix separator.

=item B<continue>

numbering continuation.

 MODES
   1  enabled
   0  disabled    (will start at 1)

If numbering continuation is enabled, and numeric subdirectories are found
within target directory which match the given identifier and separator,
then the suffix numbering will be continued. Disabling numbering continuation
may interfere with existing files.

=item B<length>

character length of the suffix.

This option will have no effect, if its smaller than the current length
of the highest suffix number.

=back

=head2 characteristic

Split files to subdirectories with a characteristic suffix. Files
are assigned to subdirectories which suffixes equal the specified,
leading character(s) of the filenames.

 %options = (  
     mode    =>    'char',

     source  =>    '/source',
     target  =>    '/target',

     verbose     =>         1,
     override    =>         0,
     
     identifier  =>     'sub',
     
     separator   =>       '-',
     case        =>   'upper',
     length      =>         1,
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

=item B<verbose>

If enabled, mkpath will output the pathes on creating
subdirectories.

 MODES
   1  enabled
   0  disabled

=item B<override>

overriding of existing files.

 MODES
   1  enabled
   0  disabled

=item B<identifier>

prefix of each subdirectory created.

=item B<separator>

suffix separator.

=item B<case>

lower / upper case of the suffix.

 MODES
   lower
   upper

=item B<length>

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
not be transferred due to existing ones, has to be counted.
Each time a new splitting is attempted, the track will be reseted.

 %Dir::Split::track = (  
     source  =>    {  files  =>    512  
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

L<File::Basename>, L<File::Copy>, L<File::Find>, L<File::Path>, L<File::Spec>

=cut
