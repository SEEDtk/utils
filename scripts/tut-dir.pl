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

=head1 Display Tutorials Directory

    tut-dir.pl [ options ]

This script will display the name of the tutorials directory.

=head2 Parameters

There are no positional parameters.

=cut

# Get the command-line parameters.
my $opt = ScriptUtils::Opts('');
my $webDir = $FIG_Config::web_dir . "/Tutorials";
print "Tutorial directory is $webDir.\n";
