#! /usr/local/bin/perl

use strict;
use warnings;
use Dir::Split;
use File::Path;
use File::Temp;

use Test::More tests => 3;

BEGIN {
    my $PACKAGE = 'Dir::Split';
    use_ok($PACKAGE);
    require_ok($PACKAGE);
}

my $tmpdir = File::Temp::tmpnam();
ok(mkpath($tmpdir, 0), 'mkpath();');
rmtree($tmpdir, 0, 0) or die "Could not remove temp dir $tmpdir: $!";
