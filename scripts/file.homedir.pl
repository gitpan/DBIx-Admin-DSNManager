#!/usr/bin/perl

use common::sense;
use warnings 'uninitialized';

use File::HomeDir;

# ----------------

my($x);

print 'Dist config dir: ', File::HomeDir -> my_dist_config('DBIx-Admin-DSNManager', {create => 1}), ". \n";
print "$x. \n";
