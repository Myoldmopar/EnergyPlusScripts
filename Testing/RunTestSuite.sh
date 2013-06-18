#!/bin/bash

# run E+ using two different working directories
# ToDo: everything!
# ideas: allow a basic project directory, including a src directory, inputFiles directory, etc.
# each working directory will have an output folder as well where data will be saved (idf, csv, eio, err, mtr, eso, tbl.html?)
# base it on my test suite in VB.Net I guess

# two directories and two executable names are passed in in the following manner:
# $0 baseDir baseExec modDir modExec # eventually the outputDir also -- Execs are file names in each working dir, not full paths

# a function will be set up to run all idf files in the {baseDir or modDir}/inputFiles directory, directly in the {baseDir or modDir} directory
# the output of each run will be saved in an output directory named...output (cleared before the runs start)
# for a first pass, we'll be able to diff the folders and check for diffs manually...eventually we can implement mathdiff.py
# the main script will call the run function with first the base info then the mod info...forking each call

# I think we may just narrow down the script so that the directory structure must be like:
#[~/tmp/testSuite]
#-> tree
#.
#├── base
#│   ├── Energy+.idd
#│   └── inputFiles
#│       ├── 1ZoneEvapCooler.idf
#│       ├── 1ZoneUncontrolled_DD2009.idf
#│       ├──  -- others --
#│       └── 1ZoneUncontrolled.idf
#├── mod
#│   ├── Energy+.idd
#│   └── inputFiles
#│       ├── 1ZoneEvapCooler.idf
#│       ├── 1ZoneUncontrolled_DD2009.idf
#│       ├──  -- others --
#│       └── 1ZoneUncontrolled.idf
#└── output
#
# this way we would only have to specify perhaps the executable names...or maybe we could require those also!?

# assumptions:
# readvars is on PATH somewhere

runATestSuiteDirectory()
{ # runs a single test suite folder, either base or mod
    local thisDir=$1
    local thisExec=$2
    
    if [ ! -d "${thisDir}" ]; then
        echo "This directory doesn't exist?!? : ${thisDir}"
        exit 1
    fi
    
    cd "${thisDir}"
    local OUTDIR="${thisDir}/${3}"
                      
    if [ ! -f "${thisExec}" ]; then
        echo "The executable doesn't exist?!? : ${thisExec}"
        exit 1
    fi
    
    if [[ ! -x "${thisExec}" ]]; then
        echo "The executable exists, but isn't actually executable?!? : ${thisExec}"
        exit 1
    fi
    
    if [ ! -f 'Energy+.idd' ]; then
        echo "Energy+.idd not found in the current directory...aborting"
        exit 1
    fi    
    
    for file in ${thisDir}/inputFiles/*.idf; do
        
        # spew
        echo "Running this file: ${file} in directory ${thisDir}"
        
        # get the base name for this file
        base=`basename ${file} .idf`
        
        # clean up
        rm -f eplusout.end > /dev/null
        rm -f eplusout.eso > /dev/null
        rm -f eplusout.csv > /dev/null
        rm -f eplusout.mtr > /dev/null
        rm -f eplusout.err > /dev/null
        rm -f in.idf > /dev/null
        
        # copy in the input file
        cp "${file}" ./in.idf > /dev/null 
                
        # execute
        ./${thisExec} > /dev/null 2>&1
        
        # check for errors
        if [ ! -f eplusout.end ]; then
            echo "End file not found, problem running simulation...aborting ths file"
            continue
        fi
        if ! grep -qi 'success' "eplusout.end"; then
            echo "End file found, but did not contain SUCCESS...simulation probably failed...aborting this file"
            continue
        fi
        
        # run readvars
        readvars > /dev/null
        
        # copy relevant output files
        if [ -f eplusout.end ]; then cp eplusout.end "${OUTDIR}/${base}.end" > /dev/null; fi
        if [ -f eplusout.eso ]; then cp eplusout.eso "${OUTDIR}/${base}.eso" > /dev/null; fi
        if [ -f eplusout.csv ]; then cp eplusout.csv "${OUTDIR}/${base}.csv" > /dev/null; fi
        if [ -f eplusout.err ]; then cp eplusout.err "${OUTDIR}/${base}.err" > /dev/null; fi
        if [ -f eplusout.mtr ]; then cp eplusout.mtr "${OUTDIR}/${base}.mtr" > /dev/null; fi
                
    done
  
}

usage() 
{
    echo "$1 BaseDirPath BaseExecFileName ModDirPath ModExecFileName OutputBaseDirectory"
}

# this could be an option...or just set by calling process
export DDONLY=Y

# check command line args
if [ $# -ne 5 ]; then
    echo "Error: Command line argument count does not equal 5.  Proper usage:"
    usage "`basename $0`"
    exit 1
fi

# assign command line args for convenience
varBaseDir=${1%/}
varBaseExec=${2}
varModDir=${3%/}
varModExec=${4}
varOutputDir=${5%/}

# get the current time and use that as the output directory in working and output dirs
NOW=`date '+%Y%m%d~%k%M%S'`
OUTDIR="output${NOW}"
baseOUTDIR="${varBaseDir}/${OUTDIR}"
modOUTDIR="${varModDir}/${OUTDIR}"
outOUTDIR="${varOutputDir}/${OUTDIR}"
echo "${baseOUTDIR}"
echo "${modOUTDIR}"
echo "${outOUTDIR}"
mkdir -p "${baseOUTDIR}"
mkdir -p "${modOUTDIR}"
mkdir -p "${outOUTDIR}"

# make sure they aren't the same working dirs for base and mod!!
if [ "${varBaseDir}" = "${varModDir}" ]; then
    echo "Base and mod directories are equal...something isn't right here..."
    exit 1
fi

# run base files 
runATestSuiteDirectory "$varBaseDir" "$varBaseExec" "$OUTDIR" & 
pidA=$!
echo "Spawned base run with PID=${pidA}"

# run mod files
runATestSuiteDirectory "$varModDir" "$varModExec" "$OUTDIR" & 
pidB=$!
echo "Spawned mod run with PID=${pidB}"

# wait for them to join and spew along the way
echo "Waiting for them to finish..."
wait "${pidA}"
echo "base run is now finished!"
wait "${pidB}"
echo "mod run is now finished!"
echo "Both runs are done"

# now do a simple process of the csvs in each output directory
# this will be looped over the base dir, since the mod dir is probably more likely to have failures (missing files)
# however, it is possible that it will miss some.  We may want to be more careful here and re-loop over the mod dir to see if any were skipped
OUTFILE="${outOUTDIR}/summary_csvs.csv"
echo "FileName,Status" > "${OUTFILE}"
for csvFile in ${varBaseDir}/${OUTDIR}/*.csv; do
    nFile=`basename ${csvFile}`
    modcsvFile="${varModDir}/${OUTDIR}/${nFile}"
    echo "diff-ing ${csvFile} and ${modcsvFile}..."
    if diff "${csvFile}" "${modcsvFile}" >/dev/null ; then
        echo "${nFile},same" >> "${OUTFILE}"
    else
        echo "${nFile},different" >> "${OUTFILE}"
    fi
done
