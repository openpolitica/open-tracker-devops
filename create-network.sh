#!/bin/bash -x
# This file is based on 
# https://gist.github.com/smxsm/67a348b79d5cd4119c24b5902ba56f53

#Create external network to communicate other containers
if [ ! "$(docker network ls | grep nginx-proxy)" ]; then
  echo "Creating nginx-proxy network ..."
  docker network create nginx-proxy
else
  echo "nginx-proxy network exists."
fi
