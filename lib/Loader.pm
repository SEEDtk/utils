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


package Loader;

    use strict;
    use warnings;
    use Stats;

=head1 Loader Utility Object

This object provides useful utilities for loader scripts. These generally
involve reading and writing sequential or FASTA files and tracking
statistical information.

The fields in this object are as follows.

=over 4

=item stats

A L<Stats> object for tracking input/output activity.

=back

=head2 Special Methods

=head3 new

    my $loader = Loader->new();

Create a new, blank loader object.

=cut

sub new {
    # Get the parameters.
    my ($class) = @_;
    # Create the object
    my $retVal = { stats => Stats->new() };
    # Bless and return it.
    bless $retVal, $class;
    return $retVal;
}


=head2 Access Methods

=head3 stats

    my $stats = $loader->stats;

Return the statistics object.

=cut

sub stats {
    my ($self) = @_;
    return $self->{stats};
}


=head2 File Utility Methods

=head3 OpenDir

    my @files = Loader::OpenDir($dirName, $filtered, $flag);

or

     my @files = $loader->OpenDir($dirName, $filtered, $flag);

Open a directory and return all the file names. This function essentially performs
the functions of an C<opendir> and C<readdir>. If the I<$filtered> parameter is
set to TRUE, all filenames beginning with a period (C<.>), dollar sign (C<$>),
or pound sign (C<#>) and all filenames ending with a tilde C<~>) will be
filtered out of the return list. If the directory does not open and I<$flag> is not
set, an exception is thrown. So, for example,

    my @files = OpenDir("/Volumes/fig/contigs", 1);

is effectively the same as

    opendir(TMP, "/Volumes/fig/contigs") || die("Could not open /Volumes/fig/contigs.");
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

sub OpenDir {
    # Convert the instance-style call to a direct call.
    shift if UNIVERSAL::isa($_[0],__PACKAGE__);
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
        die "Could not open directory $dirName.";
    }
    # Return the result.
    return @retVal;
}

=head3 GetNamesFromFile

    my $names = $loader->GetNamesFromFile($type => $fileName);

Read the names or IDs found in the first column of the specified tab-delimited file.

=over 4

=item type

The type of name found in the file. This must be a singular noun and will be used in error messages and
statistics.

=item fileName

Name of the file to read.

=item RETURN

Returns a reference to a list of names taken from the first column of each record in the file.

=back

=cut

sub GetNamesFromFile {
    # Get the parameters.
    my ($self, $type, $fileName) = @_;
    # Get the statistics object.
    my $stats = $self->{stats};
    # Open the file for input.
    open(my $ih, "<$fileName") || die "Could not open $type input file $fileName: $!";
    # We will put the names in here.
    my @retVal;
    # Loop through the file records.
    while (! eof $ih) {
        my $line = <$ih>;
        chomp $line;
        my ($name) = split /\t/, $line;
        # Ignore empty values.
        if (defined $name && $name ne "") {
            push @retVal, $name;
            $stats->Add("$type-in" => 1);
        }
    }
    # Return the list of names.
    return \@retVal;
}

=head3 OpenFasta

    my $fh = $loader->OpenFasta($type => $fileName);

Open a FASTA file for input. This returns an object that can be passed to L</GetLine> as a file handle.

=over 4

=item type

Type of sequence in the file. This must be a singular noun, and will be used in error messages and statistics.

=item fileName

Name of the FASTA file to open.

=item RETURN

Returns an object (in this case an array reference containing (0) the file handle, (1) the ID, and (2) the comment)
that can be passed to L</GetLine> to read from the FASTA.

=back

=cut

sub OpenFasta {
    # Get the parameters.
    my ($self, $type, $fileName) = @_;
    # Get the statistics object.
    my $stats = $self->{stats};
    # Open the file for input.
    open(my $ih, "<$fileName") || die "Could not open $type FASTA file: $!";
    $stats->Add("$type-file" => 1);
    # This will be our return list.
    my @retVal = ($ih);
    # Is the file empty?
    if (! eof $ih) {
        # No, read the first line.
        my $line = <$ih>;
        chomp $line;
        if ($line =~ /^>(\S*)\s*(.*)/) {
            # Here we have a valid header. Save the ID and comment.
            push @retVal, $1, $2;
        } else {
            # Here we do not have a valid header.
            die "Invalid header in FASTA file $fileName.";
        }
    }
    # Return the file descriptor.
    return \@retVal;
}

=head3 OpenFile

    my $ih = $loader->OpenFile($type => $fileName);

Open the specified file for input. If the file does not open, an error will be thrown.

=over 4

=item type

The type of record found in the file. This must be a singular noun, and will be used in error messages and
statistics.

=item fileName

Name of the file to open.

=item RETURN

Returns an open file handle.

=back

=cut

sub OpenFile {
    # Get the parameters.
    my ($self, $type, $fileName) = @_;
    # Get the statistics object.
    my $stats = $self->{stats};
    # Open the file for input.
    open(my $retVal, "<$fileName") || die "Could not open $type file $fileName: $!";
    $stats->Add("$type-file" => 1);
    # Return the handle.
    return $retVal;
}

=head3 GetLine

    my $fields = $loader->GetLine($type => $ih);

Read a line of data from an open tab-delimited or FASTA file.

=over 4

=item type

The type of record found in the file. This must be a singular noun, and will be used in error messages and
statistics.

=item ih

Open input handle for the file or a FASTA object returned from L</OpenFasta>.

=item RETURN

Returns a reference to a list of the tab-separated fields in the current line of the file, or C<undef>
if end-of-file was read.

=back

=cut

sub GetLine {
    # Get the parameters.
    my ($self, $type, $ih) = @_;
    # Get the statistics object.
    my $stats = $self->{stats};
    # The fields read will be put in here.
    my $retVal;
    # The data line will be put in here.
    my $line;
    # Determine the type of operation.
    if (ref $ih ne 'ARRAY') {
        # Here we have a tab-delimited file. Do we have a line of data?
        if (! eof $ih) {
            # Yes, Extract the fields.
            $line = <$ih>;
            chomp $line;
            $stats->Add("$type-lineIn" => 1);
            $retVal = [split /\t/, $line];
        }
    } else {
        # Here we have a FASTA file. Get the FASTA information.
        my ($fh, $id, $comment) = @$ih;
        # Only proceed if we are not already past end-of-file.
        if (defined $id) {
            # Here we are positioned on a data line. Loop until we
            # run out of data lines and hit a header.
            my @data;
            my $header = 0;
            while (! eof $fh && ! $header) {
                $line = <$fh>;
                chomp $line;
                $stats->Add("$type-lineIn" => 1);
                if (substr($line, 0, 1) eq '>') {
                    # Here we have a header.
                    $header = 1;
                } else {
                    # More data. Save it.
                    push @data, $line;
                }
            }
            # Here we are at the start of a new record. Output the old one.
            $retVal = [$id, $comment, join("", @data)];
            $stats->Add("$type-fastaRecord" => 1);
            # If there is another record coming, set up for it.
            if ($header) {
                $line =~ /^>(\S*)\s*(.*)/;
                @{$ih}[1, 2] = ($1, $2);
            } else {
                # End-of-file. Insure we know it.
                @{$ih}[1, 2] = (undef, "");
            }
        }
    }
    # Return the line.
    return $retVal;
}

=head3 PutLine

    $loader->PutLine($type => $oh, @fields);

Write a tab-delimited line to an output file.

=over 4

=item type

Type of data being written, for statistical tracking.

=item $oh

Open output file handle. If C<undef>, then the write will be suppressed.

=item @fields

List of fields to write to the output.

=back

=cut

sub PutLine {
    # Get the parameters.
    my ($self, $type, $oh, @fields) = @_;
    # Get the statistics object.
    my $stats = $self->stats;
    # Are we writing?
    if (! defined $oh) {
        # No. Skip the line.
        $stats->Add("$type-line-suppressed" => 1);
    } else {
        # Yes. Write the line.
        print $oh join("\t", @fields) . "\n";
        $stats->Add("$type-line-out" => 1);
    }
}


=head3 ReadMetaData

    my $metaHash = $loader->ReadMetaData($fileName, %options);

Read a metadata file into a hash. A metadata file contains keywords and values, one pair per line, using a single
colon as a field separator.

=over 4

=item fileName

Name of the metadata file to read.

=item options

Hash of options. The valid keywords are

=over 8

=item required

Maps to a list reference of required keywords. If one of the keywords is not found in the metadata file,
an error will occur.

=back

=item RETURN

Returns a reference to a hash that maps each keyword in the metadata file to its value.

=back

=cut

sub ReadMetaData {
    # Get the parameters.
    my ($self, $fileName, %options) = @_;
    # Get the statistics object.
    my $stats = $self->{stats};
    # Open the file for input.
    my $ih = $self->OpenFile(metadata => $fileName);
    # Read each line and parse into the return hash.
    my %retVal;
    while (! eof $ih) {
        my $line = <$ih>;
        $stats->Add('metadata-line' => 1);
        chomp $line;
        if ($line =~ /^([^:]+):(.+)/) {
            $retVal{$1} = $2;
        } else {
            die "Invalid line in metadata file $fileName.";
        }
    }
    # If there are required keywords, check for them here.
    my $list = $options{required};
    if (defined $list) {
        # Insure we have a list of keywords.
        if (ref $list ne 'ARRAY') {
            $list = [$list];
        }
        # Loop through the required keywords.
        for my $key (@$list) {
            if (! defined $retVal{$key}) {
                die "Missing required keyword $key in metadata file $fileName.";
            }
        }
    }
    # Return the hash of key-value pairs.
    return \%retVal;
}

=head3 WriteMetaData

    $loader->WriteMetaData($fileName, \%metaHash);

Write the metadata specified by a hash to the specified file.

=over 4

=item fileName

Name of the file to which the metadata should be written.

=item metaHash

Hash containing the key-value pairs to be output to the file. For each entry in the hash,
a line will be written to the output file containing the key and the value, colon-separated.

=back

=cut

sub WriteMetaData {
    # Get the parameters.
    my ($self, $fileName, $metaHash) = @_;
    # Get the statistics object.
    my $stats = $self->{stats};
    # Open the output file.
    open(my $oh, ">$fileName") || die "Could not open metadata output file $fileName: $!";
    $stats->Add(metaFileOut => 1);
    # Loop through the hash, writing key/value lines.
    for my $key (sort keys %$metaHash) {
        my $value = $metaHash->{$key};
        print $oh "$key:$value\n";
        $stats->Add(metaLineOut => 1);
    }
    # Close the output file.
    close $oh;
}

=head3 WriteBlank

    $loader->WriteBlank($type => $fileName);

Create an empty file.

=over 4

=item type

The type of file, used in statistics and error messages.

=item fileName

The name of the blank file to create.

=back

=cut

sub WriteBlank {
    # Get the parameters.
    my ($self, $type, $fileName) = @_;
    # Open the file for output.
    open(my $oh, ">$fileName") || die "Could not create $type output file: $!";
    # Blank and close the file.
    print $oh "";
    close $oh;
    $self->stats->Add('blank-$type-created' => 1);
}

=head3 GetDNA

    my $seqHash = $loader->GetDNA($locHash, $fastaFile);

Extract the DNA from a FASTA file. Each DNA sequence is identified by a key and a location. The incoming hash maps keys
to L<BasicLocation> objects; the output hash will map keys to DNA sequences.

=over 4

=item locHash

Reference to a hash mapping identifiers to L<BasicLocation> objects indicating DNA locations.

=item fastaFile

The name of a FASTA file containing the source DNA.

=item RETURN

Returns a hash mapping the identifiers to DNA sequences.

=back

=cut

sub GetDNA {
    my ($self, $locHash, $fastaFile) = @_;
    # This will be the return hash.
    my %retVal;
    # Sort the locations by contig.
    my %contigHash;
    for my $id (keys %$locHash) {
        my $loc = $locHash->{$id};
        push @{$contigHash{$loc->Contig}}, $id;
    }
    # This will count the number of contigs we need to process.
    my $contigCount = scalar keys %contigHash;
    # Loop through the contigs in the FASTA file.
    my $fh = $self->OpenFasta(dnaInput => $fastaFile);
    while ($contigCount && (my $fields = $self->GetLine(dnaInput => $fh))) {
        my ($contig, undef, $seq) = @$fields;
        if (exists $contigHash{$contig}) {
            # We have locations in this contig. Loop through their IDs.
            my $idList = $contigHash{$contig};
            for my $id (@$idList) {
                # Get the location's sequence. Note we do a reverse compliment for the minus strand.
                my $loc = $locHash->{$id};
                my $subSeq = substr($seq, $loc->Left - 1, $loc->Length);
                if ($loc->Dir eq '-') {
                    SeedUtils::rev_comp(\$subSeq);
                }
                $retVal{$id} = $subSeq;
            }
            # Denote we've processed another contig.
            $contigCount--;
        }
    }
    # Return the sequence hash.
    return \%retVal;
}

1;
