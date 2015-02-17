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
    use Shrub;
    use ScriptUtils;

=head1 Prototype Shrub Pipeline Script

    Proto [ options ] parm1 parm2 ...

This is a prototype template for a database script.

=head2 Parameters

## describe positional parameters

The command-line options are those found in L<Shrub/new_for_script> and
L<ScriptUtils::ih_options> plus the following.

=over 4


## more command-line options

=back

=cut

    # Get the command-line parameters.
    my $opt = ScriptUtils::Opts('parm1 parm2 ...', Shrub::script_options(),
            Shrub::ih_options(),
            ## more command-line options
            );
    # Connect to the database.
    my $shrub = Shrub->new_for_script($opt);
    # Open the input file.
    my $ih = ScriptUtils::IH($opt->input);

    ## process the input to produce the output.
