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
use File::Spec;
use File::Path;

=head1 Tool Installation Utility

    InstallTool [ options ] tarfile

This script is used to install tools that are packaged as tar files. The package
will be installed into the packages directory in the main SEEDtk project.

=head2 Parameters

This script has a single positional parameter, the name of the tar file containing
the tool.

=cut

# Get the tar file to unpack.
my $tarFile = $ARGV[0];
if (! $tarFile) {
	die "No tar file specified.";
} else {
	my $tarPath = File::Spec->rel2abs($tarFile);
	if (! -f $tarPath) {
		die "Could not find source file $tarPath";
	} else {
		# Make sure we have a packages directory.
		File::Path::make_path("$FIG_Config::proj/packages");
		# Switch to it.
		chdir "$FIG_Config::proj/packages";
		# Untar the tool.
		system("tar", "-xvf", $tarPath);
		print "Run the Config script to complete the install.\n";
	}
}