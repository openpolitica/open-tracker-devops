#!/bin/bash
# This script add slugs to names in database
####### REQUIRES TO SET ENVIRONMENT VALUES #########
# export PGDATABASE=database_name
# export PGHOST=localhost_or_remote_host
# export PGPORT=database_port
# export PGUSER=database_user
# export PGPASSWORD=database_password

source utils/check_execution.sh
source utils/sql.sh

sqlcmd "
CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";

DROP FUNCTION IF EXISTS add_uuid(text);
CREATE OR REPLACE FUNCTION add_uuid(tablename text)
RETURNS void as \$\$
BEGIN
  EXECUTE format('ALTER TABLE %I 
    ADD COLUMN IF NOT EXISTS \"id\" uuid', tablename);
  EXECUTE format('UPDATE %s
     SET id=uuid_generate_v4();', tablename);

  if NOT exists (select constraint_name from 
    information_schema.table_constraints where table_name = tablename
    and constraint_type = 'PRIMARY KEY') then

  EXECUTE format('ALTER TABLE %I 
    ADD PRIMARY KEY (id);', tablename);

  end if;
END;
\$\$ LANGUAGE plpgsql;
"

sqlcmd "
SELECT add_uuid('affiliation');
SELECT add_uuid('education');
SELECT add_uuid('electoral_process');
SELECT add_uuid('experience');
SELECT add_uuid('goods_immovable');
SELECT add_uuid('goods_movable');
SELECT add_uuid('judgment_civil');
SELECT add_uuid('judgment_ec');
SELECT add_uuid('judgment_penal');
"
