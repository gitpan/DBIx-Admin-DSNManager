#!/usr/bin/perl

use common::sense;
use warnings 'uninitialized';

use DBIx::Admin::DSNManager;

# -------------------

my($m) = DBIx::Admin::DSNManager -> new(verbose => 1) || die $DBIx::Admin::DSNManager::errstr;

$m -> report;
