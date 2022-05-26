#!/bin/bash 
#Init directory 
INIT_DIR=${PWD}

if [[ -z $PROJECT_DIRECTORY ]]; then
	PROJECT_DIRECTORY=${HOME}/congreso/twitter-bot
fi

mkdir -p ${PROJECT_DIRECTORY}

GIT_BRANCH=main

TWITTER_BOT_DIRECTORY=${PROJECT_DIRECTORY}/open-tracker-twitter-bot # Check if directory and repository exists
if [[ -d ${TWITTER_BOT_DIRECTORY} ]]; then
	cd ${TWITTER_BOT_DIRECTORY}
	#Check if is a repository
	if git rev-parse --is-inside-work-tree > /dev/null 2>&1 ; then
		git fetch origin ${GIT_BRANCH}
		git reset --hard origin/${GIT_BRANCH}
	else
		cd ../
		rm -rf ${TWITTER_BOT_DIRECTORY}
	  git clone git@github.com:openpolitica/open-tracker-twitter-bot.git
		git checkout origin/${GIT_BRANCH}
	fi
else 
	cd ${PROJECT_DIRECTORY}
	git clone git@github.com:openpolitica/open-tracker-twitter-bot.git
	cd ${TWITTER_BOT_DIRECTORY}
	git checkout origin/${GIT_BRANCH}
fi

#Add configuration files for backend
cd ${TWITTER_BOT_DIRECTORY}
cp ${INIT_DIR}/Dockerfile ./

docker build -t openpolitica/open-tracker-twitter-bot:${GIT_BRANCH} -f Dockerfile . 

cd ${PROJECT_DIRECTORY}

cp ${INIT_DIR}/docker-compose.yml ./

#Check if .env file exists and delete previous generated 
if [[ -f ".env" ]]; then
	sed -i '/CONSUMER_KEY=/d' .env
	sed -i '/CONSUMER_SECRET=/d' .env
	sed -i '/ACCESS_TOKEN_KEY=/d' .env
	sed -i '/ACCESS_TOKEN_SECRET=/d' .env
  sed -i '/TUKU_BOT_WEBHOOK_EVERYTHING_OK=/d' .env
	sed -i '/GIT_BRANCH=/d' .env
fi

echo "CONSUMER_KEY=${CONSUMER_KEY}" >> .env
echo "CONSUMER_SECRET=${CONSUMER_SECRET}" >> .env
echo "ACCESS_TOKEN_KEY=${ACCESS_TOKEN_KEY}" >> .env
echo "ACCESS_TOKEN_SECRET=${ACCESS_TOKEN_SECRET}" >> .env
echo "TUKU_BOT_WEBHOOK_EVERYTHING_OK=${TUKU_BOT_WEBHOOK_EVERYTHING_OK}" >> .env
echo "GIT_BRANCH=${GIT_BRANCH}" >> .env

docker-compose up -d 
