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

#Set environment variables
source ${INIT_DIR}/load-credentials.sh

SHEET_SYNC_FOLDER=sheet-sync
if [[ ! -z $GOOGLE_AUTH_ENCODED ]]; then
	echo $GOOGLE_AUTH_ENCODED | ${INIT_DIR}/tools/decode-key.sh > $SHEET_SYNC_FOLDER/key.json
fi

cd $SHEET_SYNC_FOLDER
npm ci --only=production
npm run reset -- --sheet-id ${GLOSSARY_SHEET_ID} --enable-markdown
