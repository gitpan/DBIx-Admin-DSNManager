#!/usr/bin/perl

use common::sense;
use warnings 'uninitialized';

use File::Spec;
use File::Temp;

use FindBin;

use Test::More;

# Start at 1 since $test_count++ in BEGIN() does not work :-).

our $test_count = 1;

# -----------------------------------------------

sub BEGIN { use_ok('DBIx::Admin::DSNManager'); }

# -----------------------------------------------

my($dsn)       = 'dbi:Pg:dbname=prod';
my($attr)      = {AutoCommit => 1, PrintError => 1, RaiseError => 1};
my($file_name) = File::Spec -> catdir($FindBin::Bin, 'dsn.ini');
my($section)   = 'Pg.2';
my($use_it)    = 1;
my($manager)   = DBIx::Admin::DSNManager -> new
(
	file_name => $file_name,
	verbose   => 1,
) || BAIL_OUT($DBIx::Admin::DSNManager::errstr);

isa_ok($manager, 'DBIx::Admin::DSNManager', 'Class of object');

$test_count++;

my($config) = $manager -> config;

ok($$config{$section}{dsn} eq $dsn, 'Recovered dsn from file');

$test_count++;

#diag 'File: ' . $manager -> hashref2string($$config{$section}{attributes});
#diag 'Want: ' . $manager -> hashref2string($attr);

is_deeply($$config{$section}{attributes}, $attr, 'Recovered attributes hashref from file');

$test_count++;

ok($$config{$section}{use_for_testing} eq $use_it, 'Recovered use_for_testing from file');

$test_count++;

done_testing($test_count);
