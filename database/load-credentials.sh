#!/bin/bash 
# Script to load credentials employed for other scripts

if [ -z $PGHOST ]; then
  echo "Environment variable PGHOST not set, replacing by default value"

  if [ -z $FOLDER_NAME ]; then
    echo "No deployment folder name provided. Supposed under backend."
    FOLDER_NAME=backend
  fi
  PGHOST=`sudo docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${FOLDER_NAME}_open_tracker_db_1`
fi

if [ -z $PGPASSWORD ]; then
  echo "Environment variable PGPASSWORD not set, replacing by default value"
  PGPASSWORD=op123%
fi

if [ -z $PGPORT ]; then
  echo "Environment variable PGPORT not set, replacing by default value"
  PGPORT=5432
fi

if [ -z $PGUSER ]; then
  echo "Environment variable PGUSER not set, replacing by default value"
  PGUSER=op
fi

if [ -z $PGDATABASE ]; then
  echo "Environment variable PGDATABASE not set, replacing by default value"
  PGDATABASE=op
fi

export PGHOST=$PGHOST
export PGPASSWORD=$PGPASSWORD
export PGPORT=$PGPORT
export PGDATABASE=$PGDATABASE
export PGUSER=$PGUSER
