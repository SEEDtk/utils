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
use ScriptUtils;
use File::Spec;
use Stats;

=head1 Convert Comments to Pod

    ConvertToPod [ options ] file1 file2 ...

Convert the comment blocks in the specified files to POD comments. A comments block begins with
a comment containing a long sequence of hyphens and ends with a similar line. The lines in between
are converted to a pod block. This is a very crude method: all it does is make it easier to do a
real conversion by hand.

=head2 Parameters

The positional parameters are the names of the files to be converted.

The command-line options are the following.

=over 4

=item dir

If specified, the directory containing the files to convert. The directory name will be used as a prefix
to all the names specified in the positional parameters.

=back

=cut

# Start timing.
my $startTime = time;
$| = 1; # Prevent buffering on STDOUT.
# Get the command parameters.
my $opt = ScriptUtils::Opts('file1 file2 ...',
        ["dir=s", "default directory for the input files"]
    );
# Get the statistics object.
my $stats = Stats->new();
# Check for a directory.
my $dir = $opt->dir;
if ($dir) {
    print "Default input directory is $dir.\n";
}
# Loop through the input files.
for my $file (@ARGV) {
    # Compute the full file name.
    my $filePath = File::Spec->rel2abs($file, $dir);
    print "Processing $filePath.\n";
    # Open the file for input.
    open(my $ih, "<$filePath") ||
        die "Could not open $file: $!";
    $stats->Add(filesIn => 1);
    # This will be set to TRUE if we are in a comment block.
    my $inBlock;
    # This will be set to TRUE if we are at the beginning of a pod block.
    # it is used to prevent double-blank lines.
    my $blanks;
    # We'll accumulate output lines in here.
    my @lines;
    while (! eof $ih) {
        my $line = <$ih>;
        $stats->Add(linesIn => 1);
        # Determine the line type.
        if ($line =~ /^#(?:\-+|=+)/) {
            # Here we have a block boundary.
            $stats->Add(blockBoundary => 1);
            if ($inBlock) {
                # If we are in a block, it ends the block.
                push @lines, "=cut\n";
                $inBlock = 0;
            } else {
                # Otherwise it starts the block.
                push @lines, "=pod\n", "\n";
                $inBlock = 1;
                $blanks = 1;
            }
        } elsif ($line =~ /^#(.*)/) {
            # Here we have a comment line.
            $stats->Add(comment => 1);
            if ($inBlock) {
                # We are in a block, it is emitted as a pod line.
                if (! $blanks || $1) {
                    push @lines, "$1\n";
                    $blanks = 0;
                }
            } else {
                # We are outside a block, so it is emitted unchanged.
                push @lines, $line;
            }
        } else {
            # Here we have a normal line.
            $stats->Add(code => 1);
            if ($inBlock) {
                # We are in a block, it ends the block.
                push @lines, "=cut\n";
                $inBlock = 0;
                $blanks = 0;
            }
            # Output the line.
            push @lines, $line;
        }
    }
    # Close the file and reopen it for output.
    close $ih;
    open(my $oh, ">$filePath") ||
        die "Could not open $file for output: $!";
    # Write out the accumulated lines.
    for my $line (@lines) {
        $stats->Add(lineOut => 1);
        print $oh $line;
    }
    # Close the file again.
    close $oh;
}
# Compute the total time.
my $timer = time - $startTime;
$stats->Add(totalTime => $timer);
# Tell the user we're done.
print "All done.\n" . $stats->Show();