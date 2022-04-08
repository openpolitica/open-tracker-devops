#!/bin/bash

source utils/check_execution.sh

function update_with_pgloader() {
  if [[ -z $OUTSIDE_DOCKER_NETWORK ]]; then

    if [[ -z $DOCKER_NETWORK ]]; then
      DOCKER_NETWORK=nginx-proxy
    fi
    docker run --rm --name pgloader --net $DOCKER_NETWORK --env PGPASSWORD=$PGPASSWORD -v "$PWD":/home -w /home dimitri/pgloader:ccl.latest pgloader $1
  else 
    echo "Deploy outside docker network"
    docker run --rm --name pgloader --env PGPASSWORD=$PGPASSWORD -v "$PWD":/home -w /home dimitri/pgloader:ccl.latest pgloader $1
  fi
  checkPreviousCommand "Execution of docker failed"
}
