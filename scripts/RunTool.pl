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
use SeedTkRun;

=head1 Run a Tool

    RunTool.pl [ options ] toolName parms

This script runs a SEEDtk tool. It can be used even if the tool is not in the path, so long as its
directory is listed in the C<@tools> member of L<FIG_Config>.

=head2 Parameters

The first positional parameter is the tool name. The remaining parameters are passed to the tool directly.

=cut

# Get the command.
my ($cmd, @parms) = @ARGV;
# Find the command.
my $cmdPath = SeedTkRun::executable_for($cmd);
die "Could not find $cmd." if ! $cmdPath;
# Windows hack for paths with spaces.
if ($cmdPath =~ /\s/) {
    $cmdPath = $cmd;
}
# Execute the command.
system ($cmdPath, @parms) == 0 or die "$cmdPath failed: $?";