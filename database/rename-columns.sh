#!/bin/bash
# This script rename the original column names to their english version
####### REQUIRES TO SET ENVIRONMENT VALUES #########
# export PGDATABASE=database_name
# export PGHOST=localhost_or_remote_host
# export PGPORT=database_port
# export PGUSER=database_user
# export PGPASSWORD=database_password

SQLCMD="psql -U ${PGUSER} -w  -h ${PGHOST} -c "

$SQLCMD " DROP TABLE IF EXISTS list_columns;
CREATE TABLE list_columns AS
SELECT
table_name, column_name FROM INFORMATION_SCHEMA.COLUMNS WHERE
TABLE_SCHEMA='public' ORDER BY table_name ASC, column_name ASC;
"

$SQLCMD '''
DROP TABLE IF EXISTS column_name_dict;
CREATE TABLE column_name_dict (
  "column_name" text DEFAULT NULL,
  "column_name_en" text DEFAULT NULL
);
'''
$SQLCMD "\copy column_name_dict (
  \"column_name\",
  \"column_name_en\")
FROM './column_name_dict.csv' DELIMITER ',' QUOTE '\"' CSV HEADER;
"

$SQLCMD "
DROP FUNCTION IF EXISTS change_column_names();
CREATE OR REPLACE FUNCTION change_column_names() 
RETURNS int AS \$\$
DECLARE
  table_column RECORD;
  count int := 0;
  name_en text;
BEGIN
FOR table_column IN 
  SELECT * FROM list_columns 
  WHERE list_columns.column_name IN (SELECT column_name FROM column_name_dict)
  LOOP
     RAISE NOTICE 'Change column name %.%', 
       table_column.table_name,
       table_column.column_name;
     SELECT column_name_en INTO name_en FROM column_name_dict WHERE column_name_dict.column_name=table_column.column_name;
     IF name_en = table_column.column_name THEN
       RAISE NOTICE 'English name is the same as previous name, skipping';
     ELSE
       EXECUTE format('ALTER TABLE %s RENAME COLUMN %s TO %s', table_column.table_name, table_column.column_name, name_en);
       count := count + 1;
     END IF;
  END LOOP;
  RETURN count;
END;
\$\$ LANGUAGE plpgsql;
SELECT change_column_names();
"

$SQLCMD '''
DROP TABLE IF EXISTS table_name_dict;
CREATE TABLE table_name_dict (
  "table_name" text DEFAULT NULL,
  "table_name_en" text DEFAULT NULL
);
'''
$SQLCMD "\copy table_name_dict (
  \"table_name\",
  \"table_name_en\")
FROM './table_name_dict.csv' DELIMITER ',' QUOTE '\"' CSV HEADER;
"

$SQLCMD "
DROP FUNCTION IF EXISTS change_table_names();
CREATE OR REPLACE FUNCTION change_table_names() 
RETURNS int AS \$\$
DECLARE
  table_record RECORD;
  count int := 0;
  name_en text;
BEGIN
FOR table_record IN 
  SELECT DISTINCT table_name FROM list_columns 
  WHERE list_columns.table_name IN (SELECT table_name FROM table_name_dict)
  LOOP
     RAISE NOTICE 'Change table name %', 
       table_record.table_name;
     SELECT table_name_en INTO name_en FROM table_name_dict WHERE table_name_dict.table_name=table_record.table_name;
     IF name_en = table_record.table_name THEN
       RAISE NOTICE 'English name is the same as previous name, skipping';
     ELSE
       EXECUTE format('ALTER TABLE %s RENAME TO %s', table_record.table_name, name_en);
       count := count + 1;
     END IF;
  END LOOP;
  RETURN count;
END;
\$\$ LANGUAGE plpgsql;
SELECT change_table_names();
"

