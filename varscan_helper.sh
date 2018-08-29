#!/bin/bash

set -o errexit
set -o nounset

if [ $# -lt 7 ]
then
    echo "Usage: $0 [TUMOR_BAM] [NORMAL_BAM] [REFERENCE] [STRAND_FILTER] [MIN_COVERAGE] [MIN_VAR_FREQ] [P_VALUE] [roi_bed?]"
    exit 1
fi

TUMOR_BAM="$1"
NORMAL_BAM="$2"
REFERENCE="$3"
STRAND_FILTER="$4"
MIN_COVERAGE="$5"
MIN_VAR_FREQ="$6"
P_VALUE="$7"
OUTPUT="${HOME}/output"

if [ -z ${8+x} ]
then
    #run without ROI
    java -jar /opt/varscan/VarScan.jar somatic \
        <(/opt/samtools/bin/samtools mpileup --no-baq -f "$REFERENCE" "$NORMAL_BAM" "$TUMOR_BAM") \
        $OUTPUT \
        --strand-filter $STRAND_FILTER \
        --min-coverage $MIN_COVERAGE \
        --min-var-freq $MIN_VAR_FREQ \
        --p-value $P_VALUE \
        --mpileup 1 \
        --output-vcf
else
    ROI_BED="$8"
    java -jar /opt/varscan/VarScan.jar somatic \
        <(/opt/samtools/bin/samtools mpileup --no-baq -l "$ROI_BED" -f "$REFERENCE" "$NORMAL_BAM" "$TUMOR_BAM") \
        $OUTPUT \
        --strand-filter $STRAND_FILTER \
        --min-coverage $MIN_COVERAGE \
        --min-var-freq $MIN_VAR_FREQ \
        --p-value $P_VALUE \
        --mpileup 1 \
        --output-vcf
fi
