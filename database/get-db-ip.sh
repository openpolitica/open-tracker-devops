#!/bin/bash
if [ -z $FOLDER_NAME ]; then
  FOLDER_NAME=backend
fi
PGHOST=`sudo docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${FOLDER_NAME}_open_tracker_db_1`

echo $PGHOST
