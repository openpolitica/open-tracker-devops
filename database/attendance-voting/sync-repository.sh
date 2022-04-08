#!/bin/bash

source utils/check_execution.sh
#Init directory 
INIT_DIR=${PWD}

#Set environment variables
source ${INIT_DIR}/load-credentials.sh

./attendance-voting/prepare.sh
checkPreviousCommand "Preparing repository failed. Exiting."
