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

#Perform the backup
BACKUP_FOLDER=${INIT_DIR}/backup

if [[ ! -d $BACKUP_FOLDER ]]; then
	echo "Error: backup folder doesn't exist under $BACKUP_FOLDER"
	exit 1
fi

if [[ -z $BACKUP_NAME ]]; then
	EXTENSION=.sql
	if [[ ! -z $IS_TEMPORAL ]]; then
	  PREFIX=tmp_
		LAST_DATE=$(ls ${BACKUP_FOLDER} | awk -F '[.]' '{print $1}' | awk -F '[_]' '{if ($1 == "tmp") print $4"_"$5;}' | sort -r | head -n 1 )
	else
		LAST_DATE=$(ls ${BACKUP_FOLDER} | awk -F '[.]' '{print $1}' | awk -F '[_]' '{if ($1 != "tmp") print $3"_"$4;}' | sort -r | head -n 1 )
	fi
	
	BACKUP_NAME=${PREFIX}"db_backup_"${LAST_DATE}${EXTENSION}
fi

echo "Restore $BACKUP_NAME"
./clean-db.sh
psql $PGDATABASE < ${BACKUP_FOLDER}/${BACKUP_NAME}
