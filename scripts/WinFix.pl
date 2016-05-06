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
use Stats;

=head1 Fix Text Files

    WinFix.pl [ options ] dir

This script will run through all the files in a directory fixing line endings in the text files.
It is used to clean up after a Windows-to-Mac transfer. A file is considered text if it does not
have a specifically non-text line ending. BLAST database files will be deleted, as these are
incompatible between machines and are regenerated automatically.

=head2 Parameters

The single positional parameter is a directory name.

=cut

# These constants determine which suffixes require special handling.
use constant BIN_SUFFIX => { gz => 1, zip => 1, z => 1, xlsx => 1, xls => 1, xlsm => 1 };
use constant DEL_SUFFIX => { nhr => 1, nin => 1, nsq => 1, phr => 1, pin => 1, psq => 1, 
                             psd => 1, aux => 1, loo => 1, psi => 1, rps => 1 };

# Get the command-line parameters.
my $opt = ScriptUtils::Opts('dir',
        );
# Get the input directory.
my ($dir) = @ARGV;
if (! $dir) {
    die "Directory not specified.";
} elsif (! -d $dir) {
    die "$dir is not a directory.";
} else {
    print "Processing directory $dir.\n";
}
# Create the statistics object.
my $stats = Stats->new();
# Start with the directory.
my @files = $dir;
while (my $file = shift @files) {
    print "$file: ";
    # Is this a subdirectory?
    if (-d $file) {
        # Open the directory to get the files.
        opendir(my $dh, $file) || die "Could not open $dir: $!";
        # Get all the files.
        my @subfiles = sort grep { substr($_, 0, 1) ne '.' } readdir $dh;
        close $dh;
        print "directory, " . scalar(@subfiles) . " files found.\n";
        push @files, map { "$file/$_" } @subfiles;
        $stats->Add(directories => 1);
    } else {
        # Here we have a normal file. Compute the suffix.
        my $suffix = '';
        my ($prefix, @rem) = split /\./, $file;
        if (@rem) {
            $suffix = pop @rem;
        }
        # Compute our action.
        if (BIN_SUFFIX->{$suffix}) {
            # Binary file: no action.
            print "binary-- skipped.\n";
            $stats->Add(skipped => 1);
        } elsif (DEL_SUFFIX->{$suffix}) {
            # Incompatible file: delete.
            unlink $file;
            print "incompatible-- deleted.\n";
            $stats->Add(deleted => 1);
        } else {
            # Normal file: convert.
            if (! open(my $ih, '<', $file)) {
                print "COULD NOT OPEN: $!\n";
                $stats->Add(errors => 1);
            } else {
                # Read and fix the file.
                binmode $ih;
                my @lines;
                while (! eof $ih) {
                    my $line = <$ih>;
                    my $count = ($line =~ s/\r//sg);
                    $stats->Add(lines => 1);
                    $stats->Add('returns-deleted' => $count);
                    push @lines, $line;
                }
                close $ih;
                # Write it back out.
                open(my $oh, '>', $file) || die "Could not open $file for output: $!";
                for my $line (@lines) {
                    print $oh $line;
                }
                print "fixed.\n";
                $stats->Add(fixed => 1);
            }
        }
    }
}
print "All done.\n" . $stats->Show();