# -*- perl -*-
########################################################################
# Copyright (c) 2003-2006 University of Chicago and Fellowship
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
########################################################################


package StringUtils;

    use strict;
    use FIG_Config;
    use base qw(Exporter);
    use vars qw(@EXPORT @EXPORT_OK);
    @EXPORT = qw(Confess Cluck Min Max Assert Open OpenDir TICK Constrain Insure ChDir IDHASH);
    @EXPORT_OK = qw(GetFile ParseRecord UnEscape Escape PrintLine PutLine);
    use Carp qw(longmess croak carp confess);
    use CGI;
    use Cwd;
    use Digest::MD5;
    use File::Basename;
    use File::Path;
    use File::stat;
    use LWP::UserAgent;
    use Time::HiRes 'gettimeofday';
    use URI::Escape;
    use Time::Local;
    use POSIX qw(strftime);
    use Fcntl qw(:DEFAULT :flock);
    use Data::Dumper;


    #
    # These are made optional in order to facilitate the SAS release
    # that might need Tracer.
    #
    BEGIN {
        eval {
            require FIG_Config;
        };
        if ($@) {
            $FIG_Config::temp = "/tmp";
        }
    }

=head1 Debugging Helpers


=head3 ParseDate

    my $time = StringUtils::ParseDate($dateString);

Convert a date into a PERL time number. This method expects a date-like string
and parses it into a number. The string must be vaguely date-like or it will
return an undefined value. Our requirement is that a month and day be
present and that three pieces of the date string (time of day, month and day,
year) be separated by likely delimiters, such as spaces, commas, and such-like.

If a time of day is present, it must be in military time with two digits for
everything but the hour.

The year must be exactly four digits.

Additional stuff can be in the string. We presume it's time zones or weekdays or something
equally innocuous. This means, however, that a sufficiently long sentence with date-like
parts in it may be interpreted as a date. Hopefully this will not be a problem.

It should be guaranteed that this method will parse the output of the L</Now> function.

The parameters are as follows.

=over 4

=item dateString

The date string to convert.

=item RETURN

Returns a PERL time, that is, a number of seconds since the epoch, or C<undef> if
the date string is invalid. A valid date string must contain a month and day.

=back

=cut

# Universal month conversion table.
use constant MONTHS => {    Jan =>  0, January   =>  0, '01' =>  0,  '1' =>  0,
                            Feb =>  1, February  =>  1, '02' =>  1,  '2' =>  1,
                            Mar =>  2, March     =>  2, '03' =>  2,  '3' =>  2,
                            Apr =>  3, April     =>  3, '04' =>  3,  '4' =>  3,
                            May =>  4, May       =>  4, '05' =>  4,  '5' =>  4,
                            Jun =>  5, June      =>  5, '06' =>  5,  '6' =>  5,
                            Jul =>  6, July      =>  6, '07' =>  6,  '7' =>  6,
                            Aug =>  7, August    =>  7, '08' =>  7,  '8' =>  7,
                            Sep =>  8, September =>  8, '09' =>  8,  '9' =>  8,
                            Oct =>  9, October  =>   9, '10' =>  9,
                            Nov => 10, November =>  10, '11' => 10,
                            Dec => 11, December =>  11, '12' => 11
                        };

sub ParseDate {
    # Get the parameters.
    my ($dateString) = @_;
    # Declare the return variable.
    my $retVal;
    # Find the month and day of month. There are two ways that can happen. We check for the
    # numeric style first. That way, if the user's done something like "Sun 12/22", then we
    # won't be fooled into thinking the month is Sunday.
    if ($dateString =~ m#\b(\d{1,2})/(\d{1,2})\b# || $dateString =~ m#\b(\w+)\s(\d{1,2})\b#) {
        my ($mon, $mday) = (MONTHS->{$1}, $2);
        # Insist that the month and day are valid.
        if (defined($mon) && $2 >= 1 && $2 <= 31) {
            # Find the time.
            my ($hour, $min, $sec) = (0, 0, 0);
            if ($dateString =~ /\b(\d{1,2}):(\d{2}):(\d{2})\b/) {
                ($hour, $min, $sec) = ($1, $2, $3);
            }
            # Find the year.
            my $year;
            if ($dateString =~ /\b(\d{4})\b/) {
                $year = $1;
            } else {
                # Get the default year, which is this one. Note we must convert it to
                # the four-digit value expected by "timelocal".
                (undef, undef, undef, undef, undef, $year) = localtime();
                $year += 1900;
            }
            $retVal = timelocal($sec, $min, $hour, $mday, $mon, $year);
        }
    }
    # Return the result.
    return $retVal;
}

=head3 LogErrors

    StringUtils::LogErrors($fileName);

Route the standard error output to a log file.

=over 4

=item fileName

Name of the file to receive the error output.

=back

=cut

sub LogErrors {
    # Get the file name.
    my ($fileName) = @_;
    # Open the file as the standard error output.
    open STDERR, '>', $fileName;
}


=head3 Confess

    Confess($message);

Trace the call stack and abort the program with the specified message. When used with
the OR operator and the L</Assert> method, B<Confess> can function as a debugging assert.
So, for example

    Assert($recNum >= 0) || Confess("Invalid record number $recNum.");

Will abort the program with a stack trace if the value of C<$recNum> is negative.

=over 4

=item message

Message to include in the trace.

=back

=cut

sub Confess {
    # Get the parameters.
    my ($message) = @_;
    # Trace the call stack.
    Cluck($message);
    # Abort the program.
    croak(">>> $message");
}


=head3 Assert

    Assert($condition1, $condition2, ... $conditionN);

Return TRUE if all the conditions are true. This method can be used in conjunction with
the OR operator and the L</Confess> method as a debugging assert.
So, for example

    Assert($recNum >= 0) || Confess("Invalid record number $recNum.");

Will abort the program with a stack trace if the value of C<$recNum> is negative.

=cut
sub Assert {
    my $retVal = 1;
    LOOP: for my $condition (@_) {
        if (! $condition) {
            $retVal = 0;
            last LOOP;
        }
    }
    return $retVal;
}

=head3 Cluck

    Cluck($message);

Trace the call stack.

=over 4

=item message

Message to include in the trace.

=back

=cut

sub Cluck {
    # Get the parameters.
    my ($message) = @_;
    # Trace what's happening.
    warn "Stack trace for event: $message\n";
    # Get the stack trace.
    my @trace = LongMess();
    # Convert the trace to a series of messages.
    for my $line (@trace) {
        # Replace the tab at the beginning with spaces.
        $line =~ s/^\t/    /;
        # Trace the line.
        warn "$line\n";
    }
}

=head3 LongMess

    my @lines = StringUtils::LongMess();

Return a stack trace with all tracing methods removed. The return will be in the form of a list
of message strings.

=cut

sub LongMess {
    # Declare the return variable.
    my @retVal = ();
    my $confession = longmess("");
    for my $line (split m/\s*\n/, $confession) {
        unless ($line =~ /Tracer\.pm/) {
            # Here we have a line worth keeping. Push it onto the result list.
            push @retVal, $line;
        }
    }
    # Return the result.
    return @retVal;
}


=head2 File Utility Methods

=head3 GetFile

    my @fileContents = StringUtils::GetFile($fileName);

    or

    my $fileContents = StringUtils::GetFile($fileName);

Return the entire contents of a file. In list context, line-ends are removed and
each line is a list element. In scalar context, line-ends are replaced by C<\n>.

=over 4

=item fileName

Name of the file to read.

=item RETURN

In a list context, returns the entire file as a list with the line terminators removed.
In a scalar context, returns the entire file as a string. If an error occurs opening
the file, an empty list will be returned.

=back

=cut

sub GetFile {
    # Get the parameters.
    my ($fileName) = @_;
    # Declare the return variable.
    my @retVal = ();
    # Open the file for input.
    my $handle = Open(undef, "<$fileName");
    # Read the whole file into the return variable, stripping off any terminator
    # characters.
    my $lineCount = 0;
    while (! eof $handle) {
        my $line = <$handle>;
        $lineCount++;
        $line = Strip($line);
        push @retVal, $line;
    }
    # Close it.
    close $handle;
    my $actualLines = @retVal;
    # Return the file's contents in the desired format.
    if (wantarray) {
        return @retVal;
    } else {
        return join "\n", @retVal;
    }
}

=head3 PutFile

    StringUtils::PutFile($fileName, \@lines);

Write out a file from a list of lines of text.

=over 4

=item fileName

Name of the output file.

=item lines

Reference to a list of text lines. The lines will be written to the file in order, with trailing
new-line characters. Alternatively, may be a string, in which case the string will be written without
modification.

=back

=cut

sub PutFile {
    # Get the parameters.
    my ($fileName, $lines) = @_;
    # Open the output file.
    my $handle = Open(undef, ">$fileName");
    # Count the lines written.
    if (ref $lines ne 'ARRAY') {
        # Here we have a scalar, so we write it raw.
        print $handle $lines;
    } else {
        # Write the lines one at a time.
        my $count = 0;
        for my $line (@{$lines}) {
            print $handle "$line\n";
            $count++;
        }
    }
    # Close the output file.
    close $handle;
}

=head3 ParseRecord

    my @fields = StringUtils::ParseRecord($line);

Parse a tab-delimited data line. The data line is split into field values. Embedded tab
and new-line characters in the data line must be represented as C<\t> and C<\n>, respectively.
These will automatically be converted.

=over 4

=item line

Line of data containing the tab-delimited fields.

=item RETURN

Returns a list of the fields found in the data line.

=back

=cut

sub ParseRecord {
    # Get the parameter.
    my ($line) = @_;
    # Remove the trailing new-line, if any.
    chomp $line;
    # Split the line read into pieces using the tab character.
    my @retVal = split /\t/, $line;
    # Trim and fix the escapes in each piece.
    for my $value (@retVal) {
        # Trim leading whitespace.
        $value =~ s/^\s+//;
        # Trim trailing whitespace.
        $value =~ s/\s+$//;
        # Delete the carriage returns.
        $value =~ s/\r//g;
        # Convert the escapes into their real values.
        $value =~ s/\\t/"\t"/ge;
        $value =~ s/\\n/"\n"/ge;
    }
    # Return the result.
    return @retVal;
}

=head3 Merge

    my @mergedList = StringUtils::Merge(@inputList);

Sort a list of strings and remove duplicates.

=over 4

=item inputList

List of scalars to sort and merge.

=item RETURN

Returns a list containing the same elements sorted in ascending order with duplicates
removed.

=back

=cut

sub Merge {
    # Get the input list in sort order.
    my @inputList = sort @_;
    # Only proceed if the list has at least two elements.
    if (@inputList > 1) {
        # Now we want to move through the list splicing out duplicates.
        my $i = 0;
        while ($i < @inputList) {
            # Get the current entry.
            my $thisEntry = $inputList[$i];
            # Find out how many elements duplicate the current entry.
            my $j = $i + 1;
            my $dup1 = $i + 1;
            while ($j < @inputList && $inputList[$j] eq $thisEntry) { $j++; };
            # If the number is nonzero, splice out the duplicates found.
            if ($j > $dup1) {
                splice @inputList, $dup1, $j - $dup1;
            }
            # Now the element at position $dup1 is different from the element before it
            # at position $i. We push $i forward one position and start again.
            $i++;
        }
    }
    # Return the merged list.
    return @inputList;
}

=head3 Open

    my $handle = Open($fileHandle, $fileSpec, $message);

Open a file.

The I<$fileSpec> is essentially the second argument of the PERL C<open>
function. The mode is specified using Unix-like shell information. So, for
example,

    Open(\*LOGFILE, '>>/usr/spool/news/twitlog', "Could not open twit log.");

would open for output appended to the specified file, and

    Open(\*DATASTREAM, "| sort -u >$outputFile", "Could not open $outputFile.");

would open a pipe that sorts the records written and removes duplicates. Note
the use of file handle syntax in the Open call. To use anonymous file handles,
code as follows.

    my $logFile = Open(undef, '>>/usr/spool/news/twitlog', "Could not open twit log.");

The I<$message> parameter is used if the open fails. If it is set to C<0>, then
the open returns TRUE if successful and FALSE if an error occurred. Otherwise, a
failed open will throw an exception and the third parameter will be used to construct
an error message. If the parameter is omitted, a standard message is constructed
using the file spec.

    Could not open "/usr/spool/news/twitlog"

Note that the mode characters are automatically cleaned from the file name.
The actual error message from the file system will be captured and appended to the
message in any case.

    Could not open "/usr/spool/news/twitlog": file not found.

In some versions of PERL the only error message we get is a number, which
corresponds to the C++ C<errno> value.

    Could not open "/usr/spool/news/twitlog": 6.

=over 4

=item fileHandle

File handle. If this parameter is C<undef>, a file handle will be generated
and returned as the value of this method.

=item fileSpec

File name and mode, as per the PERL C<open> function.

=item message (optional)

Error message to use if the open fails. If omitted, a standard error message
will be generated. In either case, the error information from the file system
is appended to the message. To specify a conditional open that does not throw
an error if it fails, use C<0>.

=item RETURN

Returns the name of the file handle assigned to the file, or C<undef> if the
open failed.

=back

=cut

sub Open {
    # Get the parameters.
    my ($fileHandle, $fileSpec, $message) = @_;
    # Attempt to open the file.
    my $rv = open $fileHandle, $fileSpec;
    # If the open failed, generate an error message.
    if (! $rv) {
        # Save the system error message.
        my $sysMessage = $!;
        # See if we need a default message.
        if (!$message) {
            # Clean any obvious mode characters and leading spaces from the
            # filename.
            my ($fileName) = FindNamePart($fileSpec);
            $message = "Could not open \"$fileName\"";
        }
        # Terminate with an error using the supplied message and the
        # error message from the file system.
        Confess("$message: $!");
    }
    # Return the file handle.
    return $fileHandle;
}

=head3 FindNamePart

    my ($fileName, $start, $len) = StringUtils::FindNamePart($fileSpec);

Extract the portion of a file specification that contains the file name.

A file specification is the string passed to an C<open> call. It specifies the file
mode and name. In a truly complex situation, it can specify a pipe sequence. This
method assumes that the file name is whatever follows the first angle bracket
sequence.  So, for example, in the following strings the file name is
C</usr/fig/myfile.txt>.

    >>/usr/fig/myfile.txt
    </usr/fig/myfile.txt
    | sort -u > /usr/fig/myfile.txt

If the method cannot find a file name using its normal methods, it will return the
whole incoming string.

=over 4

=item fileSpec

File specification string from which the file name is to be extracted.

=item RETURN

Returns a three-element list. The first element contains the file name portion of
the specified string, or the whole string if a file name cannot be found via normal
methods. The second element contains the start position of the file name portion and
the third element contains the length.

=back

=cut
#: Return Type $;
sub FindNamePart {
    # Get the parameters.
    my ($fileSpec) = @_;
    # Default to the whole input string.
    my ($retVal, $pos, $len) = ($fileSpec, 0, length $fileSpec);
    # Parse out the file name if we can.
    if ($fileSpec =~ m/(<|>>?)(.+?)(\s*)$/) {
        $retVal = $2;
        $len = length $retVal;
        $pos = (length $fileSpec) - (length $3) - $len;
    }
    # Return the result.
    return ($retVal, $pos, $len);
}

=head3 OpenDir

    my @files = OpenDir($dirName, $filtered, $flag);

Open a directory and return all the file names. This function essentially performs
the functions of an C<opendir> and C<readdir>. If the I<$filtered> parameter is
set to TRUE, all filenames beginning with a period (C<.>), dollar sign (C<$>),
or pound sign (C<#>) and all filenames ending with a tilde C<~>) will be
filtered out of the return list. If the directory does not open and I<$flag> is not
set, an exception is thrown. So, for example,

    my @files = OpenDir("/Volumes/fig/contigs", 1);

is effectively the same as

    opendir(TMP, "/Volumes/fig/contigs") || Confess("Could not open /Volumes/fig/contigs.");
    my @files = grep { $_ !~ /^[\.\$\#]/ && $_ !~ /~$/ } readdir(TMP);

Similarly, the following code

    my @files = grep { $_ =~ /^\d/ } OpenDir("/Volumes/fig/orgs", 0, 1);

Returns the names of all files in C</Volumes/fig/orgs> that begin with digits and
automatically returns an empty list if the directory fails to open.

=over 4

=item dirName

Name of the directory to open.

=item filtered

TRUE if files whose names begin with a period (C<.>) should be automatically removed
from the list, else FALSE.

=item flag

TRUE if a failure to open is okay, else FALSE

=back

=cut
#: Return Type @;
sub OpenDir {
    # Get the parameters.
    my ($dirName, $filtered, $flag) = @_;
    # Declare the return variable.
    my @retVal = ();
    # Open the directory.
    if (opendir(my $dirHandle, $dirName)) {
        # The directory opened successfully. Get the appropriate list according to the
        # strictures of the filter parameter.
        if ($filtered) {
            @retVal = grep { $_ !~ /^[\.\$\#]/ && $_ !~ /~$/ } readdir $dirHandle;
        } else {
            @retVal = readdir $dirHandle;
        }
        closedir $dirHandle;
    } elsif (! $flag) {
        # Here the directory would not open and it's considered an error.
        Confess("Could not open directory $dirName.");
    }
    # Return the result.
    return @retVal;
}


=head3 Insure

    Insure($dirName, $chmod);

Insure a directory is present.

=over 4

=item dirName

Name of the directory to check. If it does not exist, it will be created.

=item chmod (optional)

Security privileges to be given to the directory if it is created.

=back

=cut

sub Insure {
    my ($dirName, $chmod) = @_;
    if (! -d $dirName) {
        eval {
            mkpath $dirName;
            # If we have permissions specified, set them here.
            if (defined($chmod)) {
                chmod $chmod, $dirName;
            }
        };
        if ($@) {
            Confess("Error creating $dirName: $@");
        }
    }
}

=head3 ChDir

    ChDir($dirName);

Change to the specified directory.

=over 4

=item dirName

Name of the directory to which we want to change.

=back

=cut

sub ChDir {
    my ($dirName) = @_;
    if (! -d $dirName) {
        Confess("Cannot change to directory $dirName: no such directory.");
    } else {
        my $okFlag = chdir $dirName;
        if (! $okFlag) {
            Confess("Error switching to directory $dirName.");
        }
    }
}


=head3 GetLine

    my @data = StringUtils::GetLine($handle);

Read a line of data from a tab-delimited file.

=over 4

=item handle

Open file handle from which to read.

=item RETURN

Returns a list of the fields in the record read. The fields are presumed to be
tab-delimited. If we are at the end of the file, then an empty list will be
returned. If an empty line is read, a single list item consisting of a null
string will be returned.

=back

=cut

sub GetLine {
    # Get the parameters.
    my ($handle) = @_;
    # Declare the return variable.
    my @retVal = ();
    # Read from the file.
    my $line = <$handle>;
    # Only proceed if we found something.
    if (defined $line) {
        # If the line is empty, return a single empty string; otherwise, parse
        # it into fields.
        if ($line eq "") {
            push @retVal, "";
        } else {
            # Remove the new-line. We are a bit over-cautious here because the file may be coming in via an
            # upload control and have a nonstandard EOL combination.
            my @fields = split /\t/, $line;
            if (@fields) {
                $fields[$#fields] =~ s/[\r\n]+$//;
            }
            push @retVal, @fields;
        }
    }
    # Return the result.
    return @retVal;
}

=head3 PutLine

    StringUtils::PutLine($handle, \@fields, $eol);

Write a line of data to a tab-delimited file. The specified field values will be
output in tab-separated form, with a trailing new-line.

=over 4

=item handle

Output file handle.

=item fields

List of field values.

=item eol (optional)

End-of-line character (default is "\n").

=back

=cut

sub PutLine {
    # Get the parameters.
    my ($handle, $fields, $eol) = @_;
    # Write the data.
    print $handle join("\t", @{$fields}) . ($eol || "\n");
}


=head3 PrintLine

    StringUtils::PrintLine($line);

Print a line of text with a trailing new-line.

=over 4

=item line

Line of text to print.

=back

=cut

sub PrintLine {
    # Get the parameters.
    my ($line) = @_;
    # Print the line.
    print "$line\n";
}


=head2 Other Useful Methods

=head3 IDHASH

    my $hash = SHTargetSearch::IDHASH(@keys);

This is a dinky little method that converts a list of values to a reference
to hash of values to labels. The values and labels are the same.

=cut

sub IDHASH {
    my %retVal = map { $_ => $_ } @_;
    return \%retVal;
}

=head3 Pluralize

    my $plural = StringUtils::Pluralize($word);

This is a very simple pluralization utility. It adds an C<s> at the end
of the input word unless it already ends in an C<s>, in which case it
adds C<es>.

=over 4

=item word

Singular word to pluralize.

=item RETURN

Returns the probable plural form of the word.

=back

=cut

sub Pluralize {
    # Get the parameters.
    my ($word) = @_;
    # Declare the return variable.
    my $retVal;
    if ($word =~ /s$/) {
        $retVal = $word . 'es';
    } else {
        $retVal = $word . 's';
    }
    # Return the result.
    return $retVal;
}

=head3 Numeric

    my $okFlag = StringUtils::Numeric($string);

Return the value of the specified string if it is numeric, or an undefined value
if it is not numeric.

=over 4

=item string

String to check.

=item RETURN

Returns the numeric value of the string if successful, or C<undef> if the string
is not numeric.

=back

=cut

sub Numeric {
    # Get the parameters.
    my ($string) = @_;
    # We'll put the value in here if we succeed.
    my $retVal;
    # Get a working copy of the string.
    my $copy = $string;
    # Trim leading and trailing spaces.
    $copy =~ s/^\s+//;
    $copy =~ s/\s+$//;
    # Check the result.
    if ($copy =~ /^[+-]?\d+$/) {
        $retVal = $copy;
    } elsif ($copy =~ /^([+-]\d+|\d*)[eE][+-]?\d+$/) {
        $retVal = $copy;
    } elsif ($copy =~ /^([+-]\d+|\d*)\.\d*([eE][+-]?\d+)?$/) {
        $retVal = $copy;
    }
    # Return the result.
    return $retVal;
}


=head3 ParseParm

    my $listValue = StringUtils::ParseParm($string);

Convert a parameter into a list reference. If the parameter is undefined,
an undefined value will be returned. Otherwise, it will be parsed as a
comma-separated list of values.

=over 4

=item string

Incoming string.

=item RETURN

Returns a reference to a list of values, or C<undef> if the incoming value
was undefined.

=back

=cut

sub ParseParm {
    # Get the parameters.
    my ($string) = @_;
    # Declare the return variable.
    my $retVal;
    # Check for data.
    if (defined $string) {
        # We have some, so split it into a list.
        $retVal = [ split /\s*,\s*/, $string];
    }
    # Return the result.
    return $retVal;
}

=head3 Now

    my $string = StringUtils::Now();

Return a displayable time stamp containing the local time. Whatever format this
method produces must be parseable by L</ParseDate>.

=cut

sub Now {
    return DisplayTime(time);
}

=head3 DisplayTime

    my $string = StringUtils::DisplayTime($time);

Convert a time value to a displayable time stamp. Whatever format this
method produces must be parseable by L</ParseDate>.

=over 4

=item time

Time to display, in seconds since the epoch, or C<undef> if the time is unknown.

=item RETURN

Returns a displayable time, or C<(n/a)> if the incoming time is undefined.

=back

=cut

sub DisplayTime {
    my ($time) = @_;
    my $retVal = "(n/a)";
    if (defined $time) {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
        $retVal = _p2($mon+1) . "/" . _p2($mday) . "/" . ($year + 1900) . " " .
                  _p2($hour) . ":" . _p2($min) . ":" . _p2($sec);
    }
    return $retVal;
}

# Pad a number to 2 digits.
sub _p2 {
    my ($value) = @_;
    $value = "0$value" if ($value < 10);
    return $value;
}

=head3 NameTime

    my $string = StringUtils::NameTime($prefix, $time, $suffix);

Convert a time value to a file name. The three pieces of the file name will be separated by periods.

=over 4

=item prefix

First part of the file name, to precede the time.

=item time

Time to display, in seconds since the epoch, or C<undef> if the time is unknown.

=item suffix

Suffix to put on the file name.

=item RETURN

Returns a file name containing a sortable time stamp. The time stamp will be all zeroes if the incoming time is undefined.

=back

=cut

sub NameTime {
    my ($prefix, $time, $suffix) = @_;
    my $middle = "0000-00-00_00-00-00";
    if (defined $time) {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
        $middle = _p2($year + 1900) . "-" . _p2($mon + 1) . "-" . ($mday) . "_" .
                  _p2($hour) . "-" . _p2($min) . "-" . _p2($sec);
    }
    my $retVal = join(".", $prefix, $middle, $suffix);
    return $retVal;
}

=head3 Escape

    my $codedString = StringUtils::Escape($realString);

Escape a string for use in a command. Tabs will be replaced by C<\t>, new-lines
replaced by C<\n>, carriage returns will be deleted, and backslashes will be doubled.
Non-ascii characters will be converted to x-notation. The result is to reverse the effect
of L</UnEscape>.

=over 4

=item realString

String to escape.

=item RETURN

Escaped equivalent of the real string.

=back

=cut

sub Escape {
    # Get the parameter.
    my ($realString) = @_;
    # Initialize the return variable.
    my $retVal = "";
    # Loop through the parameter string, looking for sequences to escape.
    while (length $realString > 0) {
        # Look for the first sequence to escape.
        if ($realString =~ /^(.*?)([\n\t\r\\\x80-\xff])/) {
            # Here we found it. The text preceding the sequence is in $1. The sequence
            # itself is in $2. First, move the clear text to the return variable.
            $retVal .= $1;
            # Strip the processed section off the real string.
            $realString = substr $realString, (length $2) + (length $1);
            # Get the matched character.
            my $char = $2;
            # If we have a CR, we are done.
            if ($char eq "\n" || $char eq "\t" || $char eq "\\") {
                # It's a tab or new-line, so encode the escape sequence.
                $char =~ tr/\t\n/tn/;
                $retVal .= "\\" . $char;
            } elsif ($char ne "\r") {
                # Here we have a non-ascii character.
                $retVal .= "\\x" . sprintf('%02x', ord $char);
            }
        } else {
            # Here there are no more escape sequences. The rest of the string is
            # transferred unmodified.
            $retVal .= $realString;
            $realString = "";
        }
    }
    # Return the result.
    return $retVal;
}

=head3 UnEscape

    my $realString = StringUtils::UnEscape($codedString);

Replace escape sequences with their actual equivalents. C<\t> will be replaced by
a tab, C<\n> by a new-line character, and C<\\> by a backslash. C<\r> codes will
be deleted.

=over 4

=item codedString

String to un-escape.

=item RETURN

Returns a copy of the original string with the escape sequences converted to their actual
values.

=back

=cut

sub UnEscape {
    # Get the parameter.
    my ($codedString) = @_;
    # Initialize the return variable.
    my $retVal = "";
    # Only proceed if the incoming string is nonempty.
    if (defined $codedString) {
        # Loop through the parameter string, looking for escape sequences. We can't do
        # translating because it causes problems with the escaped slash. ("\\t" becomes
        # "\<tab>" no matter what we do.)
        while (length $codedString > 0) {
            # Look for the first escape sequence.
            if ($codedString =~ /^(.*?)\\([\\ntr]|x[a-fA-F0-9]{2})/) {
                # Here we found it. The text preceding the sequence is in $1. The sequence
                # itself is in $2. First, move the clear text to the return variable.
                $retVal .= $1;
                $codedString = substr $codedString, (1 + length($2) + length($1));
                # Get the escape value.
                my $char = $2;
                # If we have a "\r", we are done.
                if ($char eq 'n' || $char eq 't' || $char eq '\\') {
                    # Here it's not an 'r', so we convert it.
                    $char =~ tr/\\tn/\\\t\n/;
                    $retVal .= $char;
                } elsif ($char ne 'r') {
                    # Here we have a hex code.
                    $retVal .= chr(hex $char);
                }
            } else {
                # Here there are no more escape sequences. The rest of the string is
                # transferred unmodified.
                $retVal .= $codedString;
                $codedString = "";
            }
        }
    }
    # Return the result.
    return $retVal;
}

=head3 Percent

    my $percent = StringUtils::Percent($number, $base);

Returns the percent of the base represented by the given number. If the base
is zero, returns zero.

=over 4

=item number

Percent numerator.

=item base

Percent base.

=item RETURN

Returns the percentage of the base represented by the numerator.

=back

=cut

sub Percent {
    # Get the parameters.
    my ($number, $base) = @_;
    # Declare the return variable.
    my $retVal = 0;
    # Compute the percent.
    if ($base != 0) {
        $retVal = $number * 100 / $base;
    }
    # Return the result.
    return $retVal;
}

=head3 In

    my $flag = StringUtils::In($value, $min, $max);

Return TRUE if the value is between the minimum and the maximum, else FALSE.

=cut

sub In {
    return ($_[0] <= $_[2] && $_[0] >= $_[1]);
}


=head3 Constrain

    my $constrained = Constrain($value, $min, $max);

Modify a numeric value to bring it to a point in between a maximum and a minimum.

=over 4

=item value

Value to constrain.

=item min (optional)

Minimum permissible value. If this parameter is undefined, no minimum constraint will be applied.

=item max (optional)

Maximum permissible value. If this parameter is undefined, no maximum constraint will be applied.

=item RETURN

Returns the incoming value, constrained according to the other parameters.

=back

=cut

sub Constrain {
    # Get the parameters.
    my ($value, $min, $max) = @_;
    # Declare the return variable.
    my $retVal = $value;
    # Apply the minimum constraint.
    if (defined $min && $retVal < $min) {
        $retVal = $min;
    }
    # Apply the maximum constraint.
    if (defined $max && $retVal > $max) {
        $retVal = $max;
    }
    # Return the result.
    return $retVal;
}

=head3 Min

    my $min = Min($value1, $value2, ... $valueN);

Return the minimum argument. The arguments are treated as numbers.

=over 4

=item $value1, $value2, ... $valueN

List of numbers to compare.

=item RETURN

Returns the lowest number in the list.

=back

=cut

sub Min {
    # Get the parameters. Note that we prime the return value with the first parameter.
    my ($retVal, @values) = @_;
    # Loop through the remaining parameters, looking for the lowest.
    for my $value (@values) {
        if ($value < $retVal) {
            $retVal = $value;
        }
    }
    # Return the minimum found.
    return $retVal;
}

=head3 Max

    my $max = Max($value1, $value2, ... $valueN);

Return the maximum argument. The arguments are treated as numbers.

=over 4

=item $value1, $value2, ... $valueN

List of numbers to compare.

=item RETURN

Returns the highest number in the list.

=back

=cut

sub Max {
    # Get the parameters. Note that we prime the return value with the first parameter.
    my ($retVal, @values) = @_;
    # Loop through the remaining parameters, looking for the highest.
    for my $value (@values) {
        if ($value > $retVal) {
            $retVal = $value;
        }
    }
    # Return the maximum found.
    return $retVal;
}

=head3 Strip

    my $string = StringUtils::Strip($line);

Strip all line terminators off a string. This is necessary when dealing with files
that may have been transferred back and forth several times among different
operating environments.

=over 4

=item line

Line of text to be stripped.

=item RETURN

The same line of text with all the line-ending characters chopped from the end.

=back

=cut

sub Strip {
    # Get a copy of the parameter string.
    my ($string) = @_;
    my $retVal = (defined $string ? $string : "");
    # Strip the line terminator characters.
    $retVal =~ s/(\r|\n)+$//g;
    # Return the result.
    return $retVal;
}

=head3 Trim

    my $string = StringUtils::Trim($line);

Trim all spaces from the beginning and ending of a string.

=over 4

=item line

Line of text to be trimmed.

=item RETURN

The same line of text with all whitespace chopped off either end.

=back

=cut

sub Trim {
    # Get a copy of the parameter string.
    my ($string) = @_;
    my $retVal = (defined $string ? $string : "");
    # Strip the front spaces.
    $retVal =~ s/^\s+//;
    # Strip the back spaces.
    $retVal =~ s/\s+$//;
    # Return the result.
    return $retVal;
}

=head3 Pad

    my $paddedString = StringUtils::Pad($string, $len, $left, $padChar);

Pad a string to a specified length. The pad character will be a
space, and the padding will be on the right side unless specified
in the third parameter.

=over 4

=item string

String to be padded.

=item len

Desired length of the padded string.

=item left (optional)

TRUE if the string is to be left-padded; otherwise it will be padded on the right.

=item padChar (optional)

Character to use for padding. The default is a space.

=item RETURN

Returns a copy of the original string with the pad character added to the
specified end so that it achieves the desired length.

=back

=cut

sub Pad {
    # Get the parameters.
    my ($string, $len, $left, $padChar) = @_;
    # Compute the padding character.
    if (! defined $padChar) {
        $padChar = " ";
    }
    # Compute the number of spaces needed.
    my $needed = $len - length $string;
    # Copy the string into the return variable.
    my $retVal = $string;
    # Only proceed if padding is needed.
    if ($needed > 0) {
        # Create the pad string.
        my $pad = $padChar x $needed;
        # Affix it to the return value.
        if ($left) {
            $retVal = $pad . $retVal;
        } else {
            $retVal .= $pad;
        }
    }
    # Return the result.
    return $retVal;
}

=head3 Quoted

    my $string = StringUtils::Quoted($var);

Convert the specified value to a string and enclose it in single quotes.
If it's undefined, the string C<undef> in angle brackets will be used
instead.

=over 4

=item var

Value to quote.

=item RETURN

Returns a string enclosed in quotes, or an indication the value is undefined.

=back

=cut

sub Quoted {
    # Get the parameters.
    my ($var) = @_;
    # Declare the return variable.
    my $retVal;
    # Are we undefined?
    if (! defined $var) {
        $retVal = "<undef>";
    } else {
        # No, so convert to a string and enclose in quotes.
        $retVal = $var;
        $retVal =~ s/'/\\'/;
        $retVal = "'$retVal'";
    }
    # Return the result.
    return $retVal;
}

=head3 EOF

This is a constant that is lexically greater than any useful string.

=cut

sub EOF {
    return "\xFF\xFF\xFF\xFF\xFF";
}

=head3 TICK

    my @results = TICK($commandString);

Perform a back-tick operation on a command. If this is a Windows environment, any leading
dot-slash (C<./> will be removed. So, for example, if you were doing

    `./protein.cgi`

from inside a CGI script, it would work fine in Unix, but would issue an error message
in Windows complaining that C<'.'> is not a valid command. If instead you code

    TICK("./protein.cgi")

it will work correctly in both environments.

=over 4

=item commandString

The command string to pass to the system.

=item RETURN

Returns the standard output from the specified command, as a list.

=back

=cut
#: Return Type @;
sub TICK {
    # Get the parameters.
    my ($commandString) = @_;
    # Chop off the dot-slash if this is Windows.
    if ($FIG_Config::win_mode) {
        $commandString =~ s!^\./!!;
    }
    # Activate the command and return the result.
    return `$commandString`;
}


=head3 CommaFormat

    my $formatted = StringUtils::CommaFormat($number);

Insert commas into a number.

=over 4

=item number

A sequence of digits.

=item RETURN

Returns the same digits with commas strategically inserted.

=back

=cut

sub CommaFormat {
    # Get the parameters.
    my ($number) = @_;
    # Pad the length up to a multiple of three.
    my $padded = "$number";
    $padded = " " . $padded while length($padded) % 3 != 0;
    # This is a fancy PERL trick. The parentheses in the SPLIT pattern
    # cause the delimiters to be included in the output stream. The
    # GREP removes the empty strings in between the delimiters.
    my $retVal = join(",", grep { $_ ne '' } split(/(...)/, $padded));
    # Clean out the spaces.
    $retVal =~ s/ //g;
    # Return the result.
    return $retVal;
}


=head3 CompareLists

    my ($inserted, $deleted) = StringUtils::CompareLists(\@newList, \@oldList, $keyIndex);

Compare two lists of tuples, and return a hash analyzing the differences. The lists
are presumed to be sorted alphabetically by the value in the $keyIndex column.
The return value contains a list of items that are only in the new list
(inserted) and only in the old list (deleted).

=over 4

=item newList

Reference to a list of new tuples.

=item oldList

Reference to a list of old tuples.

=item keyIndex (optional)

Index into each tuple of its key field. The default is 0.

=item RETURN

Returns a 2-tuple consisting of a reference to the list of items that are only in the new
list (inserted) followed by a reference to the list of items that are only in the old
list (deleted).

=back

=cut

sub CompareLists {
    # Get the parameters.
    my ($newList, $oldList, $keyIndex) = @_;
    if (! defined $keyIndex) {
        $keyIndex = 0;
    }
    # Declare the return variables.
    my ($inserted, $deleted) = ([], []);
    # Loop through the two lists simultaneously.
    my ($newI, $oldI) = (0, 0);
    my ($newN, $oldN) = (scalar @{$newList}, scalar @{$oldList});
    while ($newI < $newN || $oldI < $oldN) {
        # Get the current object in each list. Note that if one
        # of the lists is past the end, we'll get undef.
        my $newItem = $newList->[$newI];
        my $oldItem = $oldList->[$oldI];
        if (! defined($newItem) || defined($oldItem) && $newItem->[$keyIndex] gt $oldItem->[$keyIndex]) {
            # The old item is not in the new list, so mark it deleted.
            push @{$deleted}, $oldItem;
            $oldI++;
        } elsif (! defined($oldItem) || $oldItem->[$keyIndex] gt $newItem->[$keyIndex]) {
            # The new item is not in the old list, so mark it inserted.
            push @{$inserted}, $newItem;
            $newI++;
        } else {
            # The item is in both lists, so push forward.
            $oldI++;
            $newI++;
        }
    }
    # Return the result.
    return ($inserted, $deleted);
}

=head3 Cmp

    my $cmp = StringUtils::Cmp($a, $b);

This method performs a universal sort comparison. Each value coming in is
separated into a text parts and number parts. The text
part is string compared, and if both parts are equal, then the number
parts are compared numerically. A stream of just numbers or a stream of
just strings will sort correctly, and a mixed stream will sort with the
numbers first. Strings with a label and a number will sort in the
expected manner instead of lexically. Undefined values sort last.

=over 4

=item a

First item to compare.

=item b

Second item to compare.

=item RETURN

Returns a negative number if the first item should sort first (is less), a positive
number if the first item should sort second (is greater), and a zero if the items are
equal.

=back

=cut

sub Cmp {
    # Get the parameters.
    my ($a, $b) = @_;
    # Declare the return value.
    my $retVal;
    # Check for nulls.
    if (! defined($a)) {
        $retVal = (! defined($b) ? 0 : -1);
    } elsif (! defined($b)) {
        $retVal = 1;
    } else {
        # Here we have two real values. Parse the two strings.
        my @aParsed = _Parse($a);
        my @bParsed = _Parse($b);
        # Loop through the first string.
        while (! $retVal && @aParsed) {
            # Extract the string parts.
            my $aPiece = shift(@aParsed);
            my $bPiece = shift(@bParsed) || '';
            # Extract the number parts.
            my $aNum = shift(@aParsed);
            my $bNum = shift(@bParsed) || 0;
            # Compare the string parts insensitively.
            $retVal = (lc($aPiece) cmp lc($bPiece));
            # If they're equal, compare them sensitively.
            if (! $retVal) {
                $retVal = ($aPiece cmp $bPiece);
                # If they're STILL equal, compare the number parts.
                if (! $retVal) {
                    $retVal = $aNum <=> $bNum;
                }
            }
        }
    }
    # Return the result.
    return $retVal;
}

# This method parses an input string into a string parts alternating with
# number parts.
sub _Parse {
    # Get the incoming string.
    my ($string) = @_;
    # The pieces will be put in here.
    my @retVal;
    # Loop through as many alpha/num sets as we can.
    while ($string =~ /^(\D*)(\d+)(.*)/) {
        # Push the alpha and number parts into the return string.
        push @retVal, $1, $2;
        # Save the residual.
        $string = $3;
    }
    # If there's still stuff left, add it to the end with a trailing
    # zero.
    if ($string) {
        push @retVal, $string, 0;
    }
    # Return the list.
    return @retVal;
}

=head3 ListEQ

    my $flag = StringUtils::ListEQ(\@a, \@b);

Return TRUE if the specified lists contain the same strings in the same
order, else FALSE.

=over 4

=item a

Reference to the first list.

=item b

Reference to the second list.

=item RETURN

Returns TRUE if the two parameters are identical string lists, else FALSE.

=back

=cut

sub ListEQ {
    # Get the parameters.
    my ($a, $b) = @_;
    # Declare the return variable. Start by checking the lengths.
    my $n = scalar(@$a);
    my $retVal = ($n == scalar(@$b));
    # Now compare the list elements.
    for (my $i = 0; $retVal && $i < $n; $i++) {
        $retVal = ($a->[$i] eq $b->[$i]);
    }
    # Return the result.
    return $retVal;
}

=head3 Clean

    my $cleaned = StringUtils::Clean($string);

Clean up a string for HTML display. This not only converts special
characters to HTML entity names, it also removes control characters.

=over 4

=item string

String to convert.

=item RETURN

Returns the input string with anything that might disrupt an HTML literal removed. An
undefined value will be converted to an empty string.

=back

=cut

sub Clean {
    # Get the parameters.
    my ($string) = @_;
    # Declare the return variable.
    my $retVal = "";
    # Only proceed if the value exists.
    if (defined $string) {
        # Get the string.
        $retVal = $string;
        # Clean the control characters.
        $retVal =~ tr/\x00-\x1F/?/;
        # Escape the rest.
        $retVal = CGI::escapeHTML($retVal);
    }
    # Return the result.
    return $retVal;
}

=head3 SortByValue

    my @keys = StringUtils::SortByValue(\%hash);

Get a list of hash table keys sorted by hash table values.

=over 4

=item hash

Hash reference whose keys are to be extracted.

=item RETURN

Returns a list of the hash keys, ordered so that the corresponding hash values
are in alphabetical sequence.

=back

=cut

sub SortByValue {
    # Get the parameters.
    my ($hash) = @_;
    # Sort the hash's keys using the values.
    my @retVal = sort { Cmp($hash->{$a}, $hash->{$b}) } keys %$hash;
    # Return the result.
    return @retVal;
}

=head3 GetSet

    my $value = StringUtils::GetSet($object, $name => $newValue);

Get or set the value of an object field. The object is treated as an
ordinary hash reference. If a new value is specified, it is stored in the
hash under the specified name and then returned. If no new value is
specified, the current value is returned.

=over 4

=item object

Reference to the hash that is to be interrogated or updated.

=item name

Name of the field. This is the hash key.

=item newValue (optional)

New value to be stored in the field. If no new value is specified, the current
value of the field is returned.

=item RETURN

Returns the value of the named field in the specified hash.

=back

=cut

sub GetSet {
    # Get the parameters.
    my ($object, $name, $newValue) = @_;
    # Is a new value specified?
    if (defined $newValue) {
        # Yes, so store it.
        $object->{$name} = $newValue;
    }
    # Return the result.
    return $object->{$name};
}

1;
