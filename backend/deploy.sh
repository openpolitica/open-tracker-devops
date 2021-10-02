#!/bin/bash 
#Init directory 
INIT_DIR=${PWD}

if [[ -z $ENV_TYPE ]]; then
	ENV_TYPE=staging
fi

if [[ -z $HOST_DOMAIN ]]; then
	HOST_DOMAIN=localhost
fi

if [[ -z $EMAIL_DOMAIN ]]; then
	EMAIL_DOMAIN=mail@example.com
fi

if [[ -z $DB_PASS ]]; then
	DB_PASS=op123%
fi

if [[ -z $PROJECT_DIRECTORY ]]; then
	PROJECT_DIRECTORY=${HOME}/congreso
fi

# Verify environment
if [[ $ENV_TYPE == "production" ]]; then
	ENV_DIRECTORY=${PROJECT_DIRECTORY}/production
	GIT_BRANCH=main
else
	ENV_DIRECTORY=${PROJECT_DIRECTORY}/staging
	GIT_BRANCH=dev
fi

mkdir -p ${ENV_DIRECTORY}

BACKEND_DIRECTORY=${ENV_DIRECTORY}/open-tracker-backend

# Check if directory and repository exists
if [[ -d $BACKEND_DIRECTORY ]]; then
	cd ${BACKEND_DIRECTORY}
	#Check if is a repository
	if git rev-parse --is-inside-work-tree > /dev/null 2>&1 ; then
		git fetch origin ${GIT_BRANCH}
		git reset --hard origin/${GIT_BRANCH}
	else
		cd ../
		rm -rf ${BACKEND_DIRECTORY}
	  git clone https://github.com/openpolitica/open-tracker-backend.git
		git checkout origin/${GIT_BRANCH}
	fi
else 
	cd ${ENV_DIRECTORY}
	git clone https://github.com/openpolitica/open-tracker-backend.git
	git checkout origin/${GIT_BRANCH}
fi

#Add configuration files for backend
cd ${BACKEND_DIRECTORY}
cp ${INIT_DIR}/Dockerfile ./

docker build -t openpolitica/open_tracker_backend:${GIT_BRANCH} -f Dockerfile . 

cd ${ENV_DIRECTORY}

if [[ $ENV_TYPE == "production" ]]; then
	cp ${INIT_DIR}/docker-compose.production.yml ./docker-compose.yml
else
	cp ${INIT_DIR}/docker-compose.yml ./
fi

#Check if .env file exists and delete previous generated 
if [[ -f ".env" ]]; then
	sed -i '/HOST_DOMAIN=/d' .env
	sed -i '/EMAIL_DOMAIN=/d' .env
	sed -i '/DB_PASS=/d' .env
	sed -i '/GIT_BRANCH=/d' .env
fi

echo "HOST_DOMAIN=${HOST_DOMAIN}" >> .env
echo "EMAIL_DOMAIN=${EMAIL_DOMAIN}" >> .env
echo "DB_PASS=${DB_PASS}" >> .env
echo "GIT_BRANCH=${GIT_BRANCH}" >> .env

docker-compose up -d 
