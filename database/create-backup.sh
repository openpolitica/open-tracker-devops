#!/bin/bash

source utils/check_execution.sh
source utils/sql.sh

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

BACKUP_FOLDER=${INIT_DIR}/backup
mkdir -p $BACKUP_FOLDER
BACKUP_NAME_LOCAL=backup_all_local.sql
BACKUP_FILEPATH_LOCAL=${BACKUP_FOLDER}/${BACKUP_NAME_LOCAL}


#Create dump from local database
echo "Creating dump for local database"
USE_DOCKER_CLIENT=1 
backup_all_db $BACKUP_FILEPATH_LOCAL
