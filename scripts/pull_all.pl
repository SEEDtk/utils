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
    use FIG_Config;
    use warnings;
    use Getopt::Long::Descriptive;

=head1 Pull All Projects from GIT

    pull_all [ options ]

This is a simple script that pulls all the current projects from GIT.

=head2 Parameters

Currently, there are no parameters. This may change.

=cut

# Get the project directory.
my $projDir = $FIG_Config::proj;
# Verify the environment.
if (! -d "$projDir/modules/kernel") {
    die "Improper environment. This appears to be an Eclipse setup.";
}
# This list is used to execute a GIT command.
my @git = qw(git pull);
# Change to the project directory.
chdir $projDir;
my $rc = system(@git);
if ($rc) {
    die "Pull for project directory failed. rc = $rc";
}
# Loop through the modules.
for my $module (@FIG_Config::modules) {
    # Go to this module's directory.
    chdir "$projDir/$module";
    # Pull the source from GIT.
    $rc = system(@git);
    if ($rc) {
        die "Pull for module $module failed. rc = $rc"
    }
}
