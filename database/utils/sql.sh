#!/bin/bash

source utils/check_execution.sh

function sqlcmd() {
    psql -v ON_ERROR_STOP=1 -U ${PGUSER} -w  -h ${PGHOST} -c "$@"
    checkPreviousCommand "Execution of SQL command failed."
}
