#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;

use Dir::Split;

use File::Path;
use File::Temp;

my ($PACKAGE, $tmp_dir);

BEGIN {
    $PACKAGE = 'Dir::Split';
    use_ok($PACKAGE);
    require_ok($PACKAGE);
}

$tmp_dir = File::Temp::tmpnam();
ok(mkpath($tmp_dir, 0), 'mkpath();');
rmtree $tmp_dir,0,0 or die "Could not remove temp dir $tmp_dir: $!";
