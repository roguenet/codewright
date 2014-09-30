#!/bin/bash

pushd `dirname $0` > /dev/null

# empty the current file out if it exists, otherwise create it for tailing
echo -n "" > out.log
# Start tail in the background
tail -F out.log &
TAIL_PID=$!

# start ADL, passing in our command-line arguments
adl airdesc.xml -- $@

# give it a second to make sure we caught all the output
sleep 1
# Now that ADL is done, kill tail, cleanup and exit
disown $TAIL_PID
kill -9 $TAIL_PID
rm out.log

popd > /dev/null
