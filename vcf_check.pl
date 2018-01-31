#!/usr/bin/perl

use strict;
use warnings;

use File::Copy qw(copy);


if(@ARGV < 3) {
    print STDERR "Usage: <VCF> <output destination if VCF empty> <command if VCF non-empty> [command args...]\n";
    exit -1;
}

main(@ARGV);
exit 0;

sub main {
    my ($vcf_to_check, $where_to_copy_if_empty, @commandline_if_nonempty) = @_;

    if (vcf_is_empty($vcf_to_check)) {
        copy($vcf_to_check, $where_to_copy_if_empty) or die('Failed to copy empty VCF: ' . $!);
    } else {
        exec { $commandline_if_nonempty[0] } @commandline_if_nonempty;
        die('Failed to execute command: ' . $!);
    }
}


sub vcf_is_empty {
    my $vcf = shift;

    my $is_compressed = $vcf =~ /\.gz$/;

    my $rv;
    if ($is_compressed) {
        #hack to get around broken pipe error from `zgrep`
        $rv = system(q(zcat ') . $vcf . q(' 2>/dev/null | grep -q -v '#'));
    } else {
        $rv = system('grep', '-q', '-v', '#', $vcf);
    }

    if ($rv == -1) {
        die('Failed to execute command to inspect VCF: ' . $!);
    }

    #0 rv from grep indicates a match for a data line was found => non-empty
    #1 rv from grep indicates only header lines were present => empty
    #other return codes are bad.

    $rv >>= 8;

    if ($rv == 0 or $rv == 1) {
        return $rv;
    } else {
        die('Failed to determine VCF status. Unexpected return code from grep: ' . $rv);
    }
}

