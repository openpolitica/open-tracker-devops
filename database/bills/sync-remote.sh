#!/bin/bash

#Init directory 
INIT_DIR=${PWD}

#1. Create image
./projects/create-image.sh

#2. Update remote backup
DRIVE_SYNC_FOLDER=drive-sync 

if [[ ! -z $GOOGLE_AUTH_ENCODED ]]; then
	echo $GOOGLE_AUTH_ENCODED | ${INIT_DIR}/tools/decode-key.sh > $DRIVE_SYNC_FOLDER/key.json
fi

if [[ -z $BACKUP_FOLDER ]]; then
  BACKUP_FOLDER=${INIT_DIR}/backup
fi

BACKUP_NAME=backup_projects.sql

cd $DRIVE_SYNC_FOLDER
npm ci --only=production
npm run update  -- --type=projects --source-path=$BACKUP_FOLDER/$BACKUP_NAME

