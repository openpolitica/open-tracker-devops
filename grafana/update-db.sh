#!/bin/bash
INIT_DIR=${PWD}

if [[ -z $PROJECT_DIRECTORY ]]; then
	PROJECT_DIRECTORY=${HOME}/congreso
fi

DATA_DIRECTORY=${PROJECT_DIRECTORY}/congreso-pleno-asistencia-votacion
PLENARY_DB_FILENAME=plenos.db
ATTENDANCE_DB_FILENAME=2021-2026-asistencias-votaciones.db
PLENARY_DB_PATH=${DATA_DIRECTORY}/${PLENARY_DB_FILENAME}
ATTENDANCE_DB_PATH=${DATA_DIRECTORY}/${ATTENDANCE_DB_FILENAME}

if [[ ! -f ${PLENARY_DB_PATH}  || ! -f ${ATTENDANCE_DB_PATH} ]]; then
	cd ../database
  ./attendance-voting/prepare.sh
fi

cd ${INIT_DIR}

LOCAL_DB_FOLDER=./db
mkdir -p ${LOCAL_DB_FOLDER}

LOCAL_PLENARY_DB_PATH=${LOCAL_DB_FOLDER}/${PLENARY_DB_FILENAME}
LOCAL_ATTENDANCE_DB_PATH=${LOCAL_DB_FOLDER}/${ATTENDANCE_DB_FILENAME}

# Copy from repository to local directory to be used by pgloader
echo "Copying dbs from repository to local path"
sudo cp ${PLENARY_DB_PATH} ${LOCAL_PLENARY_DB_PATH}
sudo cp ${ATTENDANCE_DB_PATH} ${LOCAL_ATTENDANCE_DB_PATH}

#This is required to enable access to database
sudo chown -R 472:root ./db
