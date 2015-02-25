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
use Loader;
use File::Copy::Recursive;
use Stats;

=head1 Create Mini-Seed

    MiniSeed [ options ] fig_disk output_fig_disk ...

Extract a set of subsystems and genomes from a specified SEED figdisk into a SEED-like
directory structure. This is used to create portable test data for scripts that access SEED
genome and subsystem directories.

=head2 Parameters

The positional parameters are the source FIGdisk directory of a SEED and a destination directory
for the output mini-seed.

The command-line options for specifying the input file are as described in L<ScriptUtils/ih_options>.
The input file should contain a list of subsystem names, one per line, followed by a double slash
(C<//>) and a list of genome names, one per line.

=cut

$| = 1; ## Prevent buffering on STDOUT.
# Create the statistics object.
my $stats = Stats->new();
# Get the command-line parameters.
my $opt = ScriptUtils::Opts('fig_disk output_fig_disk', ScriptUtils::ih_options(),
        );
# Get the SEED FIGdisk.
my $figDisk = $ARGV[0];
if (! $figDisk) {
    die "You must specify a SEED FIGdisk.";
} elsif (! -d $figDisk) {
    die "SEED directory $figDisk not found.";
}
# Get the organisms and subsystem directories.
my $orgDisk = "$figDisk/FIG/Data/Organisms";
my $subDisk = "$figDisk/FIG/Data/Subsystems";
if (! -d $orgDisk || ! -d $subDisk) {
    die "$figDisk does not appear to be a SEED FIGdisk";
}
# Get the output FIGdisk.
my $outFigDisk = $ARGV[1];
if (! $outFigDisk) {
    die "You must specify an output FIGdisk.";
} elsif (! -d $outFigDisk) {
    print "Creating output FIG disk $outFigDisk.\n";
    File::Copy::Recursive::pathmk($outFigDisk);
}
# Insure the output subdirectories exist.
my $outOrgDisk = "$outFigDisk/FIG/Data/Organisms";
my $outSubDisk = "$outFigDisk/FIG/Data/Subsystems";
if (! -d $outOrgDisk) {
    print "Creating output directory for genomes $outOrgDisk.\n";
    File::Copy::Recursive::pathmk($outOrgDisk);
}
if (! -d $outSubDisk) {
    print "Creating output directory for subsystems $outSubDisk.\n";
    File::Copy::Recursive::pathmk($outSubDisk);
}
# Open the input file.
my $ih = ScriptUtils::IH($opt->input);
# Loop through the subsystems.
my $done = 0;
while (! eof $ih && ! $done) {
    my $subsystem = <$ih>;
    chomp $subsystem;
    $stats->Add(lineIn => 1);
    # Is this an end marker?
    if (substr($subsystem, 0, 2) eq '//') {
        # Yes. Stop this loop.
        $done = 1;
    } else {
        # Denormalize the subsystem name.
        $subsystem =~ tr/ /_/;
        # Insure it exists.
        if (! -d "$subDisk/$subsystem") {
            print "Subsystem directory $subsystem not found.\n";
            $stats->Add(subNotFound => 1);
        } else {
            # Copy the subsystem directory.
            print "Copying $subsystem.\n";
            my $fileCount = File::Copy::Recursive::dircopy("$subDisk/$subsystem", "$outSubDisk/$subsystem");
            $stats->Add(subCopied => 1);
            $stats->Add(subFilesCopied => $fileCount);
        }
    }
}
# Now loop through the genomes.
while (! eof $ih) {
    my $genome = <$ih>;
    chomp $genome;
    $stats->Add(lineIn => 1);
    # Insure the genome exists.
    my $orgDir = "$orgDisk/$genome";
    if (! -d $orgDir) {
        print "Genome directory $genome not found.\n";
        $stats->Add(orgNotFound => 1);
    } else {
        # Now we want to copy the genome directory. We purposefully skip over
        # scenarios and models, which requires we look at the directory children ourselves.
        my $outOrgDir = "$outOrgDisk/$genome";
        print "Copying $genome.\n";
        if (! -d $outOrgDir) {
            File::Copy::Recursive::pathmk($outOrgDir);
        }
        # Get the genome components.
        my @children = grep { substr($_,0,1) ne '.' && $_ ne 'Scenarios' && $_ ne 'Models'} Loader::OpenDir($orgDir);
        # Loop through them, copying.
        for my $child (@children) {
            my $fileCount = File::Copy::Recursive::rcopy("$orgDir/$child", "$outOrgDir/$child");
            $stats->Add(orgFilesCopied => $fileCount);
        }
        $stats->Add(orgCopied => 1);
    }
}
# Tell the user we're done.
print "All done.\n" . $stats->Show();
