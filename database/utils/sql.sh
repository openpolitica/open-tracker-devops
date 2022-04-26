#!/bin/bash

source utils/check_execution.sh

function sqlcmd() {
    psql -v ON_ERROR_STOP=1 -U ${PGUSER} -w  -h ${PGHOST} -c "$@"
    checkPreviousCommand "Execution of SQL command failed."
}

function clean_db() {
    #https://stackoverflow.com/a/21247009/5107192
    sqlcmd "
    DROP SCHEMA public CASCADE;
    CREATE SCHEMA public;
    GRANT ALL ON SCHEMA public TO public;
    "
}

function dump_command() {
    if [[ -z $USE_DOCKER_CLIENT ]]; then
        pg_dump "$@"
    else
        if [[ -z $OUTSIDE_DOCKER_NETWORK ]]; then

            if [[ -z $DOCKER_NETWORK ]]; then
                DOCKER_NETWORK=nginx-proxy
            fi

            docker run --rm --name pgclient \
                --net $DOCKER_NETWORK \
                --env PGPASSWORD=$PGPASSWORD \
                --env PGUSER=$PGUSER \
                --env PGHOST=$PGHOST \
                --env PGDATABASE=$PGDATABASE \
                -v "$PWD":/home \
                -w /home \
                postgres pg_dump "$@"

        else
            docker run --rm --name pgclient \
                --env PGPASSWORD=$PGPASSWORD \
                --env PGUSER=$PGUSER \
                --env PGHOST=$PGHOST \
                --env PGDATABASE=$PGDATABASE \
                -v "$PWD":/home \
                -w /home \
                postgres pg_dump "$@"
        fi
    fi
    checkPreviousCommand "Dump function has failed."
}

function backup_all_db(){
    dump_command > "$@"
}

function restore_db() {
    psql -v ON_ERROR_STOP=1 -U ${PGUSER} -w  -h ${PGHOST} -d ${PGDATABASE} < "$@"
}
