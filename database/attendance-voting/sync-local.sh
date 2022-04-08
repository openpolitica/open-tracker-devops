#!/bin/bash

source utils/check_execution.sh

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
BACKUP_NAME_LOCAL=backup_attendance_voting_local.sql
BACKUP_NAME_REMOTE=backup_attendance_voting_remote.sql
BACKUP_FILEPATH_LOCAL=${BACKUP_FOLDER}/${BACKUP_NAME_LOCAL}
BACKUP_FILEPATH_REMOTE=${BACKUP_FOLDER}/${BACKUP_NAME_REMOTE}

function dump_command() {
  if [[ -z $OUTSIDE_DOCKER_NETWORK ]]; then

    if [[ -z $DOCKER_NETWORK ]]; then
      DOCKER_NETWORK=nginx-proxy
    fi
    docker run --rm --name pgclient \
      --net $DOCKER_NETWORK \
      --env PGPASSWORD=$PGPASSWORD \
      --env PGUSER=$PGUSER \
      --env PGHOST=$PGHOST \
      --env PGDATABASE=$PGDATABASE \
      -v "$PWD":/home \
      -w /home \
      postgres pg_dump "$@"
  else 
    echo "Deploy outside docker network"
    docker run --rm --name pgclient \
      --env PGPASSWORD=$PGPASSWORD \
      --env PGUSER=$PGUSER \
      --env PGHOST=$PGHOST \
      --env PGDATABASE=$PGDATABASE \
      -v "$PWD":/home \
      -w /home \
      postgres pg_dump "$@"
  fi
  checkPreviousCommand "Dump function has failed."
}


function join_by { local IFS="$1"; shift; echo "$*"; }

tables_to_backup=(\
  plenary_session \
  voting_result \
  voting_parliamentary_group \
  voting_congressperson \
  attendance_result \
  attendance_parliamentary_group \
  attendance_congressperson \
  attendance_in_session \
  voting_in_session \
  attendance_congressperson_metrics \
  attendance_parliamentary_group_metrics \
  )

#Create dump from local database
echo "Creating dump for local database"
dump_command --data-only --table="($(join_by \| ${tables_to_backup[@]}))" > $BACKUP_FILEPATH_LOCAL

#Get backup file from Google drive
DRIVE_SYNC_FOLDER=drive-sync 

if [[ ! -z $GOOGLE_AUTH_ENCODED ]]; then
	echo $GOOGLE_AUTH_ENCODED | ${INIT_DIR}/tools/decode-key.sh > $DRIVE_SYNC_FOLDER/key.json
fi

cd $DRIVE_SYNC_FOLDER
npm ci --only=production
npm run download  -- --type=attendanceVoting --dest-path=$BACKUP_FILEPATH_REMOTE
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
./attendance-voting/clean-tables.sh
checkPreviousCommand "Cleaning tables has failed. Exiting"

psql -v ON_ERROR_STOP=1 -U ${PGUSER} -w  -h ${PGHOST} -d ${PGDATABASE} < $BACKUP_FILEPATH_REMOTE

checkPreviousCommand "Updating tables failed. Exiting."
