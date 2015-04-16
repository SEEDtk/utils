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
use File::stat;
use StringUtils;
use Stats;
use File::Copy::Recursive;
use DateTime;

=head1 Coordinate SEED and SEEDtk Project Source Updates

    CheckUpdates.pl [ options ] mod1 mod2 ...

This script processes the shared projects and makes sure that any changes are coordinated
with the corresponding files in the main SEED code space.

The B<$FIG_Config::cvsroot> variable points to a directory containing the SEED code space,
which is managed by CVS. The B<lib> subdirectory of a shared module corresponds to B<FigKernelPackages> in the
SEED space; the B<scripts> subdirectory to B<FigKernelScripts>. Before beginning, we must insure that
the local projects are committed and a C<cvs update> has been run on the SEED projects. Finally, the
file C<sync.txt> in the project config directory contains the date and time of the last successful
synchronization. This is called the I<sync time>.

We get from the CVS data structures the date and time a file was updated in CVS. We use the file status
to determine the date and time one of our files was updated. We also verify that a commit has been performed
on our files. This means that if a failure occurs in the middle of a synchronization, any changes to our
files must be analyzed and verified before we can proceed.

If only one file (ours or SEED's) has changed since the last synchronization, then we copy the changed file
over the unchanged one. If both files have changed, we copy the SEED file over ours and flag it for
analysis and comparison. Since

If something is copied from our direction, we do a CVS commit on the SEED side. If something is copied in
our direction, the user is required to analyze the changes, commit them, and run this script again.

=head2 Parameters

The positional parameters are the shared modules to be processed. If no positional parameters are specified,
then the value of the B<@shared> member of L<FIG_Config> is interrogate.

The command-line options are the following.

=over 4

=item check

Check the GIT and CVS status, but do not process any modules. Mutually exclusive with C<--test>.

=item test

Display the moves that would be made, but do not make any changes. Mutually exclusive with C<--check>.

=item seedlib

SEED library directory. The default is C<FigKernelPackages> under the directory pointed to by B<$cvsroot>
in L<FIG_Config>.

=item seedscripts

SEED script directory. The default is C<FigKernelScripts> under the directory pointed to by B<$cvsroot>
in L<FIG_Config>.

=item cvsforce

Perform a real CVS update. This increases the chances that the SEED source will be up-to-date, but it is
not a read-only operation.

=item log

Log file for this run. If none is specified, one will be created.

=back

=cut

# Suppress buffering on STDOUT.
$| = 1;
# Get the command-line parameters.
my $opt = ScriptUtils::Opts('mod1 mod2 ...',
                    ['check|c', 'check source control status without scanning modules'],
                    ['test|t', 'test modules without making modifications'],
                    ['seedlib', 'SEED library directory', { default => "$FIG_Config::cvsroot/FigKernelPackages" }],
                    ['seedscripts', 'SEED script directory', { default => "$FIG_Config::cvsroot/FigKernelScripts" }],
                    ['cvsforce|F', 'perform a real CVS update to bring SEED up-to-date'],
                    ['log|l', 'log file for saved output from this script ("none" for no logging)']
        );
# Insure we haven't specified an invalid combination of options.
if ($opt->check && $opt->test) {
    die "Cannot specify both \"check\" and \"test\".";
}
# Create the statistics object.
my $stats = Stats->new;
# Get access to date parsing.
eval {
    require DateTime::Format::Flexible;
};
if ($@) {
    die "This script requires DateTime::Format::Flexible from CPAN.";
}
# Create the log file.
my $oh;
# We'll compute the log file name in here.
my $logFile = $opt->log;
if (! $logFile) {
    # Here we have to default the log file. If we are not updating, then the log file
    # defaults to no log at all.
    if ($opt->check || $opt->test) {
        $logFile = 'none';
    } else {
        # Here the user wants a timestamped logfile. Insure we have a logging directory.
        my $logDir = "$FIG_Config::proj/logs";
        File::Copy::Recursive::pathmk($logDir);
        # Here the log file name is computed using the date.
        $logFile = join("/", $logDir, StringUtils::NameTime('sync', time(), 'log'));
    }
}
# Open the log file if the user wants one.
if ($logFile ne 'none') {
    open($oh, ">$logFile") || die "Could not open $logFile: $!";
}
Print($oh, "Beginning synchronization run.\n");
# Read the synchronization time file.
my $syncTime;
my $syncFile = "$FIG_Config::proj/config/sync.txt";
if (! -s $syncFile) {
    Print($oh, "No synchronization file. Null date will be used.\n");
    $syncTime = DateTime->from_epoch(epoch => 0);
} else {
    open(my $sh, "<$syncFile") or die "Could not open synchronization date file: $!";
    my $timeStamp = <$sh>;
    chomp $timeStamp;
    $syncTime = DateTime::Format::Flexible->parse_datetime($timeStamp);
    print "Incoming synchronization date is " . $syncTime->strftime("%D %T") . "\n";
}
# Get the SEED directories.
my %seed = (lib => $opt->seedlib, scripts => $opt->seedscripts);
# Get the SEEDtk module base.
my $modBase = $FIG_Config::mod_base;
# First the check phase. This verifies both sides are up-to-date. If there is a problem, we set
# this variable to TRUE.
my $errors = 0;
# First we must compute the CVS configuration stuff. We set
# "$cmd" to the command to use, and %stats is keyed on the
# legal status letters.
my ($cmd, %stats);
if ($opt->cvsforce) {
    $cmd = 'cvs update -l';
    %stats = ('P' => 1, 'U' => 1);
} else {
    $cmd = 'cvs -n update -l';
    %stats = ();
}
# Loop through the SEED directories.
for my $dir (keys %seed) {
    my $fullDir = $seed{$dir};
    Print($oh, "Checking CVS status of $fullDir.\n");
    chdir $fullDir or die "Could not change to directory: $!";
    my @changes = `$cmd`;
    if ($?) {
        die "Error in CVS. rc = $?";
    }
    $stats->Add(cvsCalls => 1);
    # Look for unapproved status letters.
    for my $change (@changes) {
        $stats->Add(cvsOutput => 1);
        if ($change =~ /(\w)\s+(.+)/ && ! $stats{$1}) {
            Print($oh, "File $2 is not up-to-date. Status $1.\n");
            $errors++;
        }
    }
}
# Now we need to check our modules.
my @mods = @ARGV;
if (! @mods) {
    @mods = @FIG_Config::shared;
}
for my $mod (@mods) {
    my $fullDir = "$modBase/$mod";
    Print($oh, "Checking GIT status of $fullDir.\n");
    chdir $fullDir or die "Could not change to directory: $!";
    my @changes = `git status --untracked-files=no --porcelain`;
    if ($?) {
        die "Error in GIT. rc = $?";
    }
    $stats->Add(gitCalls => 1);
    # Any changes are a problem.
    for my $change (@changes) {
        $stats->Add(gitOutput => 1);
        if ($change =~ /^(..)\s+(.+)/) {
            Print($oh, "File $2 is not up-to-date. Status $1.\n");
            $errors++;
        }
    }
}
# Exit if we found errors or if we're only checking.
if ($errors) {
    Print($oh, " *** ERROR *** One or more projects are not up-to-date. Aborting.\n");
} elsif ($opt->check) {
    Print($oh, "Check option specified. No further processing.\n");
} else {
    # Now we need to get the SEED file dates. The following hash maps each
    # SEED library type to a sub-hash that maps file names to [date,fullpath]
    # tuples.
    my %seedFiles;
    # Loop through the SEED directories.
    for my $dir (keys %seed) {
        my $fullDir = $seed{$dir};
        Print($oh, "Reading CVS directory in $fullDir.\n");
        open(my $ih, "<$fullDir/CVS/Entries") or die "Could not open $fullDir CVS file: $!";
        while (! eof $ih) {
            # Parse the next line of the CVS directory listing. It has the format type/filename/version/date/.
            # We want an empty string for type, which means a file.
            my $line = <$ih>;
            $stats->Add(cvsEntryLine => 1);
            if ($line =~ m#^/([^/]+)/\d+\.\d+/([^/]+)/#) {
                # Here we have a file name and date.
                my ($name, $dateTime) = ($1, DateTime::Format::Flexible->parse_datetime($2));
                $seedFiles{$dir}{$name} = [$dateTime, "$fullDir/$name"];
                $stats->Add(cvsEntryFile => 1);
            }
        }
    }
    # Next, we process each SEEDtk module. The following list will contain a sequence of
    # copy commands in the form [sourceFile, destFile].
    my @copies;
    # This counter will track the number of copies in the SEEDtk direction.
    my $needsAnalysis = 0;
    # The following hash lists the files that need to be added to CVS in each SEED directory.
    my %seedAdd = ();
    # This hash tracks the changes to the CVS libraries. It is keyed by type, the
    # same as %seed.
    my %seedChanges;
    # Loop through the modules.
    for my $mod (@mods) {
        Print($oh, "Processing $mod.\n");
        $stats->Add(moduleAnalyzed => 1);
        # Form this module's base directory name.
        my $fullMod = "$FIG_Config::mod_base/$mod";
        # Loop through the subdirectories.
        for my $dir (keys %seed) {
            # Get all the files in this subdirectory.
            my $fullDir = "$fullMod/$dir";
            opendir(my $dh, "$fullDir") or die "Could not open $dir in $fullMod: $!";
            my @files = grep { $_ =~ /^\w+\.\w+$/ && -f "$fullDir/$_" } readdir $dh;
            for my $file (@files) {
                # Get this file's full name.
                my $fullName = "$fullDir/$file";
                # Get this file's modification time.
                my $stat = stat $fullName;
                my $fileTime = DateTime->from_epoch(epoch => $stat->mtime);
                # Look for the file on the SEED side.
                my $seedData = $seedFiles{$dir}{$file};
                # If it is not found, we have an add.
                if (! $seedData) {
                    $stats->Add(cvsAddRequired => 1);
                    push @copies, [$fullName, "$seed{$dir}/$file"];
                    push @{$seedAdd{$dir}}, $file;
                    $seedChanges{$dir}++;
                    Print($oh, "$dir file $file is new in $mod.\n");
                } else {
                    # Get the CVS information for this file.
                    my ($seedTime, $fullSeedName) = @$seedData;
                    # Now compare the times.
                    if ($seedTime > $syncTime) {
                        # Here the SEED file has changed since the last sync. Copy it to
                        # us so we can analyze it.
                        $stats->Add(cvsChangeDetected => 1);
                        push @copies, [$fullSeedName, $fullName];
                        $needsAnalysis++;
                        Print($oh, "$dir file $file in $mod updated from SEED.\n");
                    } elsif ($fileTime > $seedTime) {
                        # Here our file is newer than the CVS file, which is unchanged.
                        # Copy from us to the SEED.
                        $stats->Add(ourChangeDetected => 1);
                        push @copies, [$fullName, $fullSeedName];
                        $seedChanges{$dir}++;
                        Print($oh, "$dir file $file in SEED updated from $mod.\n");
                    } else {
                        # Here everything is in sync.
                        $stats->Add(noChangeDetected => 1);
                    }
                }
            }
        }
    }
    if (! $needsAnalysis) {
        Print($oh, "No SEEDtk files were updated.\n");
    } else {
        Print($oh, "$needsAnalysis SEEDtk files require analysis.\n");
    }
    # Are we only testing?
    if ($opt->test) {
        # Yes. We're done.
        Print($oh, "Test option specified. No file changes will be made.\n");
    } else {
        # We are serious about our changes. Start copying files.
        Print($oh, scalar(@copies) . " copy operations queued.\n");
        for my $copy (@copies) {
            my ($from, $to) = @$copy;
            Print($oh, "Copying $from to $to ... ");
            File::Copy::Recursive::copy($from, $to) or
                die "Copy failed: $!";
            $stats->Add(filesCopied => 1);
            Print($oh, "done.\n");
        }
        # Do the CVS ADDs.
        for my $dir (keys %seedAdd) {
            my $fullDir = $seed{$dir};
            Print($oh, "Processing adds for $fullDir.\n");
            chdir $fullDir or
                die "Could not change to directory: $!";
            # We can add all the files at once.
            system('cvs', 'add', @{$seedAdd{$dir}});
            if ($?) {
                die "CVS ADD failed with rc = $?";
            }
            $stats->Add(cvsAddCommands => 1);
        }
        # Do the CVS COMMITs.
        for my $dir (keys %seedChanges) {
            my $fullDir = $seed{$dir};
            Print($oh, "Processing commit for $fullDir.\n");
            chdir $fullDir or
                die "Could not change to directory: $!";
            system('cvs', 'commit', '-m', 'Changes copied from SEEDtk project.');
            if ($?) {
                die "CVS COMMIT failed with rc = $?";
            }
            $stats->Add(cvsCommitCommands => 1);
        }
        # We are done. Record the sync time.
        open(my $sh, ">$syncFile") or
            die "Could not open sync file $syncFile: $!";
        my $now = StringUtils::Now();
        Print($oh, "Sync time set to $now.\n");
        print $sh "$now\n";
    }
}
# All done. Show the statistics.
Print($oh, "\n" . $stats->Show());


=head2 Subroutines

=head3 Print

    Print($oh, $text);

Write text to the standard output and the specified open file handle.

=over 4

=item oh

Output file handle. If undefined, output will only be to the standard output.

=item text

Text to write to the the output.

=back

=cut

sub Print {
    # Get the parameters.
    my ($oh, $text) = @_;
    # Do we have an output file?
    if ($oh) {
        # Yes, write to it.
        print $oh $text;
    }
    # Write to the standard output.
    print $text;
}