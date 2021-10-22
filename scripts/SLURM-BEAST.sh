#!/bin/bash
set -e
set -o pipefail

# This script will run a BEAST 2 analysis on a slurm cluster with best practices.
# This includes repeated runs, sampling from the prior, seed reporting,
# optional MC3, dynamic chain length and sample frequencies, and
# output organisation. See BEAST.pbs for the actual job scipt.

# Config the setting (resources can be set in BEAST.pbs) and run with:
# $ bash BEAST.sh path/to/beast.xml [optional:path/to/working/dir]

# --- SETTINGS ---
CHAIN_LENGTH="50000000"  # number of step in MCMC chain - str int
NUMER_OF_REPEATS=3  # times the analysis should be repeated - int
SAMPLE_FROM_PRIOR=false  # only run prior predictive checking - bool
DESCRIPTION=""  # text to prepend to output folder name
NUMBER_OF_SAMPLES="10000"  # number of samples to collect - str int
SAMPLE_FREQUENCY="$(expr $CHAIN_LENGTH / $NUMBER_OF_SAMPLES)"
# Values to replace at run-time (comma separated)
DYNAMIC_VARS="treelog.t:ebola.logEvery=$SAMPLE_FREQUENCY"
# BEAGLE
CORES=4  # the number of threads and beagle instances to use - int
BEAGLE_CPU=true  # use CPU instance - bool
BEAGLE_SSE=true  # use beagle SSE extensions if available - bool
BEAGLE_GPU=true  # use GPU instance if available - bool
# MC3
USE_MC3=false  # optionally use the MC3 with the CoupledMCMC package - bool
LOG_HEATED_CHAINS="false"  # log the heated chians as seperate files - str bool
NUMBER_OF_CHAINS="4"  # number of cold (1) plus heated chains to run - str int
DELTA_TEMPERATURE="0.1"  # difference in temperatures between chains - str float

# --- SETUP ---
BEAST_XML=${1?Must provide a BEAST XML file as the first arg.}
WORK_DIR=$2
BEAST_XML_FILENAME="$(basename "${BEAST_XML}")"
BEAST_XML_DIR="$(dirname "${BEAST_XML}")"
# Use dynamic-beast to create a dynamic XML file.
# This allows us to modify parameters like chainLength at runtime.
DYNAMIC_XML=$BEAST_XML_DIR/DYNAMIC_$BEAST_XML_FILENAME
# Default values to replace at run-time
DYNAMIC_VARS+=",treelog.logEvery=$SAMPLE_FREQUENCY,"
DYNAMIC_VARS+="tracelog.logEvery=$SAMPLE_FREQUENCY,"
DYNAMIC_VARS+="mcmc.deltaTemperature=$DELTA_TEMPERATURE,"
DYNAMIC_VARS+="mcmc.chains=$NUMBER_OF_CHAINS,"
DYNAMIC_VARS+="mcmc.logHeatedChains=$LOG_HEATED_CHAINS,"
DYNAMIC_VARS+="mcmc.chainLength=$CHAIN_LENGTH"

# Create a working directory based on the datetime of the analysis if none provided
if [[ -z "$WORK_DIR" ]]; then
  DATE=$(date +%s)
  WORK_DIR="$(dirname "${BEAST_XML}")/$DESCRIPTION$(basename "${BEAST_XML}" .xml)_$DATE"
  mkdir $WORK_DIR
fi

# Function to submit BEAST.pbs script to Slurm Workload Manager
run_beast () {
  local PARAMS=()
  [[ $SAMPLE_FROM_PRIOR == true ]] && PARAMS+=(-sampleFromPrior)
  [[ $BEAGLE_CPU == true ]] && PARAMS+=(-beagle_CPU)
  [[ $BEAGLE_GPU == true ]] && params+=(-beagle_GPU)
  [[ $BEAGLE_SSE == true ]] && params+=(-beagle_SSE)

  EXPORT="WORK_DIR=$WORK_DIR,"
  EXPORT+="DYNAMIC_VARS=\"${DYNAMIC_VARS}\","
  EXPORT+="BEAST_XML_FILENAME=$BEAST_XML_FILENAME,"
  EXPORT+="PREFIX=$PREFIX,"
  EXPORT+="PARAMS=$PARAMS,"
  EXPORT+="SEED=$SEED,"
  EXPORT+="CORES=$CORES,"
  EXPORT+="DYNAMIC_XML=$DYNAMIC_XML"
  sbatch \
    --job-name=$NAME \
    --export=$EXPORT \
    --output "$DIR/%A.out" \
    $(dirname "${0}")/BEAST.pbs
}

# --- REQUIREMENTS ---
pip3 install --user --quiet dynamic-beast  # install dynamic-beast
# Load beast module
module load fosscuda/2019b
module load beast/2.6.3

if $USE_MC3; then
  # Create dynamic XML with MC3
  python3 -m dynamic_beast --mc3 --outfile $DYNAMIC_XML $BEAST_XML
  if packagemanager -list | grep "CoupledMCMC" | awk '{split($0,a,"|"); print a[2]}' | grep -q "NA"; then
    # Install CoupledMCMC if not already installed
    packagemanager -add CoupledMCMC
  fi
else
  # Create dynamic XML
  python3 -m dynamic_beast --outfile $DYNAMIC_XML $BEAST_XML
fi

if $SAMPLE_FROM_PRIOR; then
  # -- PRIOR ---
  # Prior predictive checking by sampling from the priors without data
  SEED=$RANDOM  # generate a random number for the seed
  DIR=$WORK_DIR/prior && mkdir -p $DIR
  PREFIX=$DIR/prior
  NAME=prior.$DATE
  run_beast
  echo "$SEED" > $DIR/seed.txt # save the seed
else
  # -- ANALYSIS ---
  # Repeat the analysis to assess convergence.
  mkdir $WORK_DIR/runs
  for i in $(seq 1 $NUMER_OF_REPEATS); do
    SEED=$RANDOM  # generate a random number for the seed
    DIR=$WORK_DIR/runs/$i && mkdir -p $DIR
    PREFIX=$DIR/$i
    NAME=run.$i.$DATE
    run_beast
    echo "$SEED" > $DIR/seed.txt # save the seed
  done
fi
