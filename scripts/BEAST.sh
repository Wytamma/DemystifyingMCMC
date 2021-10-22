#!/bin/bash
set -e
set -o pipefail

# This script will run a BEAST 2 analysis with best practices.
# Ensure BEAST 2 bin is in the PATH e.g `export PATH="/Applications/BEAST 2.6.6/bin:$PATH"`
# This includes repeated runs, seed reporting, Dynamic chain length and sample frequencies, 
# and output organisation.

# Configure the setting and run with:
# $ bash BEAST.sh path/to/beast.xml

# --- SETTINGS ---
CHAIN_LENGTH="10000000"  # number of step in MCMC chain - str int
NUMER_OF_REPEATS=3  # times the analysis should be repeated - int
NUMBER_OF_SAMPLES="10000"  # number of samples to collect - str int
SAMPLE_FREQUENCY="$(expr $CHAIN_LENGTH / $NUMBER_OF_SAMPLES)"

# Values to replace at run-time (comma separated)
# Check the dynamic XML file for IDs e.g. "treelog.t:ebola.logEvery"
DYNAMIC_VARS="treelog.t:ebola.logEvery=$SAMPLE_FREQUENCY"

# BEAGLE CONFIG
NUMBER_OF_CORES=4  # the number of threads and beagle instances to use - int
BEAGLE_CPU=true  # use CPU instance - bool
BEAGLE_SSE=true  # use beagle SSE extensions if available - bool
BEAGLE_GPU=true  # use GPU instance if available - bool

# --- SETUP ---
BEAST_XML=${1?Must provide a BEAST XML file as the first arg.}
BEAST_XML_FILENAME="$(basename "${BEAST_XML}")"
BEAST_XML_DIR="$(dirname "${BEAST_XML}")"
# Use dynamic-beast to create a dynamic XML file.
# This allows us to modify parameters like chainLength at runtime.
DYNAMIC_XML=$BEAST_XML_DIR/DYNAMIC_$BEAST_XML_FILENAME
# Default values to replace at run-time
DYNAMIC_VARS+=",mcmc.chainLength=$CHAIN_LENGTH,"
DYNAMIC_VARS+="treelog.logEvery=$SAMPLE_FREQUENCY,"
DYNAMIC_VARS+="tracelog.logEvery=$SAMPLE_FREQUENCY"

# Create a working directory based on the datetime of the analysis
DATE=$(date +%s)
WORK_DIR="$(dirname "${BEAST_XML}")/$(basename "${BEAST_XML}" .xml)_$DATE"
mkdir $WORK_DIR

# --- REQUIREMENTS ---
pip3 install --user --quiet dynamic-beast  # install dynamic-beast

# Create dynamic XML
python3 -m dynamic_beast --outfile $DYNAMIC_XML $BEAST_XML

# -- ANALYSIS ---
mkdir $WORK_DIR/runs  # make runs dir

# BEAGLE options
PARAMS=()
[[ $BEAGLE_CPU == true ]] && PARAMS+=(-beagle_CPU)
[[ $BEAGLE_GPU == true ]] && PARAMS+=(-beagle_GPU)
[[ $BEAGLE_SSE == true ]] && PARAMS+=(-beagle_SSE)

# Repeat the analysis to assess convergence.
for i in $(seq 1 $NUMER_OF_REPEATS); do
  SEED=$RANDOM  # generate a random number for the seed
  DIR=$WORK_DIR/runs/$i && mkdir -p $DIR
  PREFIX=$DIR/$i
  beast \
    -overwrite \
    -beagle \
    -instances $NUMBER_OF_CORES \
    -threads $NUMBER_OF_CORES \
    -D "${DYNAMIC_VARS}" \
    -DFout $WORK_DIR/$BEAST_XML_FILENAME \
    -seed $SEED \
    -statefile $PREFIX.$BEAST_XML_FILENAME.state \
    -prefix $PREFIX. \
    "${PARAMS[@]}" \
    $DYNAMIC_XML 2>&1 | tee $PREFIX.$BEAST_XML_FILENAME.out &
  # The `&` at the end of the beast commands tells bash to run the command in the
  # background (i.e. in parallel). The processes can be killed with the `ps` and `kill`
  # commands. See `SLURM-MCMC.sh` for an example of running beast on a HPC.

  echo "$SEED" > $DIR/seed.txt # save the seed
done

wait # wait for all parallel commands to finish