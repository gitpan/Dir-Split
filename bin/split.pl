#!/usr/bin/perl

use strict;
use warnings;
use Dir::Split qw(split_dir);

our(%form, %form_o);
my $return = -255;



#
# Modify following lines accordingly to whether 
# numeric or characteristic splitting shall be
# committed.
#

my %num_options = (  
   mode    =>    'num',

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

my %char_options = (  
   mode    =>    'char',

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


# traversal mode and options
#
#$Dir::Split::Traverse        = 1;
#$Dir::Split::Traverse_unlink = 1;
#$Dir::Split::Traverse_rmdir  = 1;


# numeric splitting
#
#$return = split_dir(%num_options);

# characteristic splitting
#
#$return = split_dir(%char_options);



# END OF CONFIG
###############

# action
if ($return == 1) { formwrite('track') }
# no action
elsif ($return == 0) { print "None moved.\n" }
# existing files
elsif ($return == -1) {
    local %form_o;

    $form_o{header} = 'EXISTS';
    $form_o{ul} = '-' x length($form_o{header});
     
    formwrite('start_debug');

    for (@Dir::Split::exists) {
        print "file:\t$_\n";
    }
    
    formwrite('end_debug'); 
    formwrite('track');
}
# copy or unlink failure
elsif ($return == -2) {
    local %form_o;

    if (@Dir::Split::exists) {
        $form_o{header} = 'EXISTS';
        $form_o{ul} = '-' x length($form_o{header});
	
        formwrite('start_debug');

        for (@Dir::Split::exists) {
            print "file:\t$_\n";
        }
	
	formwrite('end_debug');
    }
    
    $form_o{header} = 'FAILURE';
    $form_o{ul} = '-' x length($form_o{header});
    
    formwrite('start_debug');
    
    for (@{$Dir::Split::failure{copy}}) {
        print "copy failed:\t$_\n";
    }
    for (@{$Dir::Split::failure{unlink}}) {
        print "unlink failed:\t$_\n";
    }
    
    formwrite('end_debug');
    formwrite('track');
}
# no config
else {
    print __FILE__." requires adjustment.\n";
}

sub formwrite {
    my $ident = shift;
    
    no warnings 'redefine';
    eval $form{$ident};
    die $@ if $@;
    write;
}

BEGIN {
    $form{track} = 'format = 
-------------------
source - files: @<<<
sprintf "%3d", $Dir::Split::track{source}{files}
target - files: @<<<
sprintf "%3d", $Dir::Split::track{target}{files}
target - dirs : @<<<
sprintf "%3d", $Dir::Split::track{target}{dirs}
-------------------
.';

    $form{start_debug} = 'format =
---------------@<<<<<<<<<<
$form_o{ul}
START: DEBUG - @<<<<<<<<<<
$form_o{header}
---------------@<<<<<<<<<<
$form_o{ul} 
.';
    
    $form{end_debug} = 'format =
---------------@<<<<<<<<<<
$form_o{ul}
END  : DEBUG - @<<<<<<<<<<
$form_o{header}
---------------@<<<<<<<<<<
$form_o{ul} 
.';    
}
