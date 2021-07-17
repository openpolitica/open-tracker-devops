#!/bin/bash
# Script based on 
# https://gist.github.com/smxsm/67a348b79d5cd4119c24b5902ba56f53

# Adds this variable to control the deployment
if [[ -z $WITH_NGINX ]]; then
  echo "Not deploying nginx. Skipping..." 
else 

  if [ ! "$(docker ps | grep nginx-proxy)" ]; then
      if [ "$(docker ps -aq -f name=nginx-proxy)" ]; then
          # cleanup
          echo "Cleaning Nginx Proxy ..."
          docker rm nginx-proxy
      fi
      # run your container in our global network shared by different projects
      echo "Running Nginx Proxy in global nginx-proxy network ..."
      docker-compose up -d
  else
    echo "Nginx Proxy already running."
  fi
fi
