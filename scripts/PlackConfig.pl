#!/usr/bin/env perl
#
# Copyright (c) 2003-2015 University of Chicago and Fellowship
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
use warnings;
use FIG_Config;
use ScriptUtils;
use Cwd;

=head1 Fix Up Plack Server

    PlackConfig.pl [ options ]

This script updates the Plack server.  The latest code is pulled from GitHub, and the Web_Config is replaced.

=head2 Parameters

There are currently no parameters.

=cut

$| = 1;
# Get the command-line parameters.
my $opt = ScriptUtils::Opts('');
# Refresh the source files.
RefreshFiles("Plack");
# Create the Web_Config.
print "Building web_config.\n";
open(my $oh, '>', "$FIG_Config::mod_base/Plack/psgi/lib/Web_Config.pm") || die "Could not open Web_Config: $!";
print $oh "package Web_Config;\n";
print $oh "## DO NOT MODIFY THIS FILE: It is generated automatically by PlackConfig.pl.\n\n";
print $oh "# base directory for all web modules\n";
print $oh "our \$mod_base = \"$FIG_Config::mod_base/Plack\";\n\n";
print $oh "# base directory for all jar files\n";
print $oh "our \$java_base = \"$FIG_Config::mod_base/kernel/jars\";\n\n";
print $oh "# Initial portion of java command\n";
print $oh "our \@java_cmd = ('java', \"-Dlogback.configurationFile=\$java_base/weblogback.xml\", \"-jar\");\n\n";
print $oh "# CoreSEED data directory\n";
print $oh "our \$core_base = \"$FIG_Config::data/CoreSEED\";\n\n";
print $oh "# log file name\n";
print $oh "our \$log_file = \"$FIG_Config::data/logs/plack.log\";\n\n";
close $oh;
print "All done.\n";

## This refreshes the source files from GIT.
sub RefreshFiles {
    my ($dir) = @_;
    # Save the current directory.
    my $saveDir = cwd();
    # Insure the directory exists.
    my $repoDir = "$FIG_Config::mod_base/$dir";
    if (! -d "$repoDir") {
        # Directory not found, clone it.
        print "Creating $dir repo.\n";
        chdir $dir;
        my @output = `git clone https://github.com/SEEDtk/$dir.git`;
        if (grep { $_ =~ /fatal:\s+(.+)/ } @output) {
            die "Error retrieving $dir source: $1";
        }
    } elsif (! -d "$repoDir/.git") {
        # Directory is a copy. Skip it.
        print "$dir repo is a copy.\n";
    } else {
        # Directory found, refresh it.
        print "Pulling $dir repo.\n";
        chdir $repoDir;
        my @output = `git pull`;
        if (grep { $_ =~ /conflict/ } @output) {
            die "$dir pull failed.";
        }
    }
    # Restore the directory.
    chdir $saveDir;
}
