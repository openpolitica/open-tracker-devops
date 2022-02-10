#!/bin/bash

#Init directory 
INIT_DIR=${PWD}

#Expected backup
if [[ -z $BACKUP_FOLDER ]]; then
  BACKUP_FOLDER=${INIT_DIR}/backup
fi

BACKUP_NAME=backup_bills.sql
BACKUP_FILE=$BACKUP_FOLDER/$BACKUP_NAME

#1. Create image if not exists
if [[ ! -f $BACKUP_FILE ]]; then
  echo "Backup file not found, creating it..."
  ./projects/create-image.sh
  echo "Backup created"
fi

#2. Update remote backup
DRIVE_SYNC_FOLDER=drive-sync 

if [[ ! -z $GOOGLE_AUTH_ENCODED ]]; then
	echo $GOOGLE_AUTH_ENCODED | ${INIT_DIR}/tools/decode-key.sh > $DRIVE_SYNC_FOLDER/key.json
fi


cd $DRIVE_SYNC_FOLDER
npm ci --only=production
npm run update  -- --type=projects --source-path=$BACKUP_FILE

