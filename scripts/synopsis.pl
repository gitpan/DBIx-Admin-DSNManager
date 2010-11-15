#!/usr/bin/perl

use common::sense;
use warnings 'uninitialized';

use DBIx::Admin::DSNManager;

# --------------------------

my($man1) = DBIx::Admin::DSNManager -> new
(
	config  => {'Pg.1' => {dsn => 'dbi:Pg:dbname=test', username => 'me', active => 1} },
	verbose => 1,
) || die $DBIx::Admin::DSNManager::errstr;

my($file_name) = '/tmp/dsn.ini';

$man1 -> write($file_name);

my($man2) = DBIx::Admin::DSNManager -> new
(
	file_name => $file_name,
	verbose   => 1,
) || die $DBIx::Admin::DSNManager::errstr;

$man2 -> report;
