use Dir::Split;

#
# Uncomment the lines at the bottom accordingly
# whether numeric or characteristic splitting shall be
# committed.
#
# Source & target dir vars might require some adjustment.
#

%num_behavior = (  mode    =>    'num',

                   options => {  verbose        =>           1,
                                 warn           =>       'all',
                                 override       =>      'none',
                   },

                   sub_dir => {  identifier     =>      'test',
                                 file_limit     =>           2,
                                 file_sort      =>         '+',
                   },

                   suffix  => {  continue_num   =>         'y',
                                 separator      =>         '-',
                                 length         =>           5,
                   },
);

%char_behavior = (  mode    =>    'char',

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

#$source_dir = '/tmp/src';
#$target_dir = '/tmp/target';


# numeric splitting
#
#my $dir = Dir::Split->new (\%num_behavior);

# characteristic splitting
#
#my $dir = Dir::Split->new (\%char_behavior);

# evaluate the return status and squeek accordingly.
#
#if ($files_moved = $dir->split (\$source_dir, \$target_dir)) {
#    print "$files_moved files moved.\n";
#}
#else {
#    print "None moved.\n";
#}
