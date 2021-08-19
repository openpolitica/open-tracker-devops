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

SHEET_SYNC_FOLDER=sheet-sync
if [[ ! -z $GOOGLE_AUTH_INFO ]]; then
	echo $GOOGLE_AUTH_INFO > $SHEET_SYNC_FOLDER/key.json
fi

cd $SHEET_SYNC_FOLDER
npm ci --only=production
npm run reset 
