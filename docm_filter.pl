#!/usr/bin/perl

use strict;
use warnings;

use feature qw(say);

die("Wrong number of arguments. Provide docm_vcf, normal_cram, tumor_cram, output_vcf_file, set_filter_flag") unless scalar(@ARGV) == 5;
my ($docm_vcf, $normal_cram, $tumor_cram, $output_vcf_file, $set_filter_flag) = @ARGV;

my $samtools = '/opt/samtools/bin/samtools';
my $normal_header_str = `$samtools view -H $normal_cram`;
my $tumor_header_str  = `$samtools view -H $tumor_cram`;

my ($normal_name) = $normal_header_str =~ /\s+SM:(\S+)/;
my ($tumor_name)  = $tumor_header_str =~ /\s+SM:(\S+)/;

unless ($normal_name and $tumor_name) {
    die "Failed to get normal_name: $normal_name from $normal_cram AND tumor_name: $tumor_name from $tumor_cram";
}

my $docm_vcf_fh;
if($docm_vcf =~ /.gz$/){
    open($docm_vcf_fh, "gunzip -c $docm_vcf |") or die("couldn't open $docm_vcf to read");
} else {
    open($docm_vcf_fh, $docm_vcf) or die("couldn't open $docm_vcf to read");
}
open(my $docm_out_fh, ">", "$output_vcf_file") or die("couldn't open $output_vcf_file for write");

my ($normal_index, $tumor_index);

while (<$docm_vcf_fh>) {
    chomp;
    if (/^##/) {
        say $docm_out_fh $_;
    }
    elsif (/^#CHROM/) {
        if ($set_filter_flag) {
            say $docm_out_fh '##FILTER=<ID=DOCM_ONLY,Description="ignore Docm variants">';
        }
        my @columns = split /\t/, $_;
        my %index = (
            $columns[9]  => 9,
            $columns[10] => 10,
        );
        ($normal_index, $tumor_index) = map{$index{$_}}($normal_name, $tumor_name);
        unless ($normal_index and $tumor_index) {
            die "Failed to get normal_index: $normal_index for $normal_name AND tumor_index: $tumor_index for $tumor_name";
        }
        $columns[9]  = 'NORMAL';
        $columns[10] = 'TUMOR';
        my $header = join "\t", @columns;
        say $docm_out_fh $header;
    }
    else {
        my @columns = split /\t/, $_;
        my @tumor_info = split /:/, $columns[$tumor_index];
        my ($AD, $DP) = ($tumor_info[1], $tumor_info[2]);
        next unless $AD;
        my @AD = split /,/, $AD;
        shift @AD; #the first one is ref count
        
        for my $ad (@AD) {
            if ($ad > 5 and $ad/$DP > 0.01) {
                my ($normal_col, $tumor_col) = map{$columns[$_]}($normal_index, $tumor_index);
                $columns[9]  = $normal_col;
                $columns[10] = $tumor_col;
                if ($set_filter_flag) {
                    $columns[6] = 'DOCM_ONLY';
                }
                else {
                    $columns[6] = '.';
                }
                my $new_line = join "\t", @columns;
                say $docm_out_fh $new_line;
                last;
            }
        }
    }
}

close($docm_vcf_fh);
close($docm_out_fh);
