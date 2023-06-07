print "********************************************";
print "*                                          *";
print "*             TOSSIM Script                *";
print "*                                          *";
print "********************************************";

import sys;
import time;

from TOSSIM import *;

t = Tossim([]);


topofile="topology.txt";
modelfile="meyer-heavy.txt";


print "Initializing mac....";
mac = t.mac();
print "Initializing radio channels....";
radio=t.radio();
print "    using topology file:",topofile;
print "    using noise file:",modelfile;
print "Initializing simulator....";
t.init();


#simulation_outfile = "simulation.txt";
#print "Saving sensors simulation output to:", simulation_outfile;
#simulation_out = open(simulation_outfile, "w");

#out = open(simulation_outfile, "w");
out = sys.stdout;

#Add debug channel

print "Activate debug message on channel TIMER"
t.addChannel("TIMER",out);
print "Activate debug message on channel BOOT"
t.addChannel("BOOT",out);
print "Activate debug message on channel STARTDONE"
t.addChannel("STARTDONE",out);
print "Activate debug message on channel STOPDONE"
t.addChannel("STOPDONE",out);
print "Activate debug message on channel REQUEST"
t.addChannel("REQUEST",out);
print "Activate debug message on channel CLEAR"
t.addChannel("CLEAR",out);
#print "Activate debug message on channel RECEIVE"
t.addChannel("RECEIVE",out);
print "Activate debug message on channel RECEIVEBOTH"
t.addChannel("RECEIVEBOTH",out);
print "Activate debug message on channel RECEIVERTS"
t.addChannel("RECEIVERTS",out);
print "Activate debug message on channel SENDDONE"
t.addChannel("SENDDONE",out);
print "Activate debug message on channel COUNTER"
t.addChannel("COUNTER",out);
print "Activate debug message on channel PER"
t.addChannel("PER",out);
print "Activate debug message on channel PROBABILITY"
t.addChannel("PROBABILITY",out);
print "Activate debug message on channel role"
t.addChannel("role",out);
"""

"""


print "Creating node 1...";
node1 = t.getNode(1);
time1 = 0*t.ticksPerSecond(); #instant at which each node should be turned on
node1.bootAtTime(time1);
print ">>>Will boot at time",  time1/t.ticksPerSecond(), "[sec]";

print "Creating node 2...";
node2 = t.getNode(2);
time2 = 0*t.ticksPerSecond();
node2.bootAtTime(time2);
print ">>>Will boot at time", time2/t.ticksPerSecond(), "[sec]";

print "Creating node 3...";
node3 = t.getNode(3);
time3 = 0*t.ticksPerSecond();
node3.bootAtTime(time3);
print ">>>Will boot at time", time3/t.ticksPerSecond(), "[sec]";

print "Creating node 4...";
node4 = t.getNode(4);
time4 = 0*t.ticksPerSecond();
node4.bootAtTime(time4);
print ">>>Will boot at time", time4/t.ticksPerSecond(), "[sec]";

print "Creating node 5...";
node5 = t.getNode(5);
time5 = 0*t.ticksPerSecond();
node5.bootAtTime(time5);
print ">>>Will boot at time", time5/t.ticksPerSecond(), "[sec]";

print "Creating node 6...";
node6 = t.getNode(6);
time6 = 0*t.ticksPerSecond();
node6.bootAtTime(time6);
print ">>>Will boot at time", time6/t.ticksPerSecond(), "[sec]";

print "Creating radio channels..."
f = open(topofile, "r");
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print ">>>Setting radio channel from node ", s[0], " to node ", s[1], " with gain ", s[2], " dBm"
    radio.add(int(s[0]), int(s[1]), float(s[2]))


#creation of channel model
print "Initializing Closest Pattern Matching (CPM)...";
noise = open(modelfile, "r")
lines = noise.readlines()
compl = 0;
mid_compl = 0;

print "Reading noise model data file:", modelfile;
print "Loading:",
for line in lines:
    str = line.strip()
    if (str != "") and ( compl < 10000 ):
        val = int(str)
        mid_compl = mid_compl + 1;
        if ( mid_compl > 5000 ):
            compl = compl + mid_compl;
            mid_compl = 0;
            sys.stdout.write ("#")
            sys.stdout.flush()
        for i in range(1, 7):
            t.getNode(i).addNoiseTraceReading(val)
print "Done!";

for i in range(1, 7):
    print ">>>Creating noise model for node:",i;
    t.getNode(i).createNoiseModel()

print "Start simulation with TOSSIM! \n\n\n";

for i in range(0,500000):
	t.runNextEvent()

print "\n\n\nSimulation finished!";
