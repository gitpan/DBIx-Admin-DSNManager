package DBIx::Admin::DSNManager;

use common::sense;
use warnings 'uninitialized';

use Config::Tiny;

use File::HomeDir; # For my_dist_config().
use File::Slurp;   # For write_file.
use File::Spec;    # For catdir().

use Hash::FieldHash ':all';

use Try::Tiny;

fieldhash my %active          => 'active';
fieldhash my %attributes      => 'attributes';
fieldhash my %config          => 'config';
fieldhash my %file_name       => 'file_name';
fieldhash my %password        => 'password';
fieldhash my %use_for_testing => 'use_for_testing';
fieldhash my %username        => 'username';
fieldhash my %verbose         => 'verbose';

our $errstr  = '';
our $VERSION = '1.00';

# -----------------------------------------------

sub hashref2string
{
	my($self, $h) = @_;
	$h ||= {};

	return '{' . join(', ', map{"$_ => $$h{$_}"} sort keys %$h) . '}';

} # End of hashref2string.

# -----------------------------------------------

sub init
{
	my($self, $arg)        = @_;
	$$arg{active}          ||= 0;
	$$arg{attributes}      ||= {AutoCommit => 1, PrintError => 0, RaiseError => 1};
	$$arg{config}          ||= undef;
	$$arg{file_name}       ||= '';
	$$arg{password}        ||= '';
	$$arg{use_for_testing} ||= 0;
	$$arg{username}        ||= '';
	$$arg{verbose}         ||= 0;

} # End of init.

# -----------------------------------------------

sub _keys
{
	my($self) = @_;

	return (qw/dsn username password attributes active use_for_testing/);

} # End of _keys.

# -----------------------------------------------

sub _log
{
	my($self, $s) = @_;
	$s ||= '';

	# The leading hash fits in with 'diag' during testing.

	if ($self -> verbose)
	{
		print STDERR "# $s\n";
	}

} # End of _log.

# -----------------------------------------------

sub new
{
	my($class, %arg) = @_;

	$class -> init(\%arg);

	my($self);

	try
	{
		$self  = from_hash(bless({}, $class), \%arg);

		# Initialize file_name here and not in init(), so that if it dies, we catch it.

		if (! $self -> file_name)
		{
			$self -> file_name
			(
				File::Spec -> catdir
				(
					File::HomeDir -> my_dist_config('DBIx-Admin-DSNManager', {create => 1}), 'dsn.ini'
				)
			);
		}

		if (! $self -> config)
		{
			$self -> read($self -> file_name);
		}

		# We save the result of $self -> validate
		# because it incorporates the default values.

		$self -> config($self -> validate);
	}
	catch
	{
		$errstr = $_;
		$self   = undef;
	};

	return $self;

} # End of new.

# -----------------------------------------------

sub read
{
	my($self, $file_name) = @_;

	$self -> _log("Reading: $file_name");

	my($config) = Config::Tiny -> read($file_name) || die $Config::Tiny::errstr;
	$config     = {%$config};

	# For each DSN, we have to convert the attributes from a string to a hashref.

	for my $section (keys %$config)
	{
		$$config{$section}{attributes} = $self -> string2hashref($$config{$section}{attributes});
	}

	$self -> config($config);

} # End of read.

# -----------------------------------------------

sub report
{
	my($self, $config) = @_;

	if (! $config)
	{
		$self -> _log("File: " . $self -> file_name);
	}

	$config ||= $self -> config;

	my($attr);

	for my $section (sort keys %$config)
	{
		$self -> _log("Section: $section");

		for my $key ($self -> _keys)
		{
			if ($key eq 'attributes')
			{
				$attr = $$config{$section}{$key};

				$self -> _log("$key: " . join(', ', map{"$_ => $$attr{$_}"} sort keys %$attr) );
			}
			else
			{
				$self -> _log("$key: $$config{$section}{$key}");
			}
		}

		$self -> _log;
	}

} # End of report.

# -----------------------------------------------

sub string2hashref
{
	my($self, $s) = @_;
	$s            ||= '';
	my($result)   = {};

	if ($s)
	{
		if ($s =~ m/^\{\s*([^}]*)\}$/)
		{
			my(@attr) = map{split(/\s*=>\s*/)} split(/\s*,\s*/, $1);

			if (@attr)
			{
				$result = {@attr};
			}
		}
		else
		{
			die "Invalid syntax for hashref: $s";
		}
	}

	return $result;

} # End of string2hashref.

# -----------------------------------------------

sub validate
{
	my($self, $config) = @_;
	$config ||= $self -> config;

	if (! $config || (ref($config) ne 'HASH') )
	{
		die 'You must use new(config => {...}) or new(file_name => $name) or $object -> config({...})';
	}

	my($count) = 0;

	for my $section (sort keys %$config)
	{
		$count++;

		for my $key ($self -> _keys)
		{
			# The dns key is mandatory.

			if ($key eq 'dsn')
			{
				if ($$config{$section}{$key})
				{
					next;
				}
				else
				{
					die "Section $section has no value for the 'dsn' key";
				}
			}

			# If not set, use the default.

			if (! $$config{$section}{$key})
			{
				$$config{$section}{$key} = $self -> $key;
			}
		}
	}

	if ($count == 0)
	{
		die "No sections found";
	}

	return $config;

} # End of validate.

# -----------------------------------------------

sub write
{
	my($self, $file_name, $config) = @_;

	# Allow calls of the form $object -> write({...}).

	if (ref($file_name) eq 'HASH')
	{
		$config    = $file_name;
		$file_name = $self -> file_name;
	}
	else
	{
		# Allow calls of the form $object -> write($file_name) and write($file_name, {...}).

		$config ||= $self -> config;
	}

	$self -> _log("Writing: $file_name");

	my(@line);
	my($s);

	for my $section (sort keys %$config)
	{
		push @line, "[$section]";

		for my $key ($self -> _keys)
		{
			$s = $$config{$section}{$key};

			# For each DSN, we have to convert the attributes from a hashref to a string.

			if ($key eq 'attributes')
			{
				$s = $self -> hashref2string($s);
			}

			push @line, "$key = $s";
		}

		push @line, '';
	}

	write_file($file_name, map{"$_\n"} @line);

} # End of write.

# -----------------------------------------------

1;

=pod

=head1 NAME

L<DBIx::Admin::DSNManager> - Manage a file of DSNs, for both testing and production

=head1 Synopsis

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

See scripts/synopsis.pl.

=head1 Description

L<DBIx::Admin::DSNManager> manages a file of DSNs, for both testing and production.

The default directory and file name ('dsn.ini') are discussed in L</Method: new()>, under file_name.

The INI-style format was selected, rather than, say, using an SQLite database, so that casual users could edit
the file without needing to know SQL and without having to install the command line program sqlite3.

Each DSN is normally for something requiring manual preparation, such as creating the database named in the DSN.

In the case of SQLite, etc, where manual intervention is not required, you can still put the DSN in
dsn.ini.

One major use of this module is to avoid environment variable overload, since it's common to test Perl modules
by setting the env vars $DBI_DSN, $DBI_USER and $DBI_PASS.

But then the problem becomes: What do you do when you want to run tests against a set of databases servers?
Some modules define sets of env vars, one set per database server, with awkward and hard-to-guess names.
This is messy and obscure.

L<DBIx::Admin::DSNManager> is a solution to this problem.

=head1 Database Creation

By design, L<DBIx::Admin::DSNManager> does not provide a create-database option.

For database servers like Postgres, MySQL, etc, you must create users, and give them the createdb privilege.
Such actions are outside the scope of this module.

For database servers like SQLite, any code can create a database anyway, but you can use options in dsn.ini
to indicate the DSN is inactive, or not to be used for testing. See L</The Format of dsn.ini> below.

=head1 Testing 'v' Production

Of course, you may have DSNs in dsn.ini which you don't want to be used for testing.

Here's a policy for handling such situations:

=over 4

=item o An explicit use_for_testing flag

Each DSN in the file can be marked with the option 'use_for_testing = 0', to stop usage for testing,
or 'use_for_testing = 1', to allow usage for testing.

The default is 0 - do not use for testing.

=item o An implicit DSN

For cases like SQLite, testing code can either look in dsn.ini, or manufacture a temporary directory and file name
for testing.

This leads to a new question: If the testing code finds a DSN in dsn.ini which is marked use_for_testing = 0,
should that code still generate another DSN for testing? My suggestions is: Yes, since the one in dsn.ini does
not indicate that all possible DSNs should be blocked from testing.

=back

=head1 The Format of dsn.ini

On disk, dsn.ini is a typical INI-style file. In RAM it is a hashref of config options. E.g.:

	config => {'Pg.1' => {dsn => 'dbi:Pg:dbname=test', ...}, 'Pg.2' => {...} }

where config is the name of this module's getter/setter which provides access to the hashref.

=over 4

=item o Sections

Section names are unique, case-sensitive, strings.

So 2 Postgres sections might be:

	[Pg.1]
	...

	[Pg.2]
	...

=item o Connexion info within each section

Each section can have these keys:

=over 4

=item o A DSN string

A typical Postgres dsn would be:

dsn = dbi:Pg:dbname=test

A dsn key is mandatory within each section.

The DSN names the driver to use and the database.

=item o A Username string

E.g.: username = testuser

A username is optional.

If a username is not provided for a dsn, the empty string is used.

=item o A Password string

E.g.: password = testpass

A password is optional.

If a password is not provided for a dsn, the empty string is used.

=item o DSN Attributes as a hashref

E.g.:

attributes = {AutoCommit => 1, PrintError => 0, RaiseError = 1}

Attributes are optional.

Their format is exactly the same as for L<DBI>.

If attributes are not provided, they default to the example above.

=item o A Boolean active flag

E.g.: active = 0

or active = 1

The active key is optional.

If the active key is not provided for a dsn, it defaults to 0 - do not use.

This key means you can easily disable a DSN without having to delete the section, or comment it all out.

=item o A Boolean testing flag

E.g.: use_for_testing = 0

or use_for_testing = 1

The use_for_testing key is optional.

If the use_for_testing key is not provided for a dsn, it defaults to 0 - do not use for testing.

=back

=back

So, a sample dsn.ini file looks like:

	[Pg.1]
	dsn=dbi:Pg:dbname=test1
	username=user1
	password=pass1
	attributes = {AutoCommit => 1, PrintError => 0, RaiseError => 1}
	use_for_testing = 0

	[Pg.2]
	dsn=dbi:Pg:dbname=test2
	username=user2
	password=pass2
	active = 0
	use_for_testing = 1

	[SQLite.1]
	dsn=dbi:SQLite:dbname=/tmp/test.module.sqlite

This file is read by L<Config::Tiny>. Check its docs for details, but there is one thing to be aware of:
L<Config::Tiny> does not recognize comments at the ends of lines. So:

key = value # A comment.

sets key to 'value # A comment.', which is probably not what was meant.

=head1 Method: new()

Calling C<new()> returns a object of type L<DBIx::Admin::DSNManager>, or - if C<new()> fails - it returns undef.
For details see L</Trouble with Errors>.

C<new()> takes a hash of key/value pairs, some of which might mandatory. Further, some combinations
might be mandatory.

The keys are listed here in alphabetical order.

They are lower-case because they are (also) method names, meaning they can be called to set or get the value
at any time.

But a warning: In some cases, setting them after this module has used the previous value, will have no effect.
All such cases are documented (or should be).

=over 4

=item o config => {...}

Specifies a hashref to use as the initial value of the internal config hashref which holds the set of DSNs.

This hashref is keyed by section name, with each key pointing to a hashref of dsn data. E.g.:

	config => {'Pg.1' => {dsn => 'dbi:Pg:dbname=test', ...}, 'Pg.2' => {...} }

=item o file_name => $string

Specifies the name of the file holding the DSNs.

If the $string is an absolute path to a file, it is used as-is.

If it is not absolute, it is assumed to be relative to this module's configuration directory, which is
determined by:

my($config_dir) = File::HomeDir -> my_dist_config('DBIx-Admin-DSNManager', {create => 1});

See L<File::HomeDir> for details.

This key is optional.

The default value is "$config_dir/dsn.ini".

=item o verbose => 0 | 1

Specify more or less output.

The default value is 0.

=back

=head1 Method: config([{...}])

Get or set the internal config hashref holding all the DSN data.

The [] mean the hashref parameter is optional.

If called as config({...}), set the config hashref to the parameter.

If called as config(), return the config hashref.

=head1 Method: hashref2string($hashref)

Returns a string corresponding to the $hashref.

{} is converted to '{}'.

=head1 Method: read($file_name)

Read $file_name using L<Config::Tiny> and set the config hashref.

=head1 Method: report([{...}])

If called as $object -> report, print both $object -> file_name, and the contents of the config hashref, to STDERR.

If called as $object -> report({...}), print just the contents of the hashref to STDERR.

The [] mean the hashref parameter is optional.

=head1 Method: string2hashref($s)

Returns a hashref built from the string, or the empty string.

The string is expected to be something like '{AutoCommit => 1, PrintError => 0}'.

The empty string is returned as {}.

=head1 Method: validate([{...}])

Validate the given or config hashref.

Returns the validated hashref, with defaults filled in.

The [] mean the hashref parameter is optional.

If a hashref is not supplied, validate the config one.

Currently, the checks are:

=over 4

=item o There must be at least 1 section

=item o All sections must have a 'dsn' key

=back

=head1 Method: write([$file_name,][{...}])

Write the given or config hashref to $file_name.

The [] mean a parameter is optional.

If called as $object -> write('dsn.ini'), write the config hashref to $file_name.

If called as $object -> write('dsn.ini', {...}), write the given hashref to $file_name.

If called as $object -> write({...}), write the given hashref to $object -> file_name.

L<File::Slurp> is used to write this file, since these hashes are not of type C<Config::Tiny>.

=head1 Troubleshooting

=head2 Trouble with Errors

When object construction fails, C<new()> sets $DBIx::Admin::DSNManager::errstr and returns undef.
This means you can use this idiom:

	my($dsn_manager) = DBIx::Admin::DSNManager -> new(...) || process_error($DBIx::Admin::DSNManager::errstr);

However, when methods detect errors they die, so after successful object construction, you can do:

	use Try::Tiny;

	try
	{
		$dsn_manager -> some_method_which_may_die;
	}
	catch
	{
		process_error($_); # Because $_ holds the error message.
	};

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Support

Log a bug on RT: L<https://rt.cpan.org/Public/Dist/Display.html?Name=Test-Setup-Database>.

=head1 Author

L<DBIx::Admin::DSNManager> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2010.

Home page: L<http://savage.net.au/index.html>.

=head1 Copyright

Australian copyright (c) 2010, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
