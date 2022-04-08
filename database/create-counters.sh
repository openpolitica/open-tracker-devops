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

SUFFIX_TABLE="counter"
SUFFIX_COLUMN="counts"

sqlcmd "
DROP FUNCTION IF EXISTS create_counter_table(text, text, text);
CREATE OR REPLACE FUNCTION create_counter_table(tablename text, idcolumn text,
  slugcolumn text)
RETURNS void as \$\$
BEGIN
  EXECUTE format('DROP TABLE IF EXISTS %s_$SUFFIX_TABLE;', tablename);
  EXECUTE format('CREATE TABLE IF NOT EXISTS %s_$SUFFIX_TABLE 
     AS SELECT %s, %s FROM %s;', tablename, idcolumn, slugcolumn, tablename);

  EXECUTE format('ALTER TABLE %s_$SUFFIX_TABLE
    ADD COLUMN %s_$SUFFIX_COLUMN int DEFAULT 0;', tablename, tablename);

  EXECUTE format('ALTER TABLE %s_$SUFFIX_TABLE
    ADD CONSTRAINT %s_${SUFFIX_TABLE}_fk1 FOREIGN KEY (%s) 
    REFERENCES %s (%s) 
    ON DELETE CASCADE ON UPDATE CASCADE;',
    tablename, tablename, idcolumn, tablename, idcolumn);

  EXECUTE format('CREATE INDEX IF NOT EXISTS %s_index
    ON %s_$SUFFIX_TABLE (%s, %s_$SUFFIX_COLUMN);',
    tablename, tablename, idcolumn, tablename);

END;
\$\$ LANGUAGE plpgsql;
"

sqlcmd "
SELECT create_counter_table('congressperson','cv_id','congressperson_slug');
SELECT create_counter_table('parliamentary_group',
    'parliamentary_group_id','parliamentary_group_slug');
SELECT create_counter_table('location','ubigeo','location_slug');
"
