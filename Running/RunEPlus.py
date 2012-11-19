#!/usr/bin/python

# import calls
import pynotify         # for notifications
import os               # for some file I/O operations
import subprocess       # for executing the (E+) program
import sys              # for allowing a clean exit
import shutil

# debug spewer and flag
def Out(msg, DoDebug = False):
    if DoDebug:
        print " < debug > " + msg

# defaults if nothing else given
exName = "myproject_intel_debug"
idf = "in.idf"
iconUri = "file:///home/edwin/bin/ep.png"
goodIconUri = "file:///home/edwin/bin/mark_success.png"
badIconUri = "file:///home/edwin/bin/mark_error.png"

# there should be at least one command line argument: the name of the (E+) executable in the current directory
Out("len of argv list = %i" % len(sys.argv))
if len(sys.argv) > 1:
    exName = sys.argv[1]
    Out("Executable: " + sys.argv[1])
if len(sys.argv) > 2:
    idf = sys.argv[2]
    Out("Overriding input file with: " + sys.argv[2])
if len(sys.argv) > 3 or len(sys.argv) == 1:
    Out("Usage: " + sys.argv[0] + " Executable File [Input File]", True)
    exit()

# get this for execution and reporting
curDir = os.getcwd()
Out("Operating in current directory = " + curDir)
localDir = curDir.split("/")[-1]
localExecPath = ".../%s/%s" % (localDir, exName)

# check that the executable specified actually exists
if not os.path.exists(curDir+"/"+exName):
    Out("Could not find executable at the following path: " + curDir + "/" + exName)
    exit()
else:
    Out("Going to execute program at the following path: " + curDir + "/" + exName)

# init the notification library
pynotify.init("RunEPlus")

# remove the previous end file, if it exists
if os.path.exists("eplusout.end"):
    Out("Encountered eplusout.end file")
    try:
        os.remove("eplusout.end")
        Out("Deleted eplusout.end file")
    except:
        Out("Couldn't delete eplusout.end file! ...Aborting...")
        exit()
else:
    Out("eplusout.end was not found...good...")

# prepare input files, remove previous output files
if os.path.exists("inBackup.idf"):
    os.remove("inBackup.idf")
if idf != "in.idf":
    if os.path.exists("in.idf"):
        shutil.copy("in.idf","inBackup.idf")
        #p = subprocess.Popen("cp in.idf inBackup.idf")
        #p.wait()
    shutil.copy(idf, "in.idf")
    #p = subprocess.Popen("cp " + idf + " inBackup.idf")
    #p.wait()
if os.path.exists("eplusout.csv"):
    os.remove("eplusout.csv")

# start-up notification
notif = pynotify.Notification("Simulation Starting", "%s" % (localExecPath), iconUri) 
notif.show()
Out("Showed startup notification")

# execute the application
p = subprocess.Popen(curDir + "/" + exName) #, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
Out("Executed program")
retval = p.wait()
Out("Waited for program to re-join")

# make sure the end file was created
if not os.path.exists("eplusout.end"):
    Out("eplusout.end was not created...something's wrong!")
    notif.update("Simulation Failed?", "%s" % (exName), badIconUri) 
    notif.show()
    exit()

# try to read the eplusout.end file
endFile = open("eplusout.end", 'r')
result = endFile.read()
Out("Opened and read resulting eplusout.end file")

# check if the result was successful and update the notifier
if "SUCCESS" in result.upper():
    # try to parse out the run time:
    runTime = result.split(";")[2].split("=")[1].strip()
    notif.update("Simulation Completed", "%s\nRun Time = %s" % (localExecPath,runTime), goodIconUri) 
    Out("Issued successful simulation notification")
    # try to run readvars as well now
    Out("Running readvars")
    p = subprocess.Popen(["readvars", "", "unlimited"])
    retval = p.wait()
    Out("readvars re-joined")    
else:
    notif.update(" * * Simulation Failed! * * ", "%s" % (localExecPath), badIconUri) 
    Out("Issued erroroneous simulation notification")

# re-show the notification
notif.show()
    
