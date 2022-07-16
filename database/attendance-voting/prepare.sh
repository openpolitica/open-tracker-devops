#!/bin/bash 
#Init directory 
INIT_DIR=${PWD}

if [[ -z $PROJECT_DIRECTORY ]]; then
	PROJECT_DIRECTORY=${HOME}/congreso
fi

GIT_BRANCH="main"

mkdir -p ${PROJECT_DIRECTORY}

DATA_DIRECTORY=${PROJECT_DIRECTORY}/congreso-pleno-asistencia-votacion

# Check if directory and repository exists
if [[ -d $DATA_DIRECTORY ]]; then
	cd ${DATA_DIRECTORY}
	#Check if is a repository
	if git rev-parse --is-inside-work-tree > /dev/null 2>&1 ; then
		git fetch origin ${GIT_BRANCH}
		git reset --hard origin/${GIT_BRANCH}
	else
		cd ../
		rm -rf ${DATA_DIRECTORY}
	  git clone https://github.com/openpolitica/congreso-pleno-asistencia-votacion.git
		cd ${DATA_DIRECTORY}
		git checkout origin/${GIT_BRANCH}
	fi
else 
	cd ${PROJECT_DIRECTORY}
	git clone https://github.com/openpolitica/congreso-pleno-asistencia-votacion.git
	cd ${DATA_DIRECTORY}
	git checkout ${GIT_BRANCH}
fi


cd ${DATA_DIRECTORY}
#Build databases
rm -rf *.db*
mkdir -p ~/.m2
docker run --rm --name attendance-voting \
	-v ~/.m2:/var/maven/.m2 -u ${UID} -e MAVEN_CONFIG=/var/maven/.m2 \
	-v "$(pwd)":/usr/src/mymaven \
	-w /usr/src/mymaven maven:3.8.4-openjdk-17 \
	/bin/bash -c "mvn clean compile exec:java -Duser.home=/var/maven -Dexec.mainClass='op.congreso.pleno.app.CargaPlenos'; mvn exec:java -Duser.home=/var/maven -Dexec.mainClass='op.congreso.pleno.app.CargaRegitroPlenos'"

docker run --rm --name plenary-days \
	-v "$(pwd)":/usr/src/myapp \
	-w /usr/src/myapp python:3.9 \
	/bin/bash -c "pip install csvs-to-sqlite; csvs-to-sqlite plenos.csv plenos.db; chown ${UID}:0 plenos.db"


