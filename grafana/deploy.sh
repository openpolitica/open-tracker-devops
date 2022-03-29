#!/bin/bash
#Init directory 
INIT_DIR=${PWD}

if [[ -z $GRAFANA_USERNAME ]]; then
	GRAFANA_USERNAME=op
fi

if [[ -z $GRAFANA_PASSWORD ]]; then
	GRAFANA_PASSWORD=op123%
fi

if [[ -z $HOST_DOMAIN ]]; then
	HOST_DOMAIN=localhost
fi

if [[ -z $EMAIL_DOMAIN ]]; then
	EMAIL_DOMAIN=mail@example.com
fi

#Update dbs
./update-db.sh

#Check if .env file exists and delete previous generated 
if [[ -f ".env" ]]; then
	sed -i '/HOST_DOMAIN=/d' .env
	sed -i '/EMAIL_DOMAIN=/d' .env
	sed -i '/GRAFANA_USERNAME=/d' .env
	sed -i '/GRAFANA_PASSWORD=/d' .env
fi

echo "HOST_DOMAIN=${HOST_DOMAIN}" >> .env
echo "EMAIL_DOMAIN=${EMAIL_DOMAIN}" >> .env
echo "GRAFANA_USERNAME=${GRAFANA_USERNAME}" >> .env
echo "GRAFANA_PASSWORD=${GRAFANA_PASSWORD}" >> .env

docker-compose up -d
