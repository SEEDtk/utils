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

=head1 Switch to a GIT Branch

    switch_branch.pl [ options ] branchName

This script switches the project to a different GIT branch. All of the project directories are examined, and if the specified branch exists
there, a git checkout is performed.

Note that this should only be used to switch to a local branch.

=head2 Parameters

The positional parameter is the name of the branch to which the project should be switched.

=cut

# Get the command-line parameters.
my $opt = ScriptUtils::Opts('branchName',
        );
# Get the branch name.
my ($branchName) = @ARGV;
if (! $branchName) {
    die "No branch name specified.";
}
# Get a list of directories.
my @modules = map { "$FIG_Config::mod_base/$_" } @FIG_Config::modules;
push @modules, grep { $_ && -d $_ } ($FIG_Config::proj, "$FIG_Config::mod_base/p3_docs", $FIG_Config::web_dir);
print scalar(@modules) . " project directories found.\n";
for my $module (@modules) {
    chdir $module;
    print "Processing $module: ";
    my @branches = `git branch --list`;
    # Find the current branch and check for the desired branch.
    my ($current, $found);
    for my $branch (@branches) {
        if ($branch =~ /\s+(\S+)/) {
            my $actual = $1;
            if (substr($branch, 0, 1) eq '*') {
                $current = $actual;
            }
            if ($actual eq $branchName) {
                $found = 1;
            }
        }
    }
    # Did we find the desired branch?
    if ($current eq $branchName) {
        print "already switched to $branchName.\n";
    } elsif (! $found) {
        print "does not have $branchName.\n";
    } else {
        print "switching.\n";
        my $rc = system("git checkout $branchName");
        print "Switch returned $rc.\n";
    }
}
