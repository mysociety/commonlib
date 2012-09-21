#!/bin/sh

# This shell script alternative to run-with-lockfile depends on the
# Debian package lockfile-progs.  (sudo apt-get install lockfile-progs)

FAIL_IF_OTHER=false

if [ x"$1" = x"-n" ]
then
    FAIL_IF_OTHER=true
    shift
fi

if [ $# != 2 ]
then
    echo "Usage: $0 [-n] FILE COMMAND"
    exit 101
fi

LOCK_FILENAME="$1"
COMMAND="$2"

if [ FAIL_IF_OTHER = true ] && lockfile-check "$LOCK_FILENAME"
then
    exit 100
fi

# This is based on the example in lockfile-progs(1):

lockfile-create "$LOCK_FILENAME"
lockfile-touch "$LOCK_FILENAME" &
# Save the PID of the lockfile-touch process:
TOUCH_PID="$!"

/bin/sh -c "$COMMAND"
COMMAND_EXIT_CODE=$?

kill "${TOUCH_PID}"
lockfile-remove "$LOCK_FILENAME"

exit $COMMAND_EXIT_CODE
