#!/bin/bash
set -e
set -o pipefail

# This bash script (ml_trees.sh) uses iqtree to produce maximum likelihood (ML)
# trees for all fasta alignments provided. Run with:
# $ bash ml_trees.sh [path/to/aligment.fasta]

FASTA_FILES=${@?Must provide aligment file(s) as the script argument.}

mkdir -p trees  # make trees folder if it does not exist (-p)

for alignment in $(ls $FASTA_FILES)
do
  # `-s $alignment` the input alignment file
  # `-T AUTO` automatically optimise the number of threads used
  # `-m GTR+I+G` use the GTR+I+G substitution model
  # `-redo` overwrite previous runs
  # `--prefix trees/$(basename $alignment)` save trees in the trees folder
	iqtree2 -s $alignment -T AUTO -m GTR+I+G -redo --prefix trees/$(basename $alignment) &
	# The `&` at the end of the iqtree2 commands tells bash to run the command in
  # the background (i.e. in parallel).
done

wait # wait for all parallel comamnds to finsh
