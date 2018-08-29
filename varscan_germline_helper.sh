#!/bin/bash

set -o errexit
set -o nounset

if [ $# -lt : ]
then
    echo "Usage: $0 [BAM] [REFERENCE] [STRAND_FILTER] [MIN_COVERAGE] [MIN_VAR_FREQ] [MIN_READS] [P_VALUE] [SAMPLE_NAME] [OUTPUT_VCF] [roi_bed?]"
    exit 1
fi

BAM="$1"
REFERENCE="$2"
STRAND_FILTER="$3"
MIN_COVERAGE="$4"
MIN_VAR_FREQ="$5"
MIN_READS="$6"
P_VALUE="$7"
SAMPLE_NAME="$8"
OUTPUT="$9"

SAMPLE_LIST_FILE=${TMPDIR}/varscan_samples.list
echo $SAMPLE_NAME > $SAMPLE_LIST_FILE

if [ -z ${10+x} ]
then
    #run without ROI
    java -jar /opt/varscan/VarScan.jar mpileup2cns \
        <(/opt/samtools/bin/samtools mpileup --no-baq -f "$REFERENCE" "$BAM") \
        --strand-filter $STRAND_FILTER \
        --min-coverage $MIN_COVERAGE \
        --min-var-freq $MIN_VAR_FREQ \
        --min-reads2 $MIN_READS \
        --p-value $P_VALUE \
        --mpileup 1 \
        --output-vcf \
        --variants \
        --vcf-sample-list $SAMPLE_LIST_FILE \
        > "$OUTPUT"
else
    ROI_BED="${10}"
    java -jar /opt/varscan/VarScan.jar mpileup2cns \
        <(/opt/samtools/bin/samtools mpileup --no-baq -l "$ROI_BED" -f "$REFERENCE" "$BAM") \
        $OUTPUT \
        --strand-filter $STRAND_FILTER \
        --min-coverage $MIN_COVERAGE \
        --min-var-freq $MIN_VAR_FREQ \
        --min-reads2 $MIN_READS \
        --p-value $P_VALUE \
        --mpileup 1 \
        --variants \
        --output-vcf \
        --vcf-sample-list $SAMPLE_LIST_FILE \
        > "$OUTPUT"
fi
