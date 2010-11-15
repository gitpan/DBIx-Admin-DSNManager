use Module::Build;

Module::Build -> new
(
	module_name    => 'DBIx::Admin::DSNManager',
	license        => 'artistic',
	dist_abstract  => 'Manage a file of DSNs, for both testing and production',
	dist_author    => 'Ron Savage <ron@savage.net.au>',
	build_requires =>
	{
		Test::More => 0.96,
		Test::Pod  => 1.41,
	},
	requires =>
	{
		common::sense    => 3.3,
		Config::Tiny     => 2.12,
		DBI              => 1.612,
		File::HomeDir    => 0.93,
		File::Slurp      => 9999.13,
		File::Spec       => 3.31,
		File::Temp       => 0.22,
		Hash::FieldHash  => 0.1,
		Try::Tiny        => 0.06,
	},
) -> create_build_script();
