#! /usr/bin/perl

use strict;
use warnings;
use Dir::Split qw(split_dir);

our (%Form, %Form_opt);
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
 
   verbose     =>        1,
   override    =>        0,

   identifier  =>    'sub',
   file_limit  =>        2,
   file_sort   =>      '+',
   
   separator   =>      '-',
   continue    =>        1,
   length      =>        5,
);

my %char_options = (  
   mode    =>    'char',

   source  =>    '/source',
   target  =>    '/target',

   verbose     =>          1,
   override    =>          0,
  
   identifier  =>      'sub',

   separator   =>        '-',
   case        =>    'upper',
   length      =>          1,

);


# traversal mode and options
#
#$Dir::Split::Traverse        = 1;
#$Dir::Split::Traverse_unlink = 1;
#$Dir::Split::Traverse_rmdir  = 1;


# numeric splitting
#
#$return = split_dir( %num_options );

# characteristic splitting
#
#$return = split_dir( %char_options );



# End of config
###############

# action
if ($return == 1) { 
    formwrite( 'track' );
}
# no action
elsif ($return == 0) { 
    print "None moved.\n";
}
# existing files
elsif ($return == -1) {
    local %Form_opt;

    $Form_opt{header} = 'EXISTS';
    $Form_opt{ul} = '-' x length $Form_opt{header};
     
    formwrite( 'start_debug' );

    for my $file (@Dir::Split::exists) {
        print "file:\t$file\n";
    }
    
    formwrite( 'end_debug' ); 
    formwrite( 'track' );
}
# copy or unlink failure
elsif ($return == -2) {
    local %Form_opt;

    if (@Dir::Split::exists) {
        $Form_opt{header} = 'EXISTS';
        $Form_opt{ul} = '-' x length $Form_opt{header};
	
        formwrite( 'start_debug' );

        for my $file (@Dir::Split::exists) {
            print "file:\t$file\n";
        }
	
	formwrite( 'end_debug' );
    }
    
    $Form_opt{header} = 'FAILURE';
    $Form_opt{ul} = '-' x length $Form_opt{header};
    
    formwrite( 'start_debug' );
    
    for my $file (@{$Dir::Split::failure{copy}}) {
        print "copy failed:\t$file\n";
    }
    for my $file (@{$Dir::Split::failure{unlink}}) {
        print "unlink failed:\t$file\n";
    }
    
    formwrite( 'end_debug' );
    formwrite( 'track' );
}
# no config
else {
    print __FILE__." requires adjustment\n";
}

sub formwrite {
    my ($ident) = @_;
    
    no warnings 'redefine';
    eval $Form{$ident};
    die $@ if $@;
    write;
}

BEGIN {
    $Form{track} = 'format = 
-------------------
source - files: @<<<
sprintf "%3d", $Dir::Split::track{source}{files}
target - files: @<<<
sprintf "%3d", $Dir::Split::track{target}{files}
target - dirs : @<<<
sprintf "%3d", $Dir::Split::track{target}{dirs}
-------------------
.';

    $Form{start_debug} = 'format =
---------------@<<<<<<<<<<
$Form_opt{ul}
START: DEBUG - @<<<<<<<<<<
$Form_opt{header}
---------------@<<<<<<<<<<
$Form_opt{ul} 
.';
    
    $Form{end_debug} = 'format =
---------------@<<<<<<<<<<
$Form_opt{ul}
END  : DEBUG - @<<<<<<<<<<
$Form_opt{header}
---------------@<<<<<<<<<<
$Form_opt{ul} 
.';    
}
