#!/bin/bash

source ./utils/check_execution.sh

#Init directory 
INIT_DIR=${PWD}

if [[ $ENV_TYPE == 'staging' ]]; then
	export FOLDER_NAME=staging
elif [[ $ENV_TYPE == 'production' ]]; then
	export FOLDER_NAME=production
elif [[ $ENV_TYPE == 'local' ]]; then
	export FOLDER_NAME=backend
fi

#Set environment variables
source ${INIT_DIR}/load-credentials.sh

#Init counters for visited
./create-counters.sh
checkPreviousCommand "Adding counters failed. Exiting"

#Import data from bills
./bills/reset.sh
checkPreviousCommand "Resetting bills failed. Exiting"

#Import data from attendance and voting
./attendance-voting/reset.sh
checkPreviousCommand "Resetting voting failed. Exiting"

#Import data glossary sheet
./glossary/reset.sh
checkPreviousCommand "Resetting glossary failed. Exiting"
