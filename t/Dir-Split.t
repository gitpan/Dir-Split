#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

use Dir::Split;
use File::Path;
use File::Temp;

our ($obj, $PACKAGE, $tmp_dir);

$obj = Dir::Split->new;
$tmp_dir = File::Temp::tmpnam();

# tests
BEGIN {
    $PACKAGE = 'Dir::Split';
    use_ok ($PACKAGE);
    require_ok ($PACKAGE);
}
isa_ok ($obj, $PACKAGE);
ok (mkpath ($tmp_dir, 0), 'mkpath');

# rm temp dir
rmtree ($tmp_dir, 0, 0) or die "Could not remove temp dir $tmp_dir: $!";
