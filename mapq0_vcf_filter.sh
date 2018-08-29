#!/bin/bash
set -euo pipefail

vcf=$1
bam=$2
ref_fasta=$3
mapq0perc=$4
outvcf=$5


#grab sites that don't already have the MQ0 field
zgrep -v "^#" "$vcf" | grep -v "MQ0" | cut -f 1,2 | while read chr pos;do
    echo $chr $pos $((pos+1))
    pysamstats --type mapq --chromosome $chr --start $pos --end $((pos+1)) "$bam"  | grep $pos | cut -f 1,2,5 >>/tmp/mapq0counts
done

#does the file contain the MQ0 field already?
mqcount=0
case "$vcf" in
*.gz | *.tgz )
    #gzipped vcf
    mqcount=$(gunzip -c "$vcf" | grep "^#" | grep -w MQ0 | wc -l)
        ;;
*)
    #non-gzipped vcf
    mqcount=$(grep "^#" "$vcf" | grep -w MQ0 | wc -l)
        ;;
esac

if [[ $mqcount -gt 0 ]];then
    #already has mq0 set, we're all good
    vcf-info-annotator --overwrite -o /tmp/mapq0.vcf "$vcf" /tmp/mapq0counts MQ0 
else
    #no mq0, need to set the header line as well
    vcf-info-annotator -o /tmp/mapq0.vcf -f Integer -d "Number of MAPQ == 0 reads covering this record" "$vcf" /tmp/mapq0counts MQ0
fi
 
#finally, set the filter tags on the vcf
#the multiplication by 1.0 is necessary to convert integers to floats before dividing in the JEXL expression 
#(which is dumb, and I want an hour of my life back)
java -jar /opt/GenomeAnalysisTK.jar -T VariantFiltration -R $ref_fasta -o $outvcf --variant /tmp/mapq0.vcf --filterExpression "((MQ0*1.0) / (DP*1.0)) > $mapq0perc" --filterName "MAPQ0"
