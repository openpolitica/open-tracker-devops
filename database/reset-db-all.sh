#!/bin/bash
#Init directory 
INIT_DIR=${PWD}

if [[ $ENV_TYPE == 'staging' ]]; then
	export FOLDER_NAME=staging
elif [[ $ENV_TYPE == 'production' ]]; then
	export FOLDER_NAME=production
fi

if [[ ! -z $GOOGLE_AUTH_INFO ]]; then
	export GOOGLE_AUTH_INFO=$GOOGLE_AUTH_INFO
fi

#First reset static data
./reset-db-static.sh

#Then reset dynamic  data
./reset-db-dynamic.sh
