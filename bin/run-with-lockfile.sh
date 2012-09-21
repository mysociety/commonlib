#!/bin/sh

# This shell script alternative to run-with-lockfile depends on the
# Debian package lockfile-progs (sudo apt-get install lockfile-progs)
# which uses liblockfile for NFS-safe locking.

# The locking strategy is not exactly the same as Chris Lightfoot's
# run-with-lockfile.c [1] but it should be substitutable in many
# circumstances, and in addition is NFS-safe.

# [1] https://secure.mysociety.org/cvstrac/fileview?f=mysociety/run-with-lockfile/run-with-lockfile.c

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

if [ $FAIL_IF_OTHER = true ] && lockfile-check -l "$LOCK_FILENAME"
then
    exit 100
fi

# This is based on the example in lockfile-progs(1):

lockfile-create -l "$LOCK_FILENAME" || exit 101
lockfile-touch -l "$LOCK_FILENAME" &
# Save the PID of the lockfile-touch process:
TOUCH_PID="$!"

export LOCKFILE="$LOCK_FILENAME"
/bin/sh -c "$COMMAND"
COMMAND_EXIT_CODE=$?

kill "${TOUCH_PID}"
lockfile-remove -l "$LOCK_FILENAME"

exit $COMMAND_EXIT_CODE
