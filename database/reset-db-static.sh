#!/bin/bash

source utils/check_execution.sh

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

#Run the script to load the database
./reset.sh
checkPreviousCommand "Reset JNE data has failed. Exiting."

#Update column names
./rename-columns.sh
checkPreviousCommand "Renaming columns has failed. Exiting."

#Add slugs
./add-slugs.sh
checkPreviousCommand "Adding slugs has failed. Exiting."

#Add uuids for tables
./add-uuids.sh
checkPreviousCommand "Adding uuids has failed. Exiting."
