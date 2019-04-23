#!/usr/bin/perl

use strict;
use warnings;

use IO::File;

unless (@ARGV > 3) {
    die "Usage: $0 normal.bam tumor.bam insert_size <args>";
}

my ($normal_bam, $tumor_bam, $insert_size, @args) = @ARGV;

my $fh = IO::File->new("> pindel.config");

$fh->say(join("\t", $normal_bam, $insert_size, 'NORMAL'));
$fh->say(join("\t", $tumor_bam, $insert_size, 'TUMOR'));
$fh->close;

exit system(qw(/usr/bin/pindel -i pindel.config -w 10 -T 4 -o all), @args);
