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


#%Dir::Split::warn = (  dir   =>    "exists (d)\t",
#                       file  =>    "exists (f)\t",
#);

my %num_behavior = (  mode    =>    'num',

                      options => {  verbose     =>           1,
                                    warn        =>       'all',
                                    override    =>      'none',
                      },
                      sub_dir => {  identifier  =>       'sub',
                                    file_limit  =>           2,
                                    file_sort   =>         '+',
                      },
                      suffix  => {  separator   =>         '-',
                                    continue    =>         'y',
                                    length      =>           5,
                      },
);

my %char_behavior = (  mode    =>    'char',

                       options => {  verbose     =>           1,
                                     warn        =>       'all',
                                     override    =>      'none',
                       },
                       sub_dir => {  identifier  =>       'sub',
                       },
                       suffix  => {  separator   =>         '-',
                                     case        =>     'lower',
                       },

);


# numeric object
#
my $dir = Dir::Split->new(\%num_behavior); 

# characteristic object
#
#my $dir = Dir::Split->new(\%char_behavior);

$dir->{'source'} = '/tmp/source';
$dir->{'target'} = '/tmp/target';

# split, evaluate the return status and squeek accordingly.
#
#my $return = $dir->split;

# action or failure
#if ($return == 1 || $return == -1) {
#    print <<"EOT";
#
#-------------------
#Source - files: $Dir::Split::track{'source'}{'files'}
#Target - files: $Dir::Split::track{'target'}{'files'}
#Target - dirs : $Dir::Split::track{'target'}{'dirs'}
#-------------------
#EOT
#} # no action
#elsif ($return == 0) {
#    print "None moved.\n";
#} # no return code
#else {
#    print "Program abortion - no return code.\n";
#}
