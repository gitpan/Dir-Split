#!/usr/bin/perl -w

use Test::More tests => 4;

use Dir::Split;
use File::Path;

my $obj = Dir::Split->new;
my $tmp_path = 'TMP1a2R3v032s13y';

# tests
BEGIN {
    my $mname = 'Dir::Split';
    use_ok ($mname);
    require_ok ($mname);
}
isa_ok ($obj, 'Dir::Split');
ok (mkpath ('./$tmp_path', 0), 'mkpath');

# rm temp dir
rmtree ('./$tmp_path', 0, 0) or die "Could not remove ./$tmp_path: $!";
