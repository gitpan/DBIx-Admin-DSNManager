use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile
(
	($] ge '5.005') ?
	(
		AUTHOR   => 'Ron Savage (ron@savage.net.au)',
		ABSTRACT => 'Manage a file of DSNs, for both testing and production',
	) : (),
	clean =>
	{
		FILES => 'blib/* Makefile MANIFEST DBIx-Admin::DSNManager-*'
	},
	dist =>
	{
		COMPRESS => 'gzip',
		SUFFIX   => 'gz'
	},
	DISTNAME  => 'DBIx-Admin-DSNManager',
	NAME      => 'DBIx::Admin::DSNManager',
	PL_FILES  => {},
	PREREQ_PM =>
	{
		common::sense    => 3.3,
		Config::Tiny     => 2.12,
		DBI              => 1.612,
		File::HomeDir    => 0.93,
		File::Slurp      => 9999.13,
		File::Spec       => 3.31,
		File::Temp       => 0.22,
		Hash::FieldHash  => 0.1,
		Test::More       => 0.96,
		Test::Pod        => 1.41,
		Try::Tiny        => 0.06,
	},
	VERSION_FROM => 'lib/DBIx/Admin/DSNManager.pm',
);
