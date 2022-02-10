#!/bin/bash
#Init directory 
INIT_DIR=${PWD}

#Create temporary database
TMP_POSTGRES_DB=op
TMP_POSTGRES_USER=op
TMP_POSTGRES_PASSWORD=op
TMP_POSTGRES_PORT=5432
TMP_CONTAINER_NAME=tmp-database

#Delete container if it exists
#https://stackoverflow.com/a/44364288/5107192


function delete_container() {
  docker ps -qa --filter "name=$1" | grep -q . && docker rm -fv $1
}

delete_container $TMP_CONTAINER_NAME
delete_container pgloader

docker run --rm -d --name $TMP_CONTAINER_NAME \
  --env POSTGRES_DB=$TMP_POSTGRES_DB \
  --env POSTGRES_USER=$TMP_POSTGRES_USER \
  --env POSTGRES_PASSWORD=$TMP_POSTGRES_PASSWORD \
  postgres 

TMP_HOST=`docker inspect --format='{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${TMP_CONTAINER_NAME}`

# Wait until is ready for connections
#Based on https://stackoverflow.com/a/63011266/5107192
timeout 90s bash -c "until docker exec $TMP_CONTAINER_NAME pg_isready ; do sleep 5 ; done"


#Load env variables for temporal database
export OUTSIDE_DOCKER_NETWORK=1
export PGDATABASE=$TMP_POSTGRES_DB
export PGHOST=$TMP_HOST
export PGPORT=$TMP_POSTGRES_PORT
export PGUSER=$TMP_POSTGRES_USER
export PGPASSWORD=$TMP_POSTGRES_PASSWORD

./reset-db-all.sh

#Dump database into a file
BACKUP_FOLDER=${INIT_DIR}/backup
mkdir -p $BACKUP_FOLDER
BACKUP_NAME=backup_bills.sql

pg_dump --data-only --table="(bill|tracking|grouped_initiative|authorship)" > $BACKUP_FOLDER/$BACKUP_NAME

delete_container $TMP_CONTAINER_NAME
