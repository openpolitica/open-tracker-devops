#!/bin/bash
#Init directory 
INIT_DIR=${PWD}

if [[ $ENV_TYPE == 'staging' ]]; then
	export FOLDER_NAME=staging
elif [[ $ENV_TYPE == 'production' ]]; then
	export FOLDER_NAME=production
fi

#Set environment variables
source ${INIT_DIR}/load-credentials.sh

#Run the script to load the database
./reset.sh

#Update column names
./rename-columns.sh

#Add slugs
./add-slugs.sh
