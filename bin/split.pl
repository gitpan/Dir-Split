use Dir::Split;

use strict;
use warnings;

#
# Uncomment the lines at the bottom accordingly
# whether numeric or characteristic splitting shall be
# committed.
#
# Source & target dir vars might require some adjustment.
#


#%Dir::Split::warn = (  dir  =>    "exists (d)\t",
#                       file =>    "exists (f)\t",
#);

my %num_behavior = (  mode    =>    'num',

                      options => {  verbose        =>           1,
                                    warn           =>       'all',
                                    override       =>      'none',
                      },

                      sub_dir => {  identifier     =>      'test',
                                    file_limit     =>           2,
                                    file_sort      =>         '+',
                      },

                      suffix  => {  separator      =>         '-',
                                    continue       =>         'y',
                                    length         =>           5,
                      },
);

my %char_behavior = (  mode    =>    'char',

                       options => {  verbose     =>           1,
                                     warn        =>       'all',
                                     override    =>      'none',
                       },

                       sub_dir => {  identifier  =>      'test',
                       },

                       suffix  => {  separator   =>         '-',
                                     case        =>     'lower',
                       },

);

my $source_dir = '/tmp/src';
my $target_dir = '/tmp/target';


# numeric object
#
#my $dir = Dir::Split->new(\%num_behavior);

# characteristic object
#
#my $dir = Dir::Split->new(\%char_behavior);

# split, evaluate the return status and squeek accordingly.
#
#if (my $files_moved = $dir->split(\$source_dir, \$target_dir)) {
#    print "$files_moved files moved.\n";
#}
#else {
#    print "None moved.\n";
#}
