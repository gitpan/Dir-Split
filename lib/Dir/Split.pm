#============================================================================
#
# Dir::Split module
#
# Moves files from a source directory to numbered subdirectories within
# a destination directory.
#
# $Id: Split.pm,v 0.01 2003/12/21 22:53:12 st.schubiger Exp $
#
#============================================================================

package Dir::Split;

MODULES: {
    use Carp;
    use File::Copy 'cp';
    use File::Path;
    use SelfLoader;
}

$VERSION = 0.01;

1;

__DATA__


#--------------------
# new (namespace)
#
# Object constructor.
#--------------------

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}


#-----------------------------------------------------
# split (\$source_dir, \%hash_opt, \$destin_dir)
#
# Splits the files the source directory ($source_dir)
# consists of by applying the options (%hash_opt) to
# the destination directory ($destin_dir).
#-----------------------------------------------------

sub split {
    my $self = shift;
    local ($scalar_source_dir_ref, $hash_opt_ref, $scalar_target_dir_ref) = @_;

    # local variables
    local ($sub_dir_ident,
           $sub_dir_f_sort,
           $suffix_sep,
           $suffix_l);

    # private variables
    my ($debug_mode,
        $sub_dir_f_limit,
        $suffix_cont_num);

    LOCALES: { # scalar assignments
        $debug_mode = ${$hash_opt_ref}{'debug'};

        $sub_dir_ident = ${$hash_opt_ref}{'sub_dir'}{'identifier'};
        $sub_dir_f_limit = ${$hash_opt_ref}{'sub_dir'}{'file_limit'};
        $sub_dir_f_sort = ${$hash_opt_ref}{'sub_dir'}{'file_sort'};

        $suffix_sep = ${$hash_opt_ref}{'suffix'}{'separator'};
        $suffix_l = ${$hash_opt_ref}{'suffix'}{'length'};
        $suffix_cont_num = ${$hash_opt_ref}{'suffix'}{'continue_numbering'};
    }

    my (@files, $i);
    $self->_eval_files (\@files);
    if ($suffix_cont_num eq 'y') {
        $self->_eval_suffix_highest_number (\$i);
    }
    unless ($i) { $i = 1 }
    $self->_eval_suffix_sum_up (\$i);

    for (; @files; $i++) {
        my $sub_dir = $sub_dir_ident . "$suffix_sep$i";

        unless (mkpath "${$scalar_target_dir_ref}/$sub_dir", $debug_mode) {
            croak "Could not create ${$scalar_target_dir_ref}/$sub_dir";
        }

        for (my $i = 0; $i < $sub_dir_f_limit; $i++) { # cp & rm files
            last unless my $file = shift (@files);
            cp $file, "${$scalar_target_dir_ref}/$sub_dir";
            croak "Could not remove $file: $!" unless unlink $file;
        }
    }
}


#-----------------------------------------------------
# _eval_files (\@files)
#
# Internally used by &split to read the files the
# source directory consists of, to sort them according
# to the options (lowercase filenames) and transform
# the relative paths to absolute ones.
#-----------------------------------------------------

sub _eval_files {
    my ($self, $array_files_ref) = @_;

    opendir S, "${$scalar_source_dir_ref}" or
        croak "Could not open ${$scalar_source_dir_ref} for read-access: $!";
    my @files = grep { !/^\./ } readdir S;
    closedir S or croak "Could not close ${$scalar_source_dir_ref}: $!";

    @files = map { lc } @files if ($sub_dir_f_sort eq '+' || $sub_dir_f_sort eq '-'); # lower-case filenames if sorting mode

    if ($sub_dir_f_sort eq '+') { # ascending sort order
        @files = sort @files;
    }
    elsif ($sub_dir_f_sort eq '-') { # descending sort order
        @files = reverse @files;
    }
    @files = map { "${$scalar_source_dir_ref}/$_" } @files; # map absolute paths

    @{$array_files_ref} = @files;
}


#---------------------------------------------------
# _eval_suffix_highest_number (\$suffix)
#
# Internally used by &split to evaluate the highest
# existing subdir suffix number in order to continue
# numbering where it stopped previously.
#---------------------------------------------------

sub _eval_suffix_highest_number {
    my ($self, $scalar_suffix_ref) = @_;

    opendir D, "${$scalar_target_dir_ref}" or
        croak "Could not open ${$scalar_target_dir_ref} for read-access: $!";
    my @files = readdir D;
    closedir D or croak "Could not close ${$scalar_target_dir_ref}: $!";

    my @dirs = grep { opendir E, "${$scalar_target_dir_ref}/$_" } @files
        && undef @files; # crop files

    my $sep = quotemeta ($suffix_sep);
    foreach (@dirs) {
        $_ =~ s/(.+?)$sep(.*)/$1/; # extract exist. identifier (prefix)
        if ($sub_dir_ident eq $_) { # supplied identifier matches existing one
            if ($2 > $i) { $i = $2 } # increase suffix to highest number
        }
    }
    $i++; # suffix + 1 - avoid collisions with curr. subdirs

    ${$scalar_suffix_ref} = $i;
}


#------------------------------------------------
# _eval_suffix_sum_up (\$suffix)
#
# Internally used by &split to sum up the suffix
# with a given amount of zeros and to concatenate
# the numbering at the end.
#------------------------------------------------

sub _eval_suffix_sum_up {
    my ($self, $scalar_suffix_ref) = @_;

    my $i = ${$scalar_suffix_ref};
    if ( length ($i) < $suffix_l || length ($i) > $suffix_l) { # suffix length too low or to big
        my $format = "%0." . "$suffix_l" . 'd';
        $i = sprintf $format, $i; # adjust suffix length
    }

    ${$scalar_suffix_ref} = $i;
}

__END__

=head1 NAME

Dir::Split

=head1 DESCRIPTION

Module that moves files from a source directory to numbered subdirectories within
a destination directory.

=head1 METHODS

=over 4

=item new Dir::Split;

Object constructor.

=item split (\$source_dir, \%hash_opt, \$destin_dir);

$source_dir specifies the source directory.

$destin_dir specifies the destination directory.

%hash_opt contains the options that will affect the splitting process.

debug sets the debug mode (see table DEBUG MODES below); if enabled,
mkpath will act verbose on creating subdirectories.

sub_dir => identifier will affect the prefix of each subdirectory.
sub_dir => file_limit sets the limit of files per each subdirectory.
sub_dir => file_sort defines the sorting order of files
(see table SORT MODES below).

suffix => separator contains the string that separates the prefix (identifier)
from the suffix. suffix => length is an non-floating-point integer that sets
the amount of zeros to be added to the subdirectory numbering.
suffix => continue_numbering defines whether the numbering shall be continued
where it previously stopped or start at 1 (see table CONTINUE NUMBERING MODES below).

    %hash_opt = (
                   debug   =>    0,

                   sub_dir => {
                                 identifier          =>    'system',
                                 file_limit          =>         '2',
                                 file_sort           =>         '+',
                   },

                   suffix =>  {
                                 separator           =>         '.',
                                 length              =>           4,
                                 continue_numbering  =>         'y',
                   },

    );

  DEBUG MODES
    0  disabled
    1  enabled

  SORT MODES
    +  ascending sort order
    -  descending sort order

  CONTINUE NUMBERING MODES
    y  yes
    n  no

=back

=head1 SEE ALSO

perl(1)

=head1 COPYRIGHT

Copyright 2003 Steven Schubiger

This program is free software; you may redistribute it and/or modify it under the same terms as Perl itself.

=cut


