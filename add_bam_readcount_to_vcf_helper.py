#!/usr/bin/env python

import sys
import os
import re
import vcfpy
import tempfile
import csv
from collections import OrderedDict

def parse_brct_field(brcts):
    parsed_brct = {}
    for brct in brcts:
        (base, count, rest) = brct.split(':', 2)
        parsed_brct[base.upper()] = count
    return parsed_brct

def parse_bam_readcount_file(bam_readcount_files, samples):
    coverage = {}
    for bam_readcount_file, sample in zip(bam_readcount_files, samples):
        coverage[sample] = {}
        with open(bam_readcount_file, 'r') as reader:
            coverage_tsv_reader = csv.reader(reader, delimiter='\t')
            for row in coverage_tsv_reader:
                chromosome     = row[0]
                position       = row[1]
                reference_base = row[2].upper()
                depth          = row[3]
                brct           = row[4:]
                if chromosome not in coverage[sample]:
                    coverage[sample][chromosome] = {}
                if position not in coverage[sample][chromosome]:
                    coverage[sample][chromosome][position] = {}
                coverage[sample][chromosome][position][reference_base] = parse_brct_field(brct)
                coverage[sample][chromosome][position][reference_base]['depth'] = depth
    return coverage

def is_insertion(ref, alt):
    return len(alt) > len(ref)

def is_deletion(ref, alt):
    return len(alt) < len(ref)

def simplify_indel_allele(ref, alt):
    while len(ref)> 0 and len(alt) > 0 and ref[-1] == alt[-1]:
        ref = ref[0:-1]
        alt = alt[0:-1]
    while len(ref)> 0 and len(alt) > 0 and ref[0] == alt[0]:
        ref = ref[1:]
        alt = alt[1:]
    return ref, alt

def calculate_coverage(ref, var):
    return ref + var

def calculate_vaf(var, depth):
    return format(var / int(depth), '.5f')

def parse_to_bam_readcount(start, reference, alt):
    if len(alt) != len(reference):
        if is_deletion(reference, alt):
            bam_readcount_position = str(start + 2)
            (simplified_reference, simplified_alt) = simplify_indel_allele(reference, alt)
            ref_base = reference[1:2]
            var_base = '-' + simplified_reference
        elif is_insertion(reference, alt):
            bam_readcount_position = str(start)
            (simplified_reference, simplified_alt) = simplify_indel_allele(reference, alt)
            ref_base = reference
            var_base = '+' + simplified_alt
    else:
        bam_readcount_position = str(entry.POS)
        ref_base = reference
        var_base = alt
    return (bam_readcount_position, ref_base, var_base)

(script, vcf_filename, bam_readcount_filenames, samples_list, output_dir) = sys.argv

samples = samples_list.split(',')
bam_readcount_files = bam_readcount_filenames.split(',')
read_counts = parse_bam_readcount_file(bam_readcount_files, samples)

vcf_reader = vcfpy.Reader.from_path(vcf_filename)

new_header = vcfpy.Header(samples = vcf_reader.header.samples)
for line in vcf_reader.header.lines:
    if not (line.key == 'FORMAT' and line.id in ['DP', 'AD', 'AF']):
        new_header.add_line(line)
new_header.add_format_line(OrderedDict([('ID', 'DP'), ('Number', '1'), ('Type', 'Integer'), ('Description', 'Read depth')]))
new_header.add_format_line(OrderedDict([('ID', 'AD'), ('Number', 'R'), ('Type', 'Integer'), ('Description', 'Allelic depths for the ref and alt alleles in the order listed')]))
new_header.add_format_line(OrderedDict([('ID', 'AF'), ('Number', 'A'), ('Type', 'Float'), ('Description', 'Variant-allele frequency for the alt alleles')]))

vcf_writer = vcfpy.Writer.from_path(os.path.join(output_dir, 'annotated.bam_readcount.vcf.gz'), new_header)

for entry in vcf_reader:
    chromosome = entry.CHROM
    start      = entry.affected_start
    stop       = entry.affected_end
    reference  = entry.REF
    alts       = entry.ALT

    for sample in samples:
        #DP - read depth
        if 'DP' not in entry.FORMAT:
            entry.FORMAT += ['DP']
        alt = alts[0].serialize()
        (bam_readcount_position, ref_base, var_base) = parse_to_bam_readcount(start, reference, alt)
        if (
            chromosome in read_counts[sample]
            and bam_readcount_position in read_counts[sample][chromosome]
            and ref_base in read_counts[sample][chromosome][bam_readcount_position]
        ):
            brct = read_counts[sample][chromosome][bam_readcount_position][ref_base]
            if ref_base in brct:
                depth = read_counts[sample][chromosome][bam_readcount_position][ref_base]['depth']
            else:
                depth = 0
        else:
            depth = 0
        entry.call_for_sample[sample].data['DP'] = depth

        #AF - variant allele frequencies
        if 'AF' not in entry.FORMAT:
            entry.FORMAT += ['AF']
        vafs = []
        for alt in alts:
            alt = alt.serialize()
            (bam_readcount_position, ref_base, var_base) = parse_to_bam_readcount(start, reference, alt)
            if (
                chromosome in read_counts[sample]
                and bam_readcount_position in read_counts[sample][chromosome]
                and ref_base in read_counts[sample][chromosome][bam_readcount_position]
            ):
                brct = read_counts[sample][chromosome][bam_readcount_position][ref_base]
                if var_base in brct:
                    vafs.append(calculate_vaf(int(brct[var_base]), depth))
                else:
                    vafs.append(0)
            else:
                vafs.append(0)
        entry.call_for_sample[sample].data['AF'] = vafs

        #AD - ref, var1..varN counts
        if 'AD' not in entry.FORMAT:
            entry.FORMAT += ['AD']
        ads = []
        (bam_readcount_position, ref_base, var_base) = parse_to_bam_readcount(start, reference, alts[0].serialize())
        if (
            chromosome in read_counts[sample]
            and bam_readcount_position in read_counts[sample][chromosome]
            and ref_base in read_counts[sample][chromosome][bam_readcount_position]
        ):
            brct = read_counts[sample][chromosome][bam_readcount_position][ref_base]
            if ref_base in brct:
                ads.append(brct[ref_base])
            else:
                ads.append(0)
        else:
            ads.append(0)
        for alt in alts:
            if type(alt) is not str:
                alt = alt.serialize()
            (bam_readcount_position, ref_base, var_base) = parse_to_bam_readcount(start, reference, alt)
            if (
                chromosome in read_counts[sample]
                and bam_readcount_position in read_counts[sample][chromosome]
                and ref_base in read_counts[sample][chromosome][bam_readcount_position]
            ):
                brct = read_counts[sample][chromosome][bam_readcount_position][ref_base]
                if var_base in brct:
                    ads.append(brct[var_base])
                else:
                    ads.append(0)
            else:
                ads.append(0)
        entry.call_for_sample[sample].data['AD'] = ads

    vcf_writer.write_record(entry)

vcf_writer.close()
vcf_reader.close()

