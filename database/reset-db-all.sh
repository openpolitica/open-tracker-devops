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

#First reset static data
./reset-db-static.sh

#Then reset dynamic  data
./reset-db-dynamic.sh
