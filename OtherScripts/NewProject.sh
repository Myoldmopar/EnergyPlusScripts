#!/bin/bash

# constants
DIR_ORIGINAL="`pwd`"
DIR_PROJECTS="Projects"
DIRNAME_SOURCE="SourceCode"
DIR_SOURCE="${DIR_ORIGINAL}/${DIRNAME_SOURCE}"
DIRNAME_IDFS="InputFiles"
DIR_IDFS="${DIR_ORIGINAL}/Test_Files-Utilities/InternalTests/${DIRNAME_IDFS}"
IDD_NAME="Energy+.idd"
PATH_IDD="${DIR_ORIGINAL}/Release/${IDD_NAME}"
DIR_SRC_FINAL="src"
GIT_IGNORE=".gitignore"

# exit codes
ERR_PERMISSION=101
ERR_PROJECTEXISTS=102

# convenience functions
function issueError { 
    zenity --error --text "$1"
    if [ "$#" -gt "1" ]; then
        exit $2
    fi
}
function issueDone { 
    echo "[DONE]" 
}

# make sure base project directory exists, this should also provide a permission/access problem
mkdir -p "${DIR_PROJECTS}"
if [ $? != 0 ]; then
    issueError "Could not create Projects directory, probably a permission or access problem.  Aborting!"
    exit ${ERR_PERMISSION}
fi

# get a new project name
PROJECTNAME=$(zenity --entry --text "Enter a new project name" --entry-text "NewProject" --title "Project Name")
DIRPROJECT="${DIR_PROJECTS}/${PROJECTNAME}"

# check if this already exists before we do anything else
if [ -d "${DIRPROJECT}" ]; then
    issueError "Project '${PROJECTNAME}' already exists, please try again with a new project name that does not exist in the ${DIR_PROJECTS} directory"
    exit ${ERR_PROJECTEXISTS}
fi

# looks like we are good to go, make the dir
echo -n "Creating project directory ... "
mkdir -p "${DIRPROJECT}"
issueDone

# for reporting purposes, go ahead and count the files we'll be transferring
COUNT_SRC=`ls "${DIR_SOURCE}" | wc -l`
COUNT_IDF=`ls "${DIR_IDFS}" | wc -l`

# copy stuff over
echo -n "Copying ${COUNT_SRC} source code files ... "
cp -r "${DIR_SOURCE}" "${DIRPROJECT}"
issueDone
echo -n "Copying ${COUNT_IDF} input data files ... "
cp -r "${DIR_IDFS}" "${DIRPROJECT}"
issueDone
echo -n "Copying input data dictionary ... "
cp "${PATH_IDD}" "${DIRPROJECT}"
issueDone

# move into the project directory
cd "${DIRPROJECT}"

# configure for my project appearance
echo -n "Configuring project directory ... "
mv "${DIRNAME_SOURCE}" "${DIR_SRC_FINAL}"
issueDone

# create and initialize git repository
echo -n "Initializing project git repository ... "
git init > /dev/null 2>&1
issueDone
echo -n "Initializing ${GIT_IGNORE} file (ignoring InputFiles directory) ... "
echo "${DIRNAME_IDFS}" > "${GIT_IGNORE}"
issueDone
echo -n "Staging files into git ... "
git add "${DIR_SRC_FINAL}" > /dev/null 2>&1
git add "${IDD_NAME}" > /dev/null 2>&1
git add "${GIT_IGNORE}"
issueDone
echo -n "Performing first commit into git repository ... "
git commit -m 'Initial commit of source and IDD' > /dev/null 2>&1
issueDone

# move back into the original directory
cd "${DIR_ORIGINAL}"
    
    
