#
# Uncomment the lines at the bottom accordingly
# whether numeric or characteristic splitting shall be
# committed.
#
# Source & target dir vars might require some adjustment.
#


use Dir::Split;

use strict;
use warnings;

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


# numeric object
#
#$dir = Dir::Split->new(\%num_options);

# characteristic object
#
#$dir = Dir::Split->new(\%char_options);

$dir->{'source'} = '/source';
$dir->{'target'} = '/target';

# split & evaluate the return status.
#
#$return = $dir->split;

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
elsif ($return == 0) {
    print "None moved.\n";
}
# existing files
elsif ($return == -1) {
    print <<'EOT';
--------------------------
START: DEBUG DATA - EXISTS
--------------------------
EOT
    foreach (@Dir::Split::exists) {
        print "file:\t$_\n";
    }
    print <<"EOT";
------------------------
END: DEBUG DATA - EXISTS
------------------------

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
--------------------------
START: DEBUG DATA - EXISTS
--------------------------
EOT
        foreach (@Dir::Split::exists) {
            print "file:\t$_\n";
        }
        print <<'EOT';
------------------------
END: DEBUG DATA - EXISTS
------------------------
EOT
    }
    print <<'EOT';
---------------------------
START: DEBUG DATA - FAILURE
---------------------------
EOT
    foreach (@{$Dir::Split::failure{'copy'}}) {
        print "copy failed:\t$_\n";
    }
    foreach (@{$Dir::Split::failure{'unlink'}}) {
        print "unlink failed:\t$_\n";
    }
    print <<"EOT";
-------------------------
END: DEBUG DATA - FAILURE
-------------------------

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
