#!/usr/bin/env perl

use strict;

use feature qw(say);

unless(@ARGV and int($ARGV[0])) {
    STDERR->say('Usage: [NUM_CPUS] [RUNDIR] <STRELKA_CONFIGURE_OPTIONS...>');
    exit 255;
}

my $num_cpus = shift(@ARGV);
my $rundir = shift(@ARGV);

my $configure_script = '/opt/strelka/bin/configureStrelkaSomaticWorkflow.py';

system($configure_script, "--runDir=${rundir}", @ARGV) == 0
    or die("Failed to configure: $!");

chdir $rundir
    or die('Could not change to run directory.');
system('./runWorkflow.py', '-m', 'local', '-j', $num_cpus) == 0
    or die("Failed to run: $!");
