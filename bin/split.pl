#!/usr/bin/perl

#
# Uncomment the lines at the bottom accordingly
# whether numeric or characteristic splitting shall be
# committed.
#

use strict 'vars';
use warnings;

$SIG{__WARN__} = sub { return '' };

use Dir::Split q(split_dir);

our ($return, %num_options, %char_options, %form, %form_o);

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
if ($return == 1) { formwrite('track') }
# no action
elsif ($return == 0) { print "None moved.\n" }
# existing files
elsif ($return == -1) {
    local %form_o;

    $form_o{header} = 'EXISTS';
    $form_o{ul} = '-' x length $form_o{header};
     
    formwrite('start_debug');

    foreach (@Dir::Split::exists) {
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
        $form_o{ul} = '-' x length $form_o{header};
	
        formwrite('start_debug');

        foreach (@Dir::Split::exists) {
            print "file:\t$_\n";
        }
	
	formwrite('end_debug');
    }
    
    $form_o{header} = 'FAILURE';
    $form_o{ul} = '-' x length $form_o{header};
    formwrite('start_debug');
    
    foreach (@{$Dir::Split::failure{copy}}) {
        print "copy failed:\t$_\n";
    }
    foreach (@{$Dir::Split::failure{unlink}}) {
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
    
    eval $form{$ident};
    if ($@) { require Carp; Carp::croak $@; }
    write;
}

BEGIN {
    $form{track} = 'format = 
-------------------
Source - files: @<<<
sprintf "%3d", $Dir::Split::track{source}{files}
Target - files: @<<<
sprintf "%3d", $Dir::Split::track{target}{files}
Target - dirs : @<<<
sprintf "%3d", $Dir::Split::track{target}{dirs}
-------------------
.
    ';

    $form{start_debug} = 'format =
---------------@<<<<<<<<<<
$form_o{ul}
START: DEBUG - @<<<<<<<<<<
$form_o{header}
---------------@<<<<<<<<<<
$form_o{ul} 
.
    ';
    
    $form{end_debug} = 'format =
---------------@<<<<<<<<<<
$form_o{ul}
END  : DEBUG - @<<<<<<<<<<
$form_o{header}
---------------@<<<<<<<<<<
$form_o{ul} 
.
    ';    
}
