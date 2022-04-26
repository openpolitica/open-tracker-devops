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

if [[ ! -z $GOOGLE_AUTH_ENCODED ]]; then
	export GOOGLE_AUTH_ENCODED=$GOOGLE_AUTH_ENCODED
fi

#Set environment variables
source ${INIT_DIR}/load-credentials.sh

BACKUP_FOLDER=${INIT_DIR}/backup
mkdir -p $BACKUP_FOLDER
BACKUP_NAME_LOCAL=backup_bills_local.sql
BACKUP_NAME_REMOTE=backup_bills_remote.sql
BACKUP_FILEPATH_LOCAL=${BACKUP_FOLDER}/${BACKUP_NAME_LOCAL}
BACKUP_FILEPATH_REMOTE=${BACKUP_FOLDER}/${BACKUP_NAME_REMOTE}


#Create dump from local database
echo "Creating dump for local database"
USE_DOCKER_CLIENT=1 
dump_command --data-only --table="(bill|tracking|grouped_initiative|authorship)" > $BACKUP_FILEPATH_LOCAL

#Get backup file from Google drive
DRIVE_SYNC_FOLDER=drive-sync 

if [[ ! -z $GOOGLE_AUTH_ENCODED ]]; then
	echo $GOOGLE_AUTH_ENCODED | ${INIT_DIR}/tools/decode-key.sh > $DRIVE_SYNC_FOLDER/key.json
fi

cd $DRIVE_SYNC_FOLDER
npm ci --only=production
npm run download  -- --type=bills --dest-path=$BACKUP_FILEPATH_REMOTE
checkPreviousCommand "Downloading bills backup failed. Exiting."

# Compare local with remote
# Sort to skip moved lines (requires bash)
DIFFERENCES=`diff -I '^--' <(sort $BACKUP_FILEPATH_LOCAL) <(sort $BACKUP_FILEPATH_REMOTE)`

if [[ -z $DIFFERENCES ]]; then
  echo "Both databases are equal, do nothing"
  exit 0 
fi

# If backup is different from current values clean and update with remote
cd $INIT_DIR
./bills/clean-tables.sh
checkPreviousCommand "Cleaning tables has failed. Exiting"

restore_db $BACKUP_FILEPATH_REMOTE

checkPreviousCommand "Updating tables failed. Exiting."
