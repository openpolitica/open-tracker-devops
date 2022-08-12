#!/bin/bash

source utils/check_execution.sh

function update_with_pgloader() {

  if [[ -z $PGLOADER_CONTAINER_NAME ]]; then
    PGLOADER_CONTAINER_NAME=pgloader
  fi
  
  if [[ -z $OUTSIDE_DOCKER_NETWORK ]]; then

    if [[ -z $DOCKER_NETWORK ]]; then
      DOCKER_NETWORK=nginx-proxy
    fi
    docker run --rm --name $PGLOADER_CONTAINER_NAME --net $DOCKER_NETWORK --env PGPASSWORD=$PGPASSWORD -v "$PWD":/home -w /home dimitri/pgloader:ccl.latest pgloader $1
  else 
    echo "Deploy outside docker network"
    docker run --rm --name $PGLOADER_CONTAINER_NAME --env PGPASSWORD=$PGPASSWORD -v "$PWD":/home -w /home dimitri/pgloader:ccl.latest pgloader $1
  fi
  checkPreviousCommand "Execution of docker failed"
}
