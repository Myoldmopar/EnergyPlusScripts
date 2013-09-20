#!/bin/bash

# constants
DIR_ORIGINAL="`pwd`"
DIR_PROJECTS="Projects"
DIR_CRS_FIX="CRs-Fix"
DIR_CRS_VERIFY="CRs-Verify"
DIRNAME_STARTEAM="StarTeam"
DIRNAME_SOURCE="SourceCode"
DIR_STARTEAM="${DIR_ORIGINAL}/${DIRNAME_STARTEAM}"
DIR_SOURCE="${DIR_STARTEAM}/${DIRNAME_SOURCE}"
DIRNAME_IDFS="InputFiles"
DIR_IDFS="${DIR_STARTEAM}/Test_Files-Utilities/InternalTests/${DIRNAME_IDFS}"
IDD_NAME="Energy+.idd"
PATH_IDD="${DIR_STARTEAM}/Release/${IDD_NAME}"
DIR_SRC_FINAL="src"
GIT_IGNORE=".gitignore"

# exit codes
ERR_PERMISSION=101
ERR_PROJECTEXISTS=102
ERR_CANCELLED=103

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

# get a new project type
PROJTYPECR='CR-Fix'
PROJTYPECRV='CR-Verify'
PROJTYPEPROJ='Project'
PROJTYPE=`zenity --list --title='Project type?' --text='Is this a CR or Project?' --print-column='2' --column='Select...' --column='Type' --radiolist TRUE ${PROJTYPECR} FALSE ${PROJTYPECRV} FALSE ${PROJTYPEPROJ}`

# give a chance to cancel
if [ $? != 0 ]; then
    exit $ERR_CANCELLED
fi

# process the type
if [ "${PROJTYPE}" == "${PROJTYPECR}" ]; then
    DIR_TARGET="${DIR_CRS_FIX}"
elif [ "${PROJTYPE}" == "${PROJTYPECRV}" ]; then
    DIR_TARGET="${DIR_CRS_VERIFY}"
elif [ "${PROJTYPE}" == "${PROJTYPEPROJ}" ]; then
    DIR_TARGET="${DIR_PROJECTS}"
fi

# make sure target project directory exists, this should also provide a permission/access problem
mkdir -p "${DIR_TARGET}"
if [ $? != 0 ]; then
    issueError "Could not create target directory (${DIR_TARGET}), probably a permission or access problem.  Aborting!"
    exit ${ERR_PERMISSION}
fi

# get a new project name
PROJECTNAME=$(zenity --entry --text "Enter a new project name" --entry-text "NewProject" --title "Project Name")

# give a chance to cancel
if [ $? != 0 ]; then
    exit $ERR_CANCELLED
fi

DIRPROJECT="${DIR_TARGET}/${PROJECTNAME}"

# check if this already exists before we do anything else
if [ -d "${DIRPROJECT}" ]; then
    issueError "Project '${PROJECTNAME}' already exists, please try again with a new project name that does not exist in the ${DIR_TARGET} directory"
    exit ${ERR_PROJECTEXISTS}
fi

# looks like we are good to go, make the dir(s)
echo -n "Creating project directory structure ... "
mkdir -p "${DIRPROJECT}"
mkdir -p "${DIRPROJECT}/${DIRNAME_IDFS}"
issueDone

# for reporting purposes, go ahead and count the files we'll be transferring
COUNT_SRC=`ls "${DIR_SOURCE}" | wc -l`
COUNT_IDF=`ls "${DIR_IDFS}" | wc -l`

# copy stuff over
echo -n "Copying ${COUNT_SRC} source code files ... "
cp -r "${DIR_SOURCE}" "${DIRPROJECT}"
issueDone
echo -n "Copying ${COUNT_IDF} input data files ... "
for file in "${DIR_IDFS}"/*.idf; do
    # this loop makes sure we don't copy the 'other' files in the starteam idf dir
    cp "${file}" "${DIRPROJECT}/${DIRNAME_IDFS}/"
done
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
echo -n "Initializing ${GIT_IGNORE} file (ignoring InputFiles directory and E+ outputs) ... "
echo "${DIRNAME_IDFS}" > "${GIT_IGNORE}"
echo 'eplusout.*' >> "${GIT_IGNORE}"
echo 'in.idf' >> "${GIT_IGNORE}"
echo 'inBackup.idf' >> "${GIT_IGNORE}"
echo 'bin' >> "${GIT_IGNORE}"
echo '*.ini' >> "${GIT_IGNORE}"
echo '*.audit' >> "${GIT_IGNORE}"
echo 'eplusssz.csv' >> "${GIT_IGNORE}"
echo 'epluszsz.csv' >> "${GIT_IGNORE}"
echo 'eplustbl.*' >> "${GIT_IGNORE}"
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
    
    
