#!/bin/bash

BASEDIR=$PWD
echo "$BASEDIR directory"

#Check the enviroment type
if [[ -z $ENV_TYPE ]]; then
	echo "Using default ENV_TYPE staging"
	ENV_TYPE=staging
fi

#Check enviroment variables required
if [[ -z $HOST_DOMAIN ]]; then
	echo "Using default HOST_DOMAIN"
	HOST_DOMAIN=localhost
fi

if [[ -z $EMAIL_DOMAIN ]]; then
	echo "Using default EMAIL_DOMAIN"
	EMAIL_DOMAIN=mail@example.com
fi

if [[ -z $DB_PASS ]]; then
	echo "Using default DB_PASS"
	DB_PASS=mywppass
fi

if [[ -z $PROJECT_DIRECTORY ]]; then
	echo "Using default PROJECT_DIRECTORY"
	PROJECT_DIRECTORY=${HOME}/congreso
fi

export HOST_DOMAIN=$HOST_DOMAIN
export EMAIL_DOMAIN=$EMAIL_DOMAIN
export DB_PASS=$WP_DB_PASS
export WITH_NGINX=$WITH_NGINX
export ENV_TYPE=$ENV_TYPE
export PROJECT_DIRECTORY=$PROJECT_DIRECTORY

#Create docker-network
echo "Creating docker network..."
./create-network.sh

#Nginx-proxy
echo "Nginx-proxy deployment..."
cd nginx-proxy
./deploy.sh

cd $BASEDIR
#Worpress
echo "Backend deployment..."
cd backend
./deploy.sh

echo "Deployment has finished"
