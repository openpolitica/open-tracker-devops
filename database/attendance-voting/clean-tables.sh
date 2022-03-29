#!/bin/bash
####### REQUIRES TO SET ENVIRONMENT VALUES #########
# export PGDATABASE=database_name
# export PGHOST=localhost_or_remote_host
# export PGPORT=database_port
# export PGUSER=database_user
# export PGPASSWORD=database_password
# export OUTSIDE_DOCKER_NETWORK


# Includes all working tables
working_tables=(\
  plenary_session \
  voting_result \
  voting_parliamentary_group \
  voting_congressperson \
  attendance_result \
  attendance_parliamentary_group \
  attendance_congressperson \
  attendance_in_session \
  voting_in_session \
  attendance_congressperson_metrics \
  attendance_parliamentary_group_metrics \
)

SQLCMD="psql -U ${PGUSER} -w  -h ${PGHOST} -c "

# Add safe sql truncate
# based on https://stackoverflow.com/a/63004824/5107192
$SQLCMD "
CREATE OR REPLACE FUNCTION public.truncate_if_exists(_table text, _schema text DEFAULT NULL)
  RETURNS text
  LANGUAGE plpgsql AS
\$\$
DECLARE
   _qual_tbl text := concat_ws('.', quote_ident(_schema), quote_ident(_table));
   _row_found bool;
BEGIN
   IF to_regclass(_qual_tbl) IS NOT NULL THEN   -- table exists
      EXECUTE 'SELECT EXISTS (SELECT FROM ' || _qual_tbl || ')'
      INTO _row_found;

      IF _row_found THEN                        -- table is not empty
         EXECUTE 'TRUNCATE ' || _qual_tbl || ' CASCADE';
         RETURN 'Table truncated: ' || _qual_tbl;
      ELSE  -- optional!
         RETURN 'Table exists but is empty: ' || _qual_tbl;
      END IF;
   ELSE  -- optional!
      RETURN 'Table not found: ' || _qual_tbl;
   END IF;
END
\$\$;
"

for table_name in ${working_tables[@]}; do
  $SQLCMD "SELECT truncate_if_exists('$table_name');"
done
