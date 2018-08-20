#!/bin/bash
set -euo pipefail

vcf=$1
bam=$2
out_vcf=$3

zgrep -v "^#" "$1" | cut -f 1,2 | while read chr pos;do
    pysamstats --type mapq --chromosome $chr --start $pos --end $((pos+1)) "$bam"  | grep $pos | awk 'OFS="\t"{if($3==0){print $1,$2,"0"}else{print $1,$2,$5/$3}}' >>/tmp/mapq0counts
done

vcf-info-annotator "$vcf" /tmp/mapq0counts MAPQ0 "fraction mapq 0 reads" Integer $out_vcf
