#!/usr/bin/env perl

#
# Copyright (c) 2003-2006 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#


    use strict;
    use File::Basename;
    use File::Spec;
    use File::Copy;
    use File::Path;
    use Getopt::Long::Descriptive;
    use XML::Writer;

    # We need to look inside the FIG_Config even though it is loaded at
    # run-time, so we will get lots of warnings about one-time variables.
    no warnings qw(once);

    ## THIS CONSTANT DEFINES THE CORE MODULES
    use constant CORE => qw(utils ERDB kernel);

=head1 Generate SEEDtk Configuration Files

    Config [ options ] dataDirectory webDirectory

This method generates (or re-generates) the L<FIG_Config> and B<UConfig.sh> files for a
SEEDtk environment.

=head2 Parameters

The positional parameters are the location of the data folder and the location
of the web folder (see L<ReadMe> for more information about SEEDtk folders). If a
B<FIG_Config> file already exists, this information is not needed-- the existing values
will be used.

The command-line options are as follows.

=over 4

=item fc

If specified, the name of the B<FIG_Config> file for the output. If the name is specified
without a path, it will be put in the project directory's C<config> folder. If C<off>,
no B<FIG_Config> file will be written.

=item clear

If specified, the current B<FIG_Config> values will be ignored, and the configuration information will
be generated from scratch.

=item links

If specified, a prototype C<Links.html> file will be generated in the web directory if one does not
already exist.

=item dirs

If specified, the default data and web subdirectories will be set up.

=item dna

If specified, the location for the DNA repository. If you are using a shared database, then
this insures you are using the same repository as everyone else.

=item eclipse

If this is an eclipse environment, the name of the project cloned from the main SEEDtk/seedtk
project (that is, the name of the I<project directory project>).

=item gfw

If this is specified, then it is presumed you have GitHub for Windows installed. Its copy of
GIT will be added to your path in the C<user-env> script.

=back

=head2 Notes for Programmers

To add a new L<FIG_Config> parameter, simply add a call to L<Env/WriteParam> to the
L</WriteAllParams> method.


=cut

    $| = 1; # Prevent buffering on STDOUT.
    print "Retrieving current configuration.\n";
    # Get the base directory. For Unix, this is the project
    # directory. For Eclipse, this is the project directory's
    # parent. We will also figure out the eclipse mode here.
    my ($base_dir, $eclipseMode);
    if ($ENV{KB_TOP}) {
        # Here we are in a Unix setup. The base directory has been
        # stored in the environment.
        $base_dir = $ENV{KB_TOP};
    } else {
        # Get the directory this script is running in.
        $base_dir = dirname(File::Spec->rel2abs(__FILE__));
        # Fix Windows slash craziness.
        $base_dir =~ tr/\\/\//;
        # Chop off the project part of the path.
        unless ($base_dir =~ /(.+)\/utils\/scripts$/) {
            die "Directory structure is incompatible with Eclipse setup. Project must be named \"utils\".";
        } else {
            # Save the base directory.
            $base_dir = $1;
            # Denote this is Eclipse mode.
            $eclipseMode = 1;
            # Activate the include directory for the "Env" module.
            unshift @INC, "$base_dir/utils/lib";
        }
    }
    # Load the environment library.
    require Env;
    # Determine the operating system.
    my $winMode = ($^O =~ /Win/ ? 1 : 0);
    # Analyze the command line.
    my ($opt, $usage) = describe_options('%o %c dataRootDirectory webRootDirectory',
            ["clear|c", "ignore current configuration values"],
            ["fc=s", "name of a file to use for the FIG_Config output, or \"off\" to turn off FIG_Config output",
                    { default => "FIG_Config.pm" }],
            ["dirs", "verify default subdirectories exist"],
            ["dna=s", "location of the DNA repository (if other than local)"],
            ["links", "generate Links.html file"],
            ["gfw", "add GitHub for Windows GIT to the path (Windows only)"],
            ["eclipse=s", "if specified, then we will set up for Eclipse; the value must be the base name of the project directory project"]
            );
    print "Analyzing directories.\n";
    # The root directories will be put in here.
    my ($dataRootDir, $webRootDir) = ('', '');
    # This points to the project directory project.
    my $projDir = ($eclipseMode ? join("/", $base_dir, $opt->eclipse) : $base_dir);
    if (! -d "$projDir/config") {
        die "Project directory not found in $projDir.";
    }
    # Get the name of the real FIG_Config file (not the output file,
    # if one was specified, the real one).
    my $fig_config_name = "$projDir/config/FIG_Config.pm";
    # Now we want to get the current environment. If the CLEAR option is
    # specified or there is no file present, we stay blank; otherwise, we
    # load the existing FIG_Config.
    if (! $opt->clear && -f $fig_config_name) {
        RunFigConfig($fig_config_name);
    }
    # Insure the list of modules includes the cores. If they are not
    # present, we add them to the front of the list.
    for my $module (CORE) {
        if (! grep { $_ eq $module } @FIG_Config::modules) {
            unshift @FIG_Config::modules, $module;
        }
    }
    # This hash will map each module to its directory.
    my %modules;
    for my $module (@FIG_Config::modules) {
        # Compute the directory name depending on the mode.
        my $dir = ($eclipseMode ? "$base_dir/$module" : "$projDir/modules/$module");
        # Make sure it exists.
        if (! -d $dir) {
            die "Could not find expected module directory $dir.";
        }
        # Add it to the hash.
        $modules{$module} = $dir;
    }
    # Make sure we have the data directory if there is no data root
    # in the command-line parameters.
    if (! defined $FIG_Config::shrub_dir) {
        $dataRootDir = FixPath($ARGV[0]);
        if (! defined $dataRootDir) {
            die "A data root directory is required if no current value exists in FIG_Config.";
        } elsif (! -d $dataRootDir) {
            die "The specified data root directory $dataRootDir was not found.";
        }
    }
    # Make sure we have the web directory if there is no web root in
    # the command-line parameters.
    if (! defined $FIG_Config::web_dir) {
        $webRootDir = FixPath($ARGV[1]);
        if (! defined $webRootDir) {
            die "A web root directory is required if no current value exists in FIG_Config.";
        } elsif (! -d $webRootDir) {
            die "The specified web root directory $webRootDir was not found.";
        }
    }
    #If the FIG_Config write has NOT been turned off, then write the FIG_Config.
    if ($opt->fc eq 'off') {
        print "FIG_Config output suppressed.\n";
    } else {
        # Compute the FIG_Config file name.
        my $outputName = $opt->fc;
        # Fix the slash craziness for Windows.
        $outputName =~ tr/\\/\//;
        # If the name is pathless, put it in the config directory.
        if ($outputName !~ /\//) {
            $outputName = "$projDir/config/$outputName";
        }
        # If we are overwriting the real FIG_Config, back it up.
        if (-f $fig_config_name && $outputName eq $fig_config_name) {
            print "Backing up $fig_config_name.\n";
            copy $fig_config_name, "$projDir/config/FIG_Config_old.pm";
        }
        # Write the FIG_Config.
        print "Writing configuration to $outputName.\n";
        WriteAllParams($outputName, \%modules, $projDir, $dataRootDir, $webRootDir, $winMode, $opt);
        # Execute it to get the latest variable values.
        print "Reading back new configuration.\n";
        RunFigConfig($outputName);
    }
    # Are we setting up default data directories?
    if ($opt->dirs) {
        # Yes. Insure we have the data paths.
        BuildPaths($winMode, Data => $FIG_Config::shrub_dir, qw(Inputs Inputs/GenomeData Inputs/SubSystemData LoadFiles));
        # Are we using a local DNA repository?
        if (! $opt->dna) {
            # Yes. Build that, too.
            BuildPaths($winMode, Data => $FIG_Config::shrub_dir, qw(DnaRepo));
        }
        # Insure we have the web paths.
        BuildPaths($winMode, Web => $FIG_Config::web_dir, qw(img Tmp logs));
    }
    # Do we have a Web project?
    my $weblib = "$FIG_Config::web_dir/lib";
    if (-d $weblib) {
        # Yes. Create the web configuration file.
        my $webConfig = "$weblib/Web_Config.pm";
        # Open the web configuration file for output.
        if (! open(my $oh, ">$webConfig")) {
            # Web system problems are considered warnings, not fatal errors.
            warn "Could not open web configuration file $webConfig: $!\n";
        } else {
            # Write the file.
            print $oh "\n";
            print $oh "    use lib\n";
            print $oh "        '" .	join("',\n        '", @FIG_Config::libs) . "';\n";
            print $oh "\n";
            print $oh "    use FIG_Config;\n";
            print $oh "\n";
            print $oh "1;\n";
            # Close the file.
            close $oh;
            print "Web configuration file $webConfig created.\n";
        }
    }
    # If this is Eclipse mode, we need to set up the PERL libraries and
    # execution paths.
    if ($eclipseMode) {
        # Set up the paths and PERL libraries.
        WriteAllConfigs($winMode, \%modules, $projDir, $opt);
        if (! $winMode) {
            # For an Eclipse Mac installation, we have to set up binary versions of the scripts
            # and make the
            SetupBinaries($projDir, \%modules, $opt);
            # We also need to fix the CGI permissions.
            SetupCGIs($FIG_Config::web_dir, $opt);
        }
    }
    # Now we need to create the pull-all script.
    my $fileName = "$projDir/pull-all" . ($FIG_Config::win_mode ? ".cmd" : ".sh");
    open(my $oh, ">$fileName") || die "Could not open $fileName: $!";
    # The pushd command in windows can't handle forward slashes in directory names,
    # so if this is windows we have to translate.
    my $projDirForPush = $projDir;
    if ($winMode) {
        $projDirForPush =~ tr/\//\\/;
    }
    # Now write the commands to run through the directories and pull.
    print $oh "echo Pulling project directory.\n";
    print $oh "pushd $projDirForPush\n";
    print $oh "git pull\n";
    for my $module (@FIG_Config::modules) {
        print $oh "echo Pulling $module\n";
        print $oh "cd $modules{$module}\n";
        print $oh "git pull\n";
    }
    # Restore the old directory.
    print $oh "popd\n";
    close $oh;
    print "Pull-all script written to $fileName.\n";
    # Finally, check for the links file.
    if ($opt->links) {
        # Determine the output location for the links file.
        my $linksDest = "$FIG_Config::web_dir/Links.html";
        # Do we need to generate a links file?
        if (-f $linksDest) {
            # No need. We already have one.
            print "$linksDest file already exists-- not updated.\n";
        } else {
            # We don't have a links file yet.
            print "Generating new $linksDest.\n";
            # Find the source copy of the file.
            my $linksSrc = "$FIG_Config::web_dir/lib/Links.html";
            # Copy it to the destination.
            copy $linksSrc, $linksDest;
            print "$linksDest file created.\n";
        }
    }
    print "All done.\n";


=head2 Internal Subroutines

=head3 RunFigConfig

    RunFigConfig($fileName);

Execute the L<FIG_Config> module. This uses the PERL C<do> function, which
unlike C<require> can execute a module more than once, but requires error
checking. The error checking is done by this method.

=over 4

=item fileName

The name of the B<FIG_Config> file to load.

=back

=cut

sub RunFigConfig {
    # Get the parameters.
    my ($fileName) = @_;
    # Execute the FIG_Config;
    do $fileName;
    if ($@) {
        # An error occurred compiling the module.
        die "Error compiling FIG_Config: $@";
    } elsif ($!) {
        # An error occurred reading the module.
        die "Error reading FIG_Config: $!";
    }
}

=head3 WriteAllParams

    WriteAllParams($fig_config_name, \%modules, $projDir, $dataRootDir,
            $webRootDir, $winMode, $opt);

Write out the B<FIG_Config> file to the specified location. This method
is mostly calls to the L</WriteParam> method, which provides a concise
way of writing parameters to the file and checking for pre-existing
values. It is presumed that L</RunFigConfig> has been executed first so
that the existing values are known.

=over 4

=item fig_config_name

File name for the B<FIG_Config> file. The parameter code will be written to
this file.

=item modules

Reference to a hash mapping each module name to its directory.

=item projDir

Name of the project directory.

=item dataRootDir

Location of the base directory for the data files.

=item webRootDir

Location of the base directory for the web files.

=item winMode

TRUE for Windows, FALSE for Unix/Mac.

=item opt

Command-line options object.

=back

=cut

sub WriteAllParams {
    # Get the parameters.
    my ($fig_config_name, $modules, $projDir, $dataRootDir, $webRootDir, $winMode, $opt) = @_;
    # Open the FIG_Config for output.
    open(my $oh, ">$fig_config_name") || die "Could not open $fig_config_name: $!";
    # Write the initial lines.
    print $oh "package FIG_Config;\n";
    Env::WriteLines($oh,
        "",
        "## WHEN YOU ADD ITEMS TO THIS FILE, BE SURE TO UPDATE kernel/scripts/Config.pl.",
        "## All paths should be absolute, not relative.",
        "");
    # Write each parameter.
    Env::WriteParam($oh, 'root directory of the local web server', web_dir => $webRootDir);
    Env::WriteParam($oh, 'directory for temporary files', temp => "$webRootDir/Tmp");
    Env::WriteParam($oh, 'URL for the directory of temporary files', temp_url => 'http://fig.localhost/Tmp');
    Env::WriteParam($oh, 'TRUE for windows mode', win_mode => ($winMode ? 1 : 0));
    Env::WriteParam($oh, 'source code project directory', proj => $projDir);
    ## Put new non-Shrub parameters here.
    # Now we need to build our directory lists.
    my @scripts = map { "$modules->{$_}/scripts" } @FIG_Config::modules;
    my @libs = map { "$modules->{$_}/lib" } @FIG_Config::modules;
    Env::WriteLines($oh, "", "# list of script directories",
            "our \@scripts = ('" . join("', '", @scripts) . "');",
            "",  "# list of PERL libraries",
            "our \@libs = ('" . join("', '", "$projDir/config", @libs) . "');",
            "", "# list of project modules",
            "our \@modules = qw(" . join(" ", @FIG_Config::modules) . ");",
            );
    # Now comes the Shrub configuration section.
    Env::WriteLines($oh, "", "", "# SHRUB CONFIGURATION", "");
    Env::WriteParam($oh, 'root directory for Shrub data files (should have subdirectories "Inputs" (optional) and "LoadFiles" (required))',
            shrub_dir => "$dataRootDir");
    Env::WriteParam($oh, 'full name of the Shrub DBD XML file', shrub_dbd => "$modules->{ERDB}/ShrubDBD.xml");
    Env::WriteParam($oh, 'Shrub database signon info (name/password)', userData => "seed/");
    Env::WriteParam($oh, 'name of the Shrub database (empty string to use the default)', shrubDB => "");
    Env::WriteParam($oh, 'TRUE if we should create indexes before a table load (generally TRUE for MySQL, FALSE for PostGres)',
            preIndex => 1);
    Env::WriteParam($oh, 'default DBMS (currently only "mysql" works for sure)', dbms => "mysql");
    Env::WriteParam($oh, 'database access port', dbport => 3306);
    Env::WriteParam($oh, 'TRUE if we are using an old version of MySQL (legacy parameter; may go away)', mysql_v3 => 0);
    Env::WriteParam($oh, 'default MySQL storage engine', default_mysql_engine => "InnoDB");
    Env::WriteParam($oh, 'database host server (empty string to use the default)', dbhost => "");
    Env::WriteParam($oh, 'TRUE to turn off size estimates during table creation-- should be FALSE for MyISAM',
            disable_dbkernel_size_estimates => 1);
    Env::WriteParam($oh, 'mode for LOAD TABLE INFILE statements, empty string is OK except in special cases (legacy parameter; may go away)',
            load_mode => '');
    # Now comes the DNA repository. There are two cases-- a local repository or a global one. Check the type.
    my $dnaRepo = $opt->dna;
    if (! $dnaRepo) {
        # Here we have the local repository.
        $dnaRepo = "$dataRootDir/DnaRepo";
    }
    Env::WriteParam($oh, 'location of the DNA repository', shrub_dna => $dnaRepo);
    ## Put new Shrub parameters here.
    if ($opt->eclipse && $winMode) {
        # For a Windows Eclipse project, we need to convince FIG_Config to modify the path.
        my $newPath = Env::BuildPathList($winMode, ';', @scripts);
        my $newPathLen = length($newPath);
        # Now we have the text and length of the new path string. Escape any backslashes
        # in the path string and convert it to a quoted string.
        $newPath =~ s/\\/\\\\/g;
        $newPath = '"' . $newPath . '"';
        # Append the code to fix the path.
        Env::WriteLines($oh, "",
            "# Insure the path has our scripts in it.",
            "my \$newPath = $newPath;",
            "if (substr(\$ENV{PATH}, 0, $newPathLen) ne \$newPath) {",
            "    \$ENV{PATH} = \"\$newPath;\$ENV{PATH}\";",
            "}");
    }

    # Write the trailer.
    print $oh "\n1;\n";
    # Close the output file.
    close $oh;
}


=head3 WriteAllConfigs

    WriteAllConfigs($winMode, \%modules, $projDir, $opt);

Write out the path and library configuration parameters for an
Eclipse environment. This creates a C<user-env> file in the
project directory and builds the C<.includepath> files for all
the Eclipse projects. The C<user-env.sh> file is used in a
command shel to set up environment variables for PERL includes and
execution paths.

This method presumes the B<FIG_Config> file has been updated and L</RunFigConfig> has
been called to load its variables.

=over 4

=item winMode

TRUE if we are in Windows, else FALSE.

=item modules

Reference to a hash mapping each module name to its directory on
disk.

=item projDir

Name of the project directory.

=item opt

Command-line options object.

=back

=cut

sub WriteAllConfigs {
    # Get the parameters.
    my ($winMode, $modules, $projDir, $opt) = @_;
    # Compute the output file, the comment mark, and the path delimiter.
    my $fileName = "$projDir/user-env.";
    my ($delim, $rem);
    if ($winMode) {
        $fileName .= "cmd";
        $delim = ";";
        $rem = "REM ";
    } else {
        $fileName .= "sh";
        $delim = ":";
        $rem = "#";
    }
    # Open the output file.
    open(my $oh, ">$fileName") || die "Could not open shell configuration file $fileName: $!";
    # Do an ECHO OFF for Windows.
    if ($winMode) {
        print $oh "\@ECHO OFF\n";
    }
    print "Writing environment changes to $fileName.\n";
    #
    # Compute the script paths.
    my $paths = join($delim, @FIG_Config::scripts);
    # Write the comment.
    print $oh "$rem Add SEEDtk scripts to the execution path.\n";
    # Do the path update.
    if ($winMode) {
        # In Windows it's complicated, because variables at the command prompt are
        # double-interpolated and we can't use them safely. We have to use an
        # explicit path-- the current environment has the path we need already in it.
        $paths = "$ENV{PATH}";
        $paths =~ s/&/^&/g;
        # Check for the GitHub for Windows option.
        if ($opt->gfw) {
            $paths .= ';%localappdata%\GitHub\PORTAB~1\cmd'
        }
        print $oh "path $paths\n";
    } else {
        # On the Mac, we simply put the bin subdirectory in the path.
        print $oh "export PATH=$projDir/bin:\$PATH\n";
    }
    # Set the PERL libraries.
    my $libs = join($delim, @FIG_Config::libs);
    print $oh "$rem Add SEEDtk libraries to the PERL library path.\n";
    if ($ENV{PERL5LIB}) {
        # There are already libraries, so set this up as an append operation.
        $libs .= ($winMode ? ';%PERL5LIB%' : ':$PERL5LIB');
    }
    if ($winMode) {
        print $oh "SET PERL5LIB=$libs\n";
    } else {
        print $oh "export PERL5LIB=$libs\n";
    }
    # The libraries and the path are now set up.
    if ($winMode && $ENV{PATHEXT} !~ /.pl(?:;|$)/i) {
        # Here we are in Windows and PERL scripts are not set up as
        # an executable type. We need to fix that.
        print $oh "SET PATHEXT=%PATHEXT%;.PL\n"
    }
    # Close the output file.
    close $oh;
    # If this is NOT Windows, fix the permissions.
    if (! $winMode) {
        chmod 0755, $fileName;
    }
    # Now we need to create the includepath file. This is an XML file that has
    # to appear in every project directory. First, we create the text of the file.
    my $xmlOut = XML::Writer->new(OUTPUT => 'self', NEWLINES => 1);
    $xmlOut->xmlDecl("UTF-8");
    # The main tag enclosing all others is "includepath".
    $xmlOut->startTag("includepath");
    # Loop through the paths, generating includepathentry tags.
    for my $path (@FIG_Config::libs) {
        $xmlOut->emptyTag('includepathentry', path => File::Spec->rel2abs($path));
    }
    # Close the main tag.
    $xmlOut->endTag("includepath");
    # Close the document.
    $xmlOut->end();
    # Get the document text.
    my $xmlDoc = $xmlOut->to_string();
    # Now loop through the modules, writing out the xml.
    for my $module (keys %$modules) {
        open(my $mh, ">$modules->{$module}/.includepath") || die "Could not open Eclipse includepath file for $module: $!";
        print $mh $xmlDoc;
        close $mh;
    }
}



=head3 BuildPaths

    BuildPaths($winmode, $label => $rootDir, @subdirs);

Create the desired subdirectories for the specified root directory. The
type of root directory is provided as a label for status messages. On
Unix systems, a C<chmod> will be performed to fix the privileges.

=over 4

=item winmode

TRUE for a Windows system, FALSE for a Unix system.

=item label

Label describing the type of directory being created.

=item rootDir

Root directory path. All new paths created will be under this one.

=item subdirs

List of path names, relative to the specified root directory, that we
must insure exist.

=back

=cut

sub BuildPaths {
    # Get the parameters.
    my ($winmode, $label, $rootDir, @subdirs) = @_;
    # Loop through the new paths.
    for my $path (@subdirs) {
        my $newPath = "$rootDir/$path";
        # Check to see if the directory is already there.
        if (! -d $newPath) {
            # No, we must create it.
            File::Path::make_path($newPath);
            print "$label directory $newPath created.\n";
            # If this is Unix, fix the permissions.
            if (! $winmode) {
                chmod 0777, $newPath;
            }
        }
    }
}


=head3 FixPath

    my $absPath = FixPath($path);

Convert a path from relative to absolute, convert backslashes to slashes, and remove the drive letter.
This makes the path suitable for passing around in PERL.

=over 4

=item path

Path to convert.

=item RETURN

Returna an absolute, canonical version of the path.

=back

=cut

sub FixPath {
    # Get the parameters.
    my ($path) = @_;
    # Convert the path to a canonical absolute.
    my $retVal = File::Spec->rel2abs($path);
    # Convert backslashes to slashes.
    $retVal =~ tr/\\/\//;
    # Remove the drive letter (if any).
    $retVal =~ s/^\w://;
    # Return the result.
    return $retVal;
}


=head3 SetupBinaries

    SetupBinaries($projDir, \%modules, $opt);

Create the bin directory (if needed) and insure all the scripts have
executable wrappers. This is only needed for the Eclipse environment on
the Mac. Wrappers are unnecessary in Windows, and a different mechanism
exists for the wrappers in pure Unix.

=over 4

=item projDir

The path to the project directory. The C<bin> directory is put in here.

=item modules

Reference to a hash that maps each module name to its directory. The
scripts are all in the C<scripts> subdirectories of the module
directories.

=item opt

The command-line options from the configuration script.

=back

=cut

sub SetupBinaries {
    # Get the parameters.
    my ($projDir, $modules, $opt) = @_;
    # Insure we have a bin directory.
    my $binDir = "$projDir/bin";
    if (! -d $binDir) {
        File::Path::make_path($binDir);
        print "$binDir created.\n";
    }
    # Loop through the modules.
    for my $module (keys %$modules) {
        # Get the scripts for this module.
        my $scriptDir = "$modules->{$module}/scripts";
        opendir(my $dh, $scriptDir) || die "Could not open script directory $scriptDir.";
        my @scripts = grep { substr($_, -3, 3) eq '.pl' } readdir($dh);
        closedir $dh;
        # Loop through them, creating the wrappers.
        for my $script (@scripts) {
            # Get the unsuffixed script name.
            my $binaryName = substr($script, 0, -3);
            # Create the wrapper file.
            my $fileName = "$binDir/$binaryName";
            open(my $oh, ">$fileName") || die "Could not open $binaryName: $!";
            print $oh "#!/usr/bin/env bash\n";
            print $oh "perl $scriptDir/$script \"\$\@\"\n";
            close $oh;
            # Turn on the execution bits.
            my @finfo = stat $fileName;
            my $newMode = ($finfo[2] & 0777) | 0111;
            chmod $newMode, $fileName;
        }
    }
}

=head3 SetupCGIs

    SetupCGIs($webdir, $opt);

Fix the permissions on the CGI scripts. This is only needed for the Eclipse
environment on the Mac.

=over 4

=item webdir

The path to the web directory. The CGI scripts are in this directory.

=item opt

The command-line options from the configuration script.

=back

=cut

sub SetupCGIs {
    # Get the parameters.
    my ($webdir, $opt) = @_;
    # Only proceed if we have a web directory.
    if (-d $webdir) {
        # Get the CGI scripts.
        opendir(my $dh, $webdir) || die "Could not open web directory $webdir.";
        my @scripts = grep { substr($_, -4, 4) eq '.cgi' } readdir($dh);
        closedir $dh;
        # Loop through them, setting permissions.
        for my $script (@scripts) {
            # Compute the file name.
            my $fileName = "$webdir/$script";
            # Turn on the execution bits.
            my @finfo = stat $fileName;
            my $newMode = ($finfo[2] & 0777) | 0111;
            chmod $newMode, $fileName;
        }
        print "CGI permissions set.\n";
    }
}
