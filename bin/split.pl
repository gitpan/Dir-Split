#!/usr/bin/perl

#
# Uncomment the lines at the bottom accordingly
# whether numeric or characteristic splitting shall be
# committed.
#

use strict;
use warnings;

use Dir::Split;

my ($return, %num_options, %char_options, $dir);

$return = -255;


%num_options = (  mode    =>    'num',

                  options => {  verbose     =>           1,
                                override    =>           0,
                  },
                  sub_dir => {  identifier  =>       'sub',
                                file_limit  =>           2,
                                file_sort   =>         '+',
                  },
                  suffix  => {  separator   =>         '-',
                                continue    =>           1,
                                length      =>           5,
                  },
);

%char_options = (  mode    =>    'char',

                   options => {  verbose     =>           1,
                                 override    =>           0,
                   },
                   sub_dir => {  identifier  =>       'sub',
                   },
                   suffix  => {  separator   =>         '-',
                                 case        =>     'upper',
                                 length      =>           1,
                   },

);


# numeric splitting
#
#$dir = Dir::Split->new(\%num_options);

# characteristic splitting
#
#$dir = Dir::Split->new(\%char_options);

# source and target dir
#
#$dir->{'source'} = '/source';
#$dir->{'target'} = '/target';

# traversal mode and options.
#
#$Dir::Split::traverse        = 1;
#$Dir::Split::traverse_depth  = 2;
#$Dir::Split::traverse_unlink = 0;
#$Dir::Split::traverse_rmdir  = 0;

# split and evaluate the return status.
#
#$return = $dir->split();

# action
if ($return == 1) {
    print <<"EOT";

-------------------
Source - files: $Dir::Split::track{'source'}{'files'}
Target - files: $Dir::Split::track{'target'}{'files'}
Target - dirs : $Dir::Split::track{'target'}{'dirs'}
-------------------
EOT
}
# no action
elsif ($return == 0) { print "None moved.\n" }
# existing files
elsif ($return == -1) {
    print <<'EOT';
---------------------
START: DEBUG - EXISTS
---------------------
EOT

    foreach (@Dir::Split::exists) {
        print "file:\t$_\n";
    }
    
    print <<"EOT";
-------------------
END: DEBUG - EXISTS
-------------------

-------------------
Source - files: $Dir::Split::track{'source'}{'files'}
Target - files: $Dir::Split::track{'target'}{'files'}
Target - dirs : $Dir::Split::track{'target'}{'dirs'}
-------------------
EOT
}
# copy or unlink failure
elsif ($return == -2) {
    if (@Dir::Split::exists) {
    
        print <<'EOT';
---------------------
START: DEBUG - EXISTS
---------------------
EOT

        foreach (@Dir::Split::exists) {
            print "file:\t$_\n";
        }
	
        print <<'EOT';
-------------------
END: DEBUG - EXISTS
-------------------
EOT
    }
    
    print <<'EOT';
----------------------
START: DEBUG - FAILURE
----------------------
EOT

    foreach (@{$Dir::Split::failure{'copy'}}) {
        print "copy failed:\t$_\n";
    }
    foreach (@{$Dir::Split::failure{'unlink'}}) {
        print "unlink failed:\t$_\n";
    }
    
    print <<"EOT";
--------------------
END: DEBUG - FAILURE
--------------------

-------------------
Source - files: $Dir::Split::track{'source'}{'files'}
Target - files: $Dir::Split::track{'target'}{'files'}
Target - dirs : $Dir::Split::track{'target'}{'dirs'}
-------------------
EOT
} # no config
else {
    print __FILE__." requires some adjustment.\n";
}
