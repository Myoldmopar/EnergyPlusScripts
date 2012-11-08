#!/bin/bash

# run E+ using two different working directories
# ToDo: everything!
# ideas: allow a basic project directory, including a src directory, inputFiles directory, etc.
# each working directory will have an output folder as well where data will be saved (idf, csv, eio, err, mtr, eso, tbl.html?)
# base it on my test suite in VB.Net I guess

# everything from here down is actually the reverse DD script that this will be built OVER...just a starting point!

# assumptions:
# 1: input file will run ONLY two design days...needed for assumptions built into output parsing

# arguments:
# 1: name of E+ executable (default = first executable file found with "debug" in the filename)
# 2: name of input file to run with (default = in.idf)

# returns:
# 0: successful processing and resulting files are equal
# 1: successful processing, but resulting files are different
# 100+: specific error codes due to failed processing of some kind

# Steps:
# 0a: Process env args
# 0b: Error check: make sure executable, idd, and filename exist in the current directory
# 1a: Prepare input file (rename to in.idf ONLY IF file name != in.idf already), remove previous output files
# 1b: Prepare environment (export DDONLY=Y)
# 2a: Run E+ in normal mode
# 2b: Check for errors
# 3a: Run readvars to create csv data
# 3b: Check for errors
# 3c: Archive this csv data for later (rename)
# 4a: Prepare environment (DDONLY still exported, export REVERSEDD=Y)
# 5a: Run E+ (in RDD mode now)
# 5b: Check for errors
# 6a: Run readvars to create csv data
# 6b: Check for errors
# 6c: Swap output rows by reading total number of lines, subtracting 1, dividing by 2, and swapping it using sed
# 6d: Archive this csv data for later (rename)
# 7a: We could first try to simply diff this data
# 7b: If not equal, try to give a measure of differences, but frankly, if it isn't equal, we know something is wrong
# 8a: Mop-up; reset environment variables to pre-script state

# exit codes
exit_SUCCESS_FILESEQUAL=0
exit_SUCCESS_FILESDIFFERENT=1
exit_EPFILEPROBLEM=101
exit_INPUTFILEPROBLEM=102
exit_SIMULATIONPROBLEM=103
exit_BADARGS=104

# constants
fIDF='in.idf'
fIDFBKUP='inBackup.idf'
fIDD='Energy+.idd'
fEND='eplusout.end'
fCSV='eplusout.csv'
fCSVA='DD1.csv'
fCSVB='DD2.csv'
fTMP='tmp.csv'
 
# memory variables, to reset environment to pre-script state
VAR_DDO=$DDONLY
VAR_RDD=$REVERSEDD
 
# convenience variables
SS=" * ReverseDD Script: " 
 
# default values to be overridden with cl arguments
fEXEC='EnergyPlus_intel_debug'
fFILE='PipingSystem_Underground_TwoPipe.idf'

# for diagnostics, spew the current directory
echo "${SS}Current Directory=\"`pwd`\""
 
# 0a: Process CL args
if [ "$#" -gt 0 ]; then
    fEXEC="$1"
    echo "${SS}Overriding default executable file with command line argument=\"${fEXEC}\""
fi
if [ "$#" -gt 1 ]; then
    fFILE="$2"
    echo "${SS}Overriding default filename with command line argument=\"${fFILE}\""
fi
if [ "$#" -gt 2 ]; then
    echo "Usage: `basename $0` [Executable File] [Input File]"
fi

# 0b: make sure all files exist, and that exec is actually executable
if [ ! -f "${fIDD}" ]; then
    echo "${SS}Did not find IDD file=\"$fIDD\" in current directory...aborting"
    exit $exit_EPFILEPROBLEM
fi
if [ ! -f "${fEXEC}" ]; then
    echo "${SS}Did not find E+ executable file=\"$fEXEC\" in current directory...aborting"
    exit $exit_EPFILEPROBLEM
fi
if [ ! -x "${fEXEC}" ]; then
    echo "${SS}Found the E+ executable file=\"$fEXEC\", but it is not marked with the executable bit...odd...aborting"
    exit $exit_EPFILEPROBLEM
fi
if [ ! -f "${fFILE}" ]; then
    echo "${SS}Did not find the E+ input file=\"$fFILE\" in current directory...aborting"
    exit $exit_INPUTFILEPROBLEM
fi

# debug
echo "${SS}File structure validated"

# 1a: prepare input files, remove previous output files
if [ -f "${fIDFBKUP}" ]; then
    rm "${fIDFBKUP}"
fi
if [ "${fFILE}" != "${fIDF}" ]; then
    cp "${fFILE}" "${fIDF}"
fi
if [ -f "${fEND}" ]; then
    rm "${fEND}"
fi
if [ -f "${fCSV}" ]; then
    rm "${fCSV}"
fi

# debug
echo "${SS}Input files prepared"

# 1b: prepare environment:
export DDONLY=Y
export REVERSEDD=N

# debug
echo "${SS}Environment prepared for DDONLY runs"

# 2a: Run E+
./${fEXEC}

# debug
echo "${SS}EnergyPlus run with base DD configuration"

# 2b: Check for errors
if [ ! -f "${fEND}" ]; then
    echo "${SS}End file not found, problem running simulation...aborting"
    exit $exit_SIMULATIONPROBLEM
fi
if ! grep -qi 'success' "${fEND}"; then
    echo "${SS}End file found, but did not contain SUCCESS...simulation probably failed...aborting"
    exit $exit_SIMULATIONPROBLEM
fi

# debug
echo "${SS}EnergyPlus appeared to complete successfully"

# 3a: Run readvars
readvars

# 3b: Check for errors (does readvars return a useful return code?)

# debug
echo "${SS}ReadVars has been run...not validated"

# 3c: Archive this data
if [ -f ${fCSVA} ]; then
    rm ${fCSVA}
fi
cp ${fCSV} ${fCSVA}

# 3d: Archive any reverse dd struc files found
mkdir -p "DD1Structures"
mv RevDDStruc* DD1Structures/

# debug
echo "${SS}Output from base DD configuration stored"

# 4a: Prepare environment for second run
if [ -f ${fEND} ]; then
    rm ${fEND}
fi
if [ -f ${fCSV} ]; then
    rm ${fCSV}
fi
export REVERSEDD=Y

# debug
echo "${SS}Environment prepared for reverse DD run"

# 5a: Run E+ (in RDD mode this time)
./${fEXEC}

# debug
echo "${SS}EnergyPlus run with reverse DD configuration"

# 5b: Check for errors
if [ ! -f ${fEND} ]; then
    echo "${SS}End file not found, problem running simulation...aborting"
    exit $exit_SIMULATIONPROBLEM
fi
if ! grep -qi 'success' ${fEND}; then
    echo "${SS}End file found, but did not contain SUCCESS...simulation probably failed...aborting"
    exit $exit_SIMULATIONPROBLEM
fi

# debug
echo "${SS}EnergyPlus appeared to run successfully"
 
# 6a: Run readvars
readvars

# 6b: Check for errors (does readvars return a useful return code?)

# debug
echo "${SS}ReadVars has been run...not validated"

# 6c: Swap output rows
# first get the number of lines in the file total
NUMLINES=`wc -l < ${fCSV}`
# then (assuming equal number of rows for each DD, and also ONLY 2 DDs), use bc to calculate number of rows for each DD
LINESPERDD=`echo "(${NUMLINES}-1)/2" | bc`
# would be nice to do this in place (copy/append first DD to end of file, then remove the first one)
# instead, we can write the header to a temp file, then separately append the 2nd then the 1st
sed -n "1p" ${fCSV} > ${fTMP}
sed -n "$((LINESPERDD+2)),${NUMLINES}p" ${fCSV} >> ${fTMP}
sed -n "2,$((LINESPERDD+1))p" ${fCSV} >> ${fTMP}

# debug
echo "${SS}Results from second output file swapped, number of rows per DD=${LINESPERDD}"

# 6d: Archive this csv data for later (rename)
if [ -f ${fCSVB} ]; then
    rm ${fCSVB}
fi
cp ${fTMP} ${fCSVB}

# 6e: Archive any reverse dd struc files found
mkdir -p "DD2Structures"
mv RevDDStruc* DD2Structures/

# debug
echo "${SS}Output from reverse DD configuration stored"

# 7a: Try diffing the data
echo "${SS}* * * * * * * * * * * * * * * * * * * * * * * * "
if `diff ${fCSVA} ${fCSVB} >/dev/null` ; then
  echo "${SS}Diff run: Files are the same!"
else
  echo "${SS}Diff run: Files are different!"
fi
echo "${SS}* * * * * * * * * * * * * * * * * * * * * * * * "

# 7b: TODO: Additional diff diagnostics...probably not necessary

# 8a: Mop-up; reset environment variables to pre-script state
export DDONLY=$VAR_DDO
export REVERSEDD=$VAR_RDD

# debug
echo "${SS}Environment cleaned up"
