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


package SeedAware;

    use strict;
    use warnings;
    eval { ## Insure we compile under kBase.
        require IPC::Run3;
    };
    use File::Spec;
    use File::Temp;
    use FIG_Config;
    use StringUtils;

=head1 Operating System Access Methods

This package provides methods for accessing the operating system. It is a not quite a drop-in
replacement for the old SeedAware module from the SEED.  In addition, it is not prepared to run
outside the SEEDtk world. At some point in the future, when I'm not under a crushing deadline,
this can be corrected.

=head2 Public Methods

=head3 executable_for

    my $exeWithPath = SeedAware::executable_for($programName);

Find the location of the specified program in the execution path and return the fully-qualified
name.

=over 4

=item programName

Name of the program to find.

=item RETURN

Returns the full path to the executable, or C<undef> if the program is not found.

=back

=cut

sub executable_for {
    # Get the parameters.
    my ($programName) = @_;
    # These variables will contain the path delimiter and the list of suffixes to check.
    my ($delim, @suffixes);
    if ($FIG_Config::win_mode) {
        $delim = ';';
        @suffixes = split /;/, $ENV{PATHEXT};
    } else {
        $delim = ':';
        @suffixes = ('');
    }
    # Loop through the tool and path directories.
    my ($retVal, $path);
    my @paths = split $delim, $ENV{PATH};
    push @paths, @FIG_Config::tools;
    while (! $retVal && defined($path = pop @paths)) {
        # Form the execution name.
        my $testName = File::Spec->catfile($path, $programName);
        # Check it with all the suffixes.
        if (grep { -f "$testName$_" } @suffixes) {
            # We found it, so return the full name.
            $retVal = $testName;
        }
    }
    # Return the result.
    return $retVal;
}


=head3 location_of_tmp

    my $dirName = SeedAware::location_of_tmp(\%options);

Return the name of a directory in which temporary files can be written. The first choice is the
directory specified in the C<tmp> member of the incoming options hash and the second choice is the
value of B<$FIG_Config::temp>.

=over 4

=item options (optional)

Reference to a hash. If specified, the C<tmp> member will be interrogated to determine a possible
candidate directory.

=item RETURN

Returns the name of a writable directory suitable for temporary files.

=back

=cut

sub location_of_tmp {
    # Get the parameters.
    my ($options) = @_;
    # The name of the directory found will be put in here.
    my $retVal;
    # Check for a supplied option.
    if (! $options && $options->{tmp}) {
        $retVal = $options->{tmp};
    } else {
        $retVal = $FIG_Config::temp;
    }
    if (! -d $retVal || ! -w $retVal) {
        Confess("Invalid temp directory $retVal.");
    }
    # Return the directory found.
    return $retVal;
}


=head3 tmp_file

    my $fileName = SeedAware::tmp_file($base, $ext, $dir);

or

    my ($fh, $fileName) = SeedAware::tmp_file($base, $ext, $dir);

Create a temporary file name. The file name will be formed from the specified base name with
the specified extension in the specified directory.  All three arguments are optional. The
preferred method is to ask for both a file handle and name, which you do by specifying a list
return; however, if you specify a scalar return, only a file name will be returned and the file
will not be opened.

=over 4

=item base (optional)

Base name of the file. This will be suffixed with random letters to make the name unique.

=item ext (optional)

Extension for the file name. This defaults to C<tmp>.

=item dir (optional)

Target directory for the file. This defaults to the value of B<$FIG_Config::temp>.

=item RETURN

In list context, return an open output file handle and the name of a file owned by this process.
In scalar context, returns just the file name.

=back

=cut

sub tmp_file {
    # Get the parameters.
    my ($base, $ext, $dir) = @_;
    # This will be the return file name.
    my $retVal;
    # This will be the return file handle (if any).
    my $fh;
    # Handle defaults.
    $base //= 'temp';
    $ext //= 'tmp';
    $dir //= $FIG_Config::temp;
    # Create the file name. Note we turn off warnings because we may not be opening the file here.
    local $^W = 0;
    ($fh, $retVal) = File::Temp::tempfile($base . "XXXXXXXX", SUFFIX => ".$ext", OPEN => wantarray, DIR => $dir);
    # Return the file name computed and possibly the handle.
    if (wantarray) {
        return ($fh, $retVal);
    } else {
        return $retVal;
    }
}

=head3 open_tmp_file

    my ($fh, $fileName) = SeedAware::open_tmp_file($base, $ext, $dir);

This is a legacy interface to L<tmp_file> that always returns an open output file handle.

=cut

sub open_tmp_file {
    my ($base, $ext, $dir) = @_;
    my @retVal = tmp_file($base, $ext, $dir);
    return @retVal;
}

=head3 tmp_file_name

    my $fileName = SeedAware::tmp_file_name($base, $ext, $dir);

This is a legacy interface to L</tmp_file> that always returns the name of an unopened file.

=cut
sub tmp_file_name {
    my ($base, $ext, $dir) = @_;
    my $retVal = tmp_file($base, $ext, $dir);
    return $retVal;
}


=head3 temporary_directory

    my ($tmp_dir, $save_dir) = SeedAware::temporary_directory(\%options);

Create a temporary directory, with various options.

=over 4

=item options (optional)

Reference to a hash containing various options for naming or creating the directory.

=over 8

=item base

Base string for the directory name. Random characters will be added at the end to make
it unique.

=item name

Exact name to give the directory. Overrides C<base>.

=item save_dir

If TRUE, the caller will be told not to delete the directory at end of session.
If omitted, the caller will be told to keep the directory if it already existed
and to delete it otherwise.

=item tmp

Name of the directory in which the new temporary directory should be placed. If
omitted, the value of B<$FIG_Config::temp> is used.

=item tmp_dir

Full path of the new directory. If specified, overrides C<name>, C<tmp>, and C<base>.

=back

=item RETURN

Returns a list containing (0) the name of the new directory and (1) a boolean that is
TRUE if the directory should be kept at end-of-session and FALSE otherwise.

=back

=cut

sub temporary_directory {
    # Get the parameters.
    my ($options) = @_;
    $options //= {};
    # Allow legacy versions of "save_dir".
    my $save_dir = $options->{save_dir} // $options->{savedir};
    # Look for a caller-supplied value.
    my $retVal = $options->{tmp_dir} // $options->{tmpdir};
    # Set save_dir if the user didn't.
    if (! defined $save_dir && $retVal) {
        $save_dir = (-d $retVal ? 1 : 0);
    }
    # Only proceed if the user didn't give us a name.
    if (! $retVal) {
        # Get the parent directory name.
        my $parent = location_of_tmp($options);
        # Do we have a name?
        if ($options->{name}) {
            # Yes. Use it to form the directory name.
            $retVal = File::Spec->catfile($parent, $options->{name});
            if (! defined $save_dir) {
                $save_dir = (-d $retVal ? 1 : 0);
            }
        } else {
            # No. Form a pattern from the base.
            my $pattern = ($options->{base} // 'temp_') . "XXXXXXXX";
            # Create the directory.
            $retVal = File::Temp::tempdir($pattern, DIR => $parent);
            if (! defined $save_dir) {
                $save_dir = 0;
            }
        }
    }
    # Return the results.
    return ($retVal, $save_dir);
}


=head3 run_redirected

    my $rc = run_redirected($command, @parms, \%redirects);

Run a command with optional output and input redirection. The default action of this method
is to send all output into oblivion (C</dev/null> on Unix) and have no input. This behavior
can be overridden by specifying a value in the redirect hash for one of the three standard
files. The caller can specify a file name, in which case the file name is opened for the
appropriate direction, a scalar reference, in which case the data is read from or written
to the scalar, or a file handle, in which case the file handle is used. Thus

    my $rc = run_redirected('AnalyzeGenomes', { stdin => \$genomes, stdout => 'Data/genomeData.tbl' });

would take the genome list from the variable I<$genomes>, write the output data to C<Data/genomeData.tbl>,
and ignore the error output. Similarly,

    my $rc = run_redirected('AnalyzeGenomes', { stdin => $opt->genomes, stdout => \$analysis, stderr => \*STDERR });

reads the genome list from the file name given in the value of the C<$opt->genomes> expression, writes it
into the scalar variable I<$analysis>, and sends the error output to the current process's error output stream.

=over 4

=item command

Command to execute.

=item parms

List containing the command parameters.

=item redirects (optional)

Reference to a hash containing zero or more of the following options for file redirection. Redirects
that are not specified default to oblivion (that is, instant end-of-file on input, discarding on output).

=item RETURN

Returns the status code from the execution of the command.

=back

=head4 IMPORTANT NOTE

B<TO IMPROVE DEBUGGING POSSIBILITIES, ONLY USE THIS METHOD FOR EXTERNAL TOOLS>. For file system functions,
use one of the Perl C<File> modules, such as L<File::Copy> or L<File::Copy::Recursive>. For internal scripts,
call the script's processing module so you can step through the code. In general, when something goes wrong
in the command invoked by this method, you will be clueless.

As a precaution, if the C<STK_TYPE> environment variable is not defined, it is presumed you are running in a
debug situation, and standard error will default to the parent process standard error output instead.

=cut

sub run_redirected {
    # Get the parameters.
    my ($command, @parms) = @_;
    # Check for a redirection hash.
    my $redirects;
    if (@parms && ref $parms[$#parms] eq 'HASH') {
        $redirects = pop @parms;
    } else {
        $redirects = {};
    }
    # Compute the redirects.
    my $stdin = $redirects->{stdin} // \undef;
    my $stdout = $redirects->{stdout} // \undef;
    my $stderr = $redirects->{stderr} // ($ENV{STK_TYPE} ? \undef : undef);
    # Execute the command.
    IPC::Run3::run3([$command, @parms], $stdin, $stdout, $stderr);
    # Return the exit code. Note we stash it in $retVal so that during debugging the programmer
    # can see it in a breakpoint trace.
    my $retVal =  $?;
    return $retVal;
}

=head3 run_gathering_output

    my $lines = SeedAware::run_gathering_output($command, @parms);

or

    my @lines = SeedAware::run_gathering_output($command, @parms);

Run a command, returning the output in a list or string.

=over 4

=item command

Command to execute.

=item parms

List containing the command parameters.

=item RETURN

In scalar context, returns a string containing the standard output. In list context, returns a list
containing each line of the standard output.

=back

=cut

sub run_gathering_output {
    # Get the parameters.
    my ($command, @parms) = @_;
    # This will be the return variable.
    my $retVal;
    # Invoke the command.
    run_redirected($command, @parms, { stdout => \$retVal });
    # Return the result.
    if (wantarray) {
        return split /\n/, $retVal;
    } else {
        return $retVal;
    }
}


=head3 system_with_redirect

This is a marker method so we can find which calls we haven't converted to the new format. Since the
parameters are different, the calls have to be modified individually.

=cut

sub system_with_redirect {
    Confess("system_with_redirect is no longer supported. Use run_redirected instead.");
}

1;