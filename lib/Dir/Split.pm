#============================================================================
#
# Dir::Split extension
#
# Splits the files of a directory to subdirectories.
#
# $Id: Split.pm,v 0.05 2003/12/25 13:44:53 st.schubiger Exp $
#
#============================================================================

package Dir::Split;

# pragmas
use strict;
use vars qw($VERSION);
#use warnings;

# global variables
our ($hash_opt_ref,
     $scalar_source_dir_ref,
     $scalar_target_dir_ref,
     $sub_dir_ident,
     $sub_dir_f_sort,
     $suffix_l,
     $suffix_sep);

CONSTANTS: {
    $VERSION = 0.05;
}

MODULES: {
    use Carp;
    use File::Copy 'cp';
    use File::Path;
}

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
    local ($scalar_source_dir_ref, $scalar_target_dir_ref, $hash_opt_ref) = @_;
    croak q~Invalid arguments: split (\$source_dir, \$target_dir, \%hash_opt)~
      unless (ref $scalar_source_dir_ref eq 'SCALAR') && (ref $scalar_target_dir_ref eq 'SCALAR')
      && (ref $hash_opt_ref eq 'HASH');

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
            croak qq~Could not create ${$scalar_target_dir_ref}/$sub_dir: $!~;
        }

        for (my $i = 0; $i < $sub_dir_f_limit; $i++) { # cp & rm files
            last unless my $file = shift @files;
            cp $file, "${$scalar_target_dir_ref}/$sub_dir";
            croak qq~Could not remove $file: $!~ unless unlink $file;
        }
    }
}

#-----------------------------------------------------
# _eval_files (\@files)
#
# Internally called by split() to read the files the
# source directory consists of, to sort them according
# to the options (lowercase filenames) and transform
# the relative paths to absolute ones.
#-----------------------------------------------------

sub _eval_files {
    my ($self, $array_files_ref) = @_;

    opendir S, "${$scalar_source_dir_ref}" or
      croak qq~Could not open ${$scalar_source_dir_ref} for read-access: $!~;
    my @files = grep { !/^\./ } readdir S;
    closedir S or croak qq~Could not close ${$scalar_source_dir_ref}: $!~;

    # if files are to be sorted, lowercase filenames
    @files = map { lc } @files if $sub_dir_f_sort eq '+' || $sub_dir_f_sort eq '-';
    if ($sub_dir_f_sort eq '+') { # ascending sort order
        @files = sort @files;
    }
    elsif ($sub_dir_f_sort eq '-') { # descending sort order
        @files = reverse @files;
    }
    @files = map { "${$scalar_source_dir_ref}/$_" } @files; # map absolute paths

    @{$array_files_ref} = @files;
}

#-----------------------------------------------------
# _eval_suffix_highest_number (\$suffix)
#
# Internally called by split() to evaluate the highest
# existing subdir suffix number in order to continue
# numbering where it stopped previously.
#-----------------------------------------------------

sub _eval_suffix_highest_number {
    my ($self, $scalar_suffix_ref) = @_;

    opendir D, "${$scalar_target_dir_ref}" or
      croak qq~Could not open ${$scalar_target_dir_ref} for read-access: $!~;
    my @files = readdir D;
    closedir D or croak qq~Could not close ${$scalar_target_dir_ref}: $!~;

    my @dirs = grep { opendir E, "${$scalar_target_dir_ref}/$_" } @files # crop files
        && closedir E && undef @files;

    my ($i, $sep);
    $sep = quotemeta ($suffix_sep);
    foreach (@dirs) {
        $_ =~ s/(.+?)$sep(.*)/$1/; # extract exist. identifier (prefix)
        if ($sub_dir_ident eq $_) { # supplied identifier matches existing one
            if ($2 > $i) { $i = $2 } # increase suffix to highest number
        }
    }
    $i++; # suffix + 1 - avoid collisions with curr. subdirs

    ${$scalar_suffix_ref} = $i;
}

#--------------------------------------------------
# _eval_suffix_sum_up (\$suffix)
#
# Internally called by split() to sum up the suffix
# with a given amount of zeros and to concatenate
# the numbering at the end.
#--------------------------------------------------

sub _eval_suffix_sum_up {
    my ($self, $scalar_suffix_ref) = @_;

    my $i = ${$scalar_suffix_ref};
    # suffix length too low or to big
    if (length ($i) < $suffix_l || length ($i) > $suffix_l) {
        my $format = "%0." . "$suffix_l" . 'd';
        $i = sprintf $format, $i; # adjust suffix length
    }

    ${$scalar_suffix_ref} = $i;
}

1;

__END__

=head1 NAME

Dir::Split - Splits the files of a directory to subdirectories

=head1 SYNOPSIS

    use Dir::Split;

    my $dir = Dir::Split->new;

    $source_dir = '/var/tmp/src';
    $destin_dir = '/var/tmp/destin';

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

    $dir->split (\$source_dir, \$destin_dir, \%hash_opt);

=head1 DESCRIPTION

Dir::Split moves files from a source directory to numbered subdirectories within
a destination directory.

=head1 METHODS

=over 4

=item $dir = Dir::Split->new;

Object constructor.

=item $dir->split (\$source_dir, \$destin_dir, \%hash_opt);

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
    y   yes
    ''  no

=back

=head1 EXAMPLES

Assuming the source directory '/var/tmp/src' contains 9 files, the directory
tree in the destination directory '/var/tmp/destin' will look as following:

    + /var/tmp/destin
    +- system.0001 / 2 file(s)
    +- system.0002 / 2 "
    +- system.0003 / 2 "
    +- system.0004 / 2 "
    +- system.0005 / 1 "

=head1 SEE ALSO

perl(1)

=head1 COPYRIGHT

Copyright 2003 Steven Schubiger, E<lt>st.schubiger@swissinfo.orgE<gt>.

This program is free software; you may redistribute it and/or modify it under the same terms as Perl itself.

=cut



