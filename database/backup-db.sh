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
DATE_BACKUP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FOLDER=${INIT_DIR}/backup

mkdir -p $BACKUP_FOLDER

if [[ ! -z $IS_TEMPORAL ]]; then
	PREFIX=tmp_
fi

pg_dump $PGDATABASE > ${BACKUP_FOLDER}/${PREFIX}db_backup_${DATE_BACKUP}.sql
