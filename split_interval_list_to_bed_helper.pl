#!/usr/bin/perl

use strict;
use warnings;

use feature qw(say);

my $retval = system('/usr/bin/java', '-jar', '/usr/picard/picard.jar', 'IntervalListTools', @ARGV);
exit $retval if $retval != 0;

my $i = 1;
for my $interval_list (glob('*/scattered.interval_list')) {
    my $bed = $i.'.interval.bed';
    open(my $in_fh, $interval_list) or die "fail to open $interval_list for read"; 
    open(my $out_fh, ">$bed") or die "fail to write to $bed";
    while (<$in_fh>) {
        next if /^@/;
        my ($chr, $start, $stop) = split /\t/, $_;
        $out_fh->say(join("\t", $chr, $start-1, $stop));
    }
    close $in_fh;
    close $out_fh;
    $i++
}
