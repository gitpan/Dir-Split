#!/usr/bin/perl

#
# Uncomment the lines below accordingly whether 
# numeric or characteristic splitting shall be
# committed.
#

use strict;
use warnings;

use Dir::Split q/split_dir/;

my ($return, %num_options, %char_options);

$return = -255;


%num_options = (  mode    =>    'num',

                  source  =>    '/source',
		  target  =>    '/target',

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

                   source  =>    '/source',
		   target  =>    '/target',

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


# traversal mode and options.
#
#$Dir::Split::Traverse        = 1;
#$Dir::Split::Traverse_unlink = 1;
#$Dir::Split::Traverse_rmdir  = 1;

# numeric splitting
#
#$return = split_dir(\%num_options);

# characteristic splitting
#
#$return = split_dir(\%char_options);

# action
if ($return == 1) {
    print <<"EOT";

-------------------
Source - files: $Dir::Split::track{source}{files}
Target - files: $Dir::Split::track{target}{files}
Target - dirs : $Dir::Split::track{target}{dirs}
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
Source - files: $Dir::Split::track{source}{files}
Target - files: $Dir::Split::track{target}{files}
Target - dirs : $Dir::Split::track{target}{dirs}
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

    foreach (@{$Dir::Split::failure{copy}}) {
        print "copy failed:\t$_\n";
    }
    foreach (@{$Dir::Split::failure{unlink}}) {
        print "unlink failed:\t$_\n";
    }
    
    print <<"EOT";
--------------------
END: DEBUG - FAILURE
--------------------

-------------------
Source - files: $Dir::Split::track{source}{files}
Target - files: $Dir::Split::track{target}{files}
Target - dirs : $Dir::Split::track{target}{dirs}
-------------------
EOT
} # no config
else {
    print __FILE__." requires adjustment.\n";
}
