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

=head1 Runan app_services Script

    app_services.pl cmd parm1 parm2 ...

This script modifies the PATH and the PERL5LIB for running app_services scripts.

=head2 Parameters

The parameters are the name and parameters to be passed to the script.

=cut

$| = 1;
my ($cmd, @parms) = @ARGV;
my $modules = "$ENV{HOME}\\dev_container\\modules";
my $oldPath = $ENV{PATH};
my $oldLib = $ENV{PERL5LIB};
my $path = "$oldPath;$modules\\app_service\\scripts";
my $libs = join(';', $oldLib, map { "$modules\\$_\\lib" } qw(Workspace p3_auth p3_deployment p3diffexp seed_gjo seed_rast typecomp app_service));
$ENV{PATH} = $path;
$ENV{PERL5LIB} = $libs;
system($cmd, @parms);
