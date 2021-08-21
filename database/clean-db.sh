#!/bin/bash
####### REQUIRES TO SET ENVIRONMENT VALUES #########
# export PGDATABASE=database_name
# export PGHOST=localhost_or_remote_host
# export PGPORT=database_port
# export PGUSER=database_user
# export PGPASSWORD=database_password

SQLCMD="psql -U ${PGUSER} -w  -h ${PGHOST} -c "

#https://stackoverflow.com/a/21247009/5107192
$SQLCMD "
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO public;
"
