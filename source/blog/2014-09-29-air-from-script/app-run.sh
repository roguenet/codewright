#!/bin/bash

pushd `dirname $0` > /dev/null

# empty the current file out, if it exists, otherwise create it for tailing
echo -n "" > out.log
# start ADL in the background, passing in our command-line arguments
adl airdesc.xml -- $@ &
ADL_PID=$!

# Pipe to /dev/null to avoid doubled up output from tail. Start tail in the background
tail -F out.log > /dev/null &
TAIL_PID=$!

# Wait for ADL to finish
wait $ADL_PID

# Now that ADL is done, kill tail, cleanup and exit
disown $TAIL_PID
kill -9 $TAIL_PID
rm out.log

popd > /dev/null
