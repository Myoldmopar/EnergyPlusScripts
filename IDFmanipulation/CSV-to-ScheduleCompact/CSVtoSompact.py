#!/usr/bin/python

# inputs, could be brought in as command line args
# -- should be hourly for now, could make it more general
fName = "CoolingLoads.csv"
schName = "Load Profile Load Schedule"
schTypeLimits = "CW Loop Any Number"
zeroBasedValColumnIndex = 1

# initialize the list
vals = []

# open the file for reading
with open(fName) as f:

    # read the first line, header
    line = f.readline()

    # loop indefinitely
    while True:
        
        # read a data line
        line = f.readline()
        if not line:
            break
        
        # add the value to the list
        vals.append(line.split(",")[1].strip())
    
# set up some constants    
hoursInDay = 24
daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]    

def writeOneHour(hour, val, last):
    if last:
        print "   Until: " + str(hour).zfill(2) + ":00, " + str(val) + ";"
    else:
        print "   Until: " + str(hour).zfill(2) + ":00, " + str(val) + ","

# output the first part of the schedule
print "Schedule:Compact,\n  " + schName + ",\n  " + schTypeLimits + ","

hourCounter = 0
for monthNum in range(len(daysInMonth)):
    for date in range(daysInMonth[monthNum]):
        print "  Through: " + str(monthNum+1).zfill(2) + "/" + str(date+1).zfill(2) + ", " + "For: AllDays,"
        for hour in range(24):
            hourCounter += 1
            writeOneHour(hour+1, vals[hourCounter-1], hourCounter==len(vals))
            
