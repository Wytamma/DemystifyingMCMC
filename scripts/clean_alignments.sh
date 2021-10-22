#!/bin/bash
set -e
set -o pipefail

# This bash script (`clean_alignments.sh`) uses `seqkit` (Shen et al 2016) to
# produce cleaned alignments (reference sequences removed and dates added to
# description) for all fasta alignments provided. Assumes that metadata files
# are in the same dir as the fasta file {fasta_file_name}_metadata.csv.
# Asumes that the column matching the fasta description is the first column.
# Run with:
# $ bash clean_alignments.sh [path/to/fasta.fasta]

COLUMNS=2  # Columns (comma sperate e.g. 2,3) to add to the fasta description

FASTA_FILES=${@?Must provide fasta file(s) as the script argument.}

mkdir -p cleaned_alignments  # make cleaned_alignments folder if it does not exist (-p)

for alignment in $(ls $FASTA_FILES)
do
  METADATA=$(dirname $alignment)/$(basename $alignment .fasta)_metadata.csv
  # Remove sequences with fasta description starting with (^) `Reference`
	seqkit grep -rvip "^Reference" $alignment |
	# Add data to description.
	seqkit replace \
    --keep-key \
    --kv-file \
      <(paste -d "\t" <(cut -d , -f 1 $METADATA) \
      <(cut -d , -f $COLUMNS $METADATA | tr ',' '_')) \
    --pattern "^(\w+)" --replacement "\${1}_{kv}" \
  > cleaned_alignments/$(basename $alignment)
done
