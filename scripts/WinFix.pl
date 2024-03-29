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
use File::Basename;

=head1 Fix Text Files

    WinFix.pl [ options ] dir

This script will run through all the files in a directory fixing line endings in the text files.
It is used to clean up after a Windows-to-Mac transfer. A file is considered text if it does not
have a specifically non-text file extension. BLAST database files will be deleted, as these are
incompatible between machines and are regenerated automatically.

=head2 Parameters

The single positional parameter is a directory name. The command-line parameters are

=over 4

=item shallow

If specified, subdirectories will not be processed recursively.

=item perm

Fix the permissions of the files.

=cut

# These constants determine which suffixes require special handling.
use constant BIN_SUFFIX => { '.gz' => 1, '.zip' => 1, '.z' => 1, '.xlsx' => 1, '.xls' => 1,
                            '.xlsm' => 1, '.ser' => 1, '.jar' => 1, '.png' => 1, '.gif' => 1,
                            '.jpg' => 1, '.swg' => 1, '.ico' => 1, '.pdf' => 1, '.docx' => 1,
                            '.docm' => 1, '.pptx' => 1, '.gtoz' => 1 };
use constant DEL_SUFFIX => { '.nhr' => 1, '.nin' => 1, '.nsq' => 1, '.phr' => 1, '.pin' => 1,
                            '.psq' => 1, '.psd' => 1, '.aux' => 1, '.loo' => 1, '.psi' => 1,
                            '.rps' => 1 };
use constant BIN_NAME => { 'RandomForestClassifier' => 1 };

# Get the command-line parameters.
my $opt = ScriptUtils::Opts('dir',
        ['shallow', 'do not recurse into directories'],
        ['all', 'fix all files regardless of extensiion'],
        ['perm', 'fix file permissions']
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
my $first = 1;
my @files = $dir;
while (my $file = shift @files) {
    print "$file: ";
    # Is this a subdirectory?
    if (-d $file) {
        # Handle permissions.
        if( $opt->perm) {
            chmod 0775, $file;
        }
        # Only proceed if we are deep.
        if ($first || ! $opt->shallow) {
            # Open the directory to get the files.
            opendir(my $dh, $file) || die "Could not open $dir: $!";
            # Get all the files.
            my @subfiles = sort grep { substr($_, 0, 1) ne '.' } readdir $dh;
            close $dh;
            print "directory, " . scalar(@subfiles) . " files found.\n";
            push @files, map { "$file/$_" } @subfiles;
            $stats->Add(directories => 1);
            $first = 0;
        }
    } else {
        # Here we have a normal file.  Handle permissions.
        if ($opt->perm) {
            chmod 0764, $file;
        }
        # Compute the suffix and the base name.
        my ($baseName, $dirs, $suffix) = File::Basename::fileparse($file, qr/\.[^.]*/);
        $suffix = lc $suffix;
        # Compute our action.
        if (! $opt->all && (BIN_NAME->{$baseName} || BIN_SUFFIX->{$suffix})) {
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
            if (! -w $file) {
                print "CANNOT WRITE $file.\n";
                $stats->Add(lockedFile => 1);
            } elsif (! open(my $ih, '<', $file)) {
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
                if (! open(my $oh, '>', $file)) {
                    print "Could not open $file for output: $!\n";
                } else {
                    for my $line (@lines) {
                        print $oh $line;
                    }
                    print "fixed.\n";
                    $stats->Add(fixed => 1);
                }
            }
        }
    }
}
print "All done.\n" . $stats->Show();
