#!/bin/bash
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
BACKUP_NAME_LOCAL=backup_projects_local.sql
BACKUP_NAME_REMOTE=backup_projects_remote.sql
BACKUP_FILEPATH_LOCAL=${BACKUP_FOLDER}/${BACKUP_NAME_LOCAL}
BACKUP_FILEPATH_REMOTE=${BACKUP_FOLDER}/${BACKUP_NAME_REMOTE}

#Create dump from local database
pg_dump --data-only --table="(law_project|tracking|grouped_initiative|signatory)" > $BACKUP_FILEPATH_LOCAL

#Get backup file from Google drive
DRIVE_SYNC_FOLDER=drive-sync 

if [[ ! -z $GOOGLE_AUTH_ENCODED ]]; then
	echo $GOOGLE_AUTH_ENCODED | ${INIT_DIR}/tools/decode-key.sh > $DRIVE_SYNC_FOLDER/key.json
fi

cd $DRIVE_SYNC_FOLDER
npm ci --only=production
npm run download  -- --type=projects --dest-path=$BACKUP_FILEPATH_REMOTE

# Compare local with remote
# Sort to skip moved lines (requires bash)
DIFFERENCES=`diff -I '^--' <(sort $BACKUP_FILEPATH_LOCAL) <(sort $BACKUP_FILEPATH_REMOTE)`

if [[ -z $DIFFERENCES ]]; then
  echo "Both databases are equal, do nothing"
  exit 0 
fi

# If backup is different from current values clean and update with remote
cd $INIT_DIR
./projects/clean-tables.sh
psql -U ${PGUSER} -w  -h ${PGHOST} -d ${PGDATABASE} < $BACKUP_FILEPATH_REMOTE

