#!/usr/bin/perl -w

use Test::More tests => 4;

use Dir::Split;
my $Dir = Dir::Split->new;
use File::Path;

my $tmp_path = 'TMP1a2R3v032s13y';

ok (defined $Dir, 'new()');
ok (ref $Dir eq 'Dir::Split', 'class name');
ok (mkpath ('./$tmp_path', 0), 'mkpath');
ok (rmtree ('./$tmp_path', 0, 0), 'rmpath');
