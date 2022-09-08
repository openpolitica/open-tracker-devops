#!/bin/bash
####### REQUIRES TO SET ENVIRONMENT VALUES #########
# export PGDATABASE=database_name
# export PGHOST=localhost_or_remote_host
# export PGPORT=database_port
# export PGUSER=database_user
# export PGPASSWORD=database_password
# export OUTSIDE_DOCKER_NETWORK

source utils/check_execution.sh
source utils/sql.sh
source utils/pgloader.sh
source utils/check_db.sh

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
  ./attendance-voting/prepare.sh
  checkPreviousCommand "Preparing database failed. Exiting."
fi

LOCAL_DB_FOLDER=./attendance-voting/db
mkdir -p ${LOCAL_DB_FOLDER}

LOCAL_PLENARY_DB_PATH=${LOCAL_DB_FOLDER}/${PLENARY_DB_FILENAME}
LOCAL_ATTENDANCE_DB_PATH=${LOCAL_DB_FOLDER}/${ATTENDANCE_DB_FILENAME}

# Copy from repository to local directory to be used by pgloader
echo "Copying dbs from repository to local path"
cp ${PLENARY_DB_PATH} ${LOCAL_PLENARY_DB_PATH}
cp ${ATTENDANCE_DB_PATH} ${LOCAL_ATTENDANCE_DB_PATH}


# Includes all working tables
working_tables=(\
  plenos \
  votacion_resultado \
  votacion_grupo_parlamentario \
  votacion_congresista \
  asistencia_resultado \
  asistencia_grupo_parlamentario \
  asistencia_congresista \
  #Corresponding english name
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

for table_name in ${working_tables[@]}; do
  sqlcmd "DROP TABLE IF EXISTS \"$table_name\" CASCADE;"
done

# Import Plenary days
# Requires pgloader
echo "----------------------------------------------"
echo "#### Import plenary days"
command_file="$(cat << EOF
load database
     from ${LOCAL_PLENARY_DB_PATH}
     into pgsql://${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE}

 WITH include drop, create tables, create indexes, reset sequences

  SET work_mem to '128 MB', maintenance_work_mem to '512 MB'

 WITH batch size = 5MB, prefetch rows = 25000

 CAST type string to text;
EOF
)"
echo "$command_file" > script 
update_with_pgloader script
rm script


# Import Attendance and voting
# Requires pgloader
echo "----------------------------------------------"
echo "#### Import attendance and voting"
command_file="$(cat << EOF
load database
     from ${LOCAL_ATTENDANCE_DB_PATH}
     into pgsql://${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE}

 WITH include drop, create tables, create indexes, reset sequences

  SET work_mem to '128 MB', maintenance_work_mem to '512 MB'

 WITH batch size = 5MB, prefetch rows = 25000

 CAST type string to text;
EOF
)"
echo "$command_file" > script 
update_with_pgloader script
rm script

./rename-columns.sh

# 1. Add slugs to tables
# Add slugs to facilitate comparison with legislature
echo "----------------------------------------------"
echo "#### Add slug to plenary_session table "
sqlcmd "
ALTER TABLE plenary_session ADD COLUMN IF NOT EXISTS legislature_slug text;
UPDATE plenary_session SET legislature_slug =
slugify(legislature::TEXT);
"

echo "----------------------------------------------"
echo "#### Add slug to attendance_congressperson table "
sqlcmd "
ALTER TABLE attendance_congressperson ADD COLUMN IF NOT EXISTS congressperson_slug text;
UPDATE attendance_congressperson SET congressperson_slug =
slugify(concat(split_part(congressperson::TEXT,',', 2), ' ',
split_part(congressperson::TEXT,',', 1)));
"

echo "----------------------------------------------"
echo "#### Add slug to voting_congressperson table "
sqlcmd "
ALTER TABLE voting_congressperson ADD COLUMN IF NOT EXISTS congressperson_slug text;
UPDATE voting_congressperson SET congressperson_slug =
slugify(concat(split_part(congressperson::TEXT,',', 2), ' ',
split_part(congressperson::TEXT,',', 1)));
"

# 2. Create auxiliary tables 

echo "----------------------------------------------"
echo "#### Create attendance in session table "
sqlcmd "
DROP TABLE IF EXISTS \"attendance_in_session\";
CREATE TABLE attendance_in_session AS
SELECT DISTINCT parliamentary_period, annual_period, 
legislature, date, time, plenary_session_title, quorum
FROM attendance_result;
"


echo "----------------------------------------------"
echo "#### Create voting in session table "
sqlcmd "
DROP TABLE IF EXISTS \"voting_in_session\";
CREATE TABLE voting_in_session AS
SELECT DISTINCT parliamentary_period, annual_period, 
legislature, date, time, plenary_session_title, quorum, subject, president, tags
FROM voting_result;
"

# 3. Generate UUIDs for plenary_session voting_in_session and
# attendance_in_session tables
# requires the function created in add_uuids.sh script

sqlcmd "
SELECT add_uuid('plenary_session');
SELECT add_uuid('attendance_in_session');
SELECT add_uuid('voting_in_session');
SELECT add_uuid('attendance_result');
SELECT add_uuid('attendance_congressperson');
SELECT add_uuid('attendance_parliamentary_group');
SELECT add_uuid('voting_result');
SELECT add_uuid('voting_congressperson');
SELECT add_uuid('voting_parliamentary_group');
"


## 2. Fix if they are wrong (not matched values)
## Some names are wrong in the congress project page
echo "----------------------------------------------"
echo "#### Fix slug names"

wrong_slugs=(\
  "arturo-alegria-garcia" \
  "campos-hernando-guerra-garcia" \
  "ernesto-bustamante-donayre" \
  "vivian-olivos-martinez" \
)

right_slugs=(\
  "luis-arturo-alegria-garcia" \
  "hernando-guerra-garcia-campos" \
  "carlos-ernesto-bustamante-donayre" \
  "leslie-vivian-olivos-martinez" \
)

j=0
for slug in ${wrong_slugs[@]}; do
  sqlcmd "
   UPDATE attendance_congressperson SET congressperson_slug = '${right_slugs[j]}' WHERE
   congressperson_slug = '${wrong_slugs[j]}';"
  sqlcmd "
   UPDATE voting_congressperson SET congressperson_slug = '${right_slugs[j]}' WHERE
   congressperson_slug = '${wrong_slugs[j]}';"
  ((j++))
done

# In case of avanza pais, some codes are wrong
echo "----------------------------------------------"
echo "#### Fix parliamentary_group id"
wrong_codes=(\
  "AVP" \
  "APAIS" \
  "CD" \
)

right_codes=(\
  "AP-PIS" \
  "AP-PIS" \
  "CD-JPP"
)

j=0
for slug in ${wrong_codes[@]}; do
  sqlcmd "
   UPDATE attendance_parliamentary_group SET parliamentary_group =
   '${right_codes[j]}' WHERE
   parliamentary_group = '${wrong_codes[j]}';"
  sqlcmd "
   UPDATE voting_parliamentary_group SET parliamentary_group =
   '${right_codes[j]}' WHERE
   parliamentary_group = '${wrong_codes[j]}';"
  ((j++))
done

# 3. Add corresponding IDs
echo "----------------------------------------------"
echo "#### Add legislature_id to plenary_session table "
SELECTED_PARLIAMENTARY_PERIOD="Congreso de la República - Periodo Parlamentario 2021 - 2026"

sqlcmd "
ALTER TABLE plenary_session ADD COLUMN IF NOT EXISTS legislature_id uuid;
UPDATE plenary_session SET legislature_id = legislature.legislature_id
FROM legislature 
WHERE plenary_session.parliamentary_period = '${SELECTED_PARLIAMENTARY_PERIOD}'
AND plenary_session.legislature_slug = RTRIM(legislature.legislature_slug,
'-2013456') ;
"

# Create function to relate by date
sqlcmd "
DROP FUNCTION IF EXISTS relate_by_date(text, text);
CREATE OR REPLACE FUNCTION relate_by_date(target_table text, reference_table text)
RETURNS void as \$\$
BEGIN
  EXECUTE format('ALTER TABLE %I 
    ADD COLUMN IF NOT EXISTS %I_id uuid;', target_table, reference_table);
  EXECUTE format('UPDATE %s SET %s_id = %s.id
    FROM %s WHERE %s.date = %s.date;', 
    target_table, reference_table,
    reference_table, reference_table, reference_table, target_table);
  EXECUTE format('ALTER TABLE %s
    ADD CONSTRAINT %s_%s_fk1 FOREIGN KEY (\"%s_id\") 
    REFERENCES %s (\"id\") 
    ON DELETE NO ACTION ON UPDATE NO ACTION;', 
    target_table, target_table, reference_table, reference_table, reference_table);
END;
\$\$ LANGUAGE plpgsql;
"
echo "----------------------------------------------"
echo "#### Add plenary_session_id to attendance_in_session table "
sqlcmd "
SELECT relate_by_date('attendance_in_session', 'plenary_session');
"

echo "----------------------------------------------"
echo "#### Add plenary_session_id to voting_in_session table "
sqlcmd "
SELECT relate_by_date('voting_in_session', 'plenary_session');
"

echo "----------------------------------------------"
echo "#### Add voting and attendance id to related tables table "
# Create function to relate by date and time
sqlcmd "
DROP FUNCTION IF EXISTS relate_by_date_and_time(text, text);
CREATE OR REPLACE FUNCTION relate_by_date_and_time(target_table text, reference_table text)
RETURNS void as \$\$
BEGIN
  EXECUTE format('ALTER TABLE %I 
    ADD COLUMN IF NOT EXISTS %I_id uuid;', target_table, reference_table);
  EXECUTE format('UPDATE %s SET %s_id = %s.id
    FROM %s WHERE %s.date = %s.date AND %s.time = %s.time;', 
    target_table, reference_table,
    reference_table, reference_table, reference_table, target_table,
    reference_table, target_table);
  EXECUTE format('ALTER TABLE %s
    ADD CONSTRAINT %s_%s_fk1 FOREIGN KEY (\"%s_id\") 
    REFERENCES %s (\"id\") 
    ON DELETE NO ACTION ON UPDATE NO ACTION;', 
    target_table, target_table, reference_table, reference_table, reference_table);
END;
\$\$ LANGUAGE plpgsql;
"

sqlcmd "
SELECT relate_by_date_and_time('attendance_result', 'attendance_in_session');
SELECT relate_by_date_and_time('attendance_congressperson', 'attendance_in_session');
SELECT relate_by_date_and_time('attendance_parliamentary_group', 'attendance_in_session');
"

sqlcmd "
SELECT relate_by_date_and_time('voting_result', 'voting_in_session');
SELECT relate_by_date_and_time('voting_congressperson', 'voting_in_session');
SELECT relate_by_date_and_time('voting_parliamentary_group', 'voting_in_session');
"


echo "----------------------------------------------"
echo "#### Add congressperson_id to attendance and voting tables "
sqlcmd "
ALTER TABLE attendance_congressperson ADD COLUMN IF NOT EXISTS
congressperson_id integer;
UPDATE attendance_congressperson SET congressperson_id = congressperson.cv_id
FROM congressperson 
WHERE congressperson.congressperson_slug =
attendance_congressperson.congressperson_slug;
"
# Validating
check_null_values "attendance_congressperson" "congressperson_id"
checkPreviousCommand "Ids has null values. Exiting."

sqlcmd "
ALTER TABLE voting_congressperson ADD COLUMN IF NOT EXISTS
congressperson_id integer;
UPDATE voting_congressperson SET congressperson_id = congressperson.cv_id
FROM congressperson 
WHERE congressperson.congressperson_slug = 
voting_congressperson.congressperson_slug;
"

# Validating
check_null_values "voting_congressperson" "congressperson_id"
checkPreviousCommand "Ids has null values. Exiting."

echo "----------------------------------------------"
echo "#### Add parliamentary_group_id to attendance and voting tables "
sqlcmd "
ALTER TABLE attendance_parliamentary_group ADD COLUMN IF NOT EXISTS
parliamentary_group_id uuid;
UPDATE attendance_parliamentary_group SET parliamentary_group_id =
parliamentary_group.parliamentary_group_id
FROM parliamentary_group 
WHERE parliamentary_group.parliamentary_group_code =
attendance_parliamentary_group.parliamentary_group;
"

# Validating
check_null_values "attendance_parliamentary_group" "parliamentary_group_id"
checkPreviousCommand "Ids has null values. Exiting."

sqlcmd "
ALTER TABLE voting_parliamentary_group ADD COLUMN IF NOT EXISTS
parliamentary_group_id uuid;
UPDATE voting_parliamentary_group SET parliamentary_group_id =
parliamentary_group.parliamentary_group_id
FROM parliamentary_group 
WHERE parliamentary_group.parliamentary_group_code = 
voting_parliamentary_group.parliamentary_group;
"

# Validating
check_null_values "voting_parliamentary_group" "parliamentary_group_id"
checkPreviousCommand "Ids has null values. Exiting."

#4. Update datatypes
# Change datatypes to plenary
echo "----------------------------------------------"
echo "#### Change datatypes"
sqlcmd "
ALTER TABLE plenary_session ALTER COLUMN date TYPE date using date::date;
ALTER TABLE voting_in_session ALTER COLUMN date TYPE date using date::date;
ALTER TABLE attendance_in_session ALTER COLUMN date TYPE date using date::date;
ALTER TABLE voting_in_session ALTER COLUMN time TYPE time using time::time;
ALTER TABLE attendance_in_session ALTER COLUMN time TYPE time using time::time;
"

#5. Add missing indexes and foreign keys
echo "----------------------------------------------"
echo "#### Add indexes and foreign keys"
sqlcmd "
ALTER TABLE plenary_session
  ADD CONSTRAINT plenary_session_legislature_fk1 FOREIGN KEY (\"legislature_id\") 
  REFERENCES legislature (\"legislature_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  
"

sqlcmd "
ALTER TABLE attendance_congressperson
  ADD CONSTRAINT attendance_congressperson_congressperson_fk1 
  FOREIGN KEY (\"congressperson_id\") 
  REFERENCES congressperson (\"cv_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  
"

sqlcmd "
ALTER TABLE voting_congressperson
  ADD CONSTRAINT voting_congressperson_congressperson_fk1 
  FOREIGN KEY (\"congressperson_id\") 
  REFERENCES congressperson (\"cv_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  
"

sqlcmd "
ALTER TABLE attendance_parliamentary_group
  ADD CONSTRAINT attendance_parliamentary_group_parliamentary_group_fk1 
  FOREIGN KEY (\"parliamentary_group_id\") 
  REFERENCES parliamentary_group (\"parliamentary_group_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  
"

sqlcmd "
ALTER TABLE voting_parliamentary_group
  ADD CONSTRAINT voting_parliamentary_group_parliamentary_group_fk1 
  FOREIGN KEY (\"parliamentary_group_id\") 
  REFERENCES parliamentary_group (\"parliamentary_group_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  
"

#CREATE INDEX bill_idx ON bill(id, period, number,legislature_id,
#  last_committee_id,parliamentary_group_id, last_status_id);
#
#CREATE INDEX authorship_idx ON authorship(bill_id, congressperson_id, 
#  authorship_type);
#"

# 5. Obtain metrics for congressperson
echo "----------------------------------------------"
echo "#### Create metrics for congressperson"
sqlcmd "
DROP TABLE IF EXISTS attendance_congressperson_metrics;
CREATE TABLE attendance_congressperson_metrics AS
SELECT agg.*,
(agg.present::FLOAT8 / agg.count::FLOAT8)*100.0 AS present_percentage,
(agg.absent::FLOAT8 / agg.count::FLOAT8)*100.0 AS absent_percentage,
(agg.license_total::FLOAT8 / agg.count::FLOAT8)*100.0 AS license_percentage,
(agg.other_total::FLOAT8 / agg.count::FLOAT8)*100.0 AS other_percentage
FROM
(SELECT summary.*, 
summary.license_illness + summary.license_official + summary.license_personal
AS license_total,
summary.fault + summary.dead AS other_total
FROM
(SELECT attendance_congressperson.congressperson_id, 
count(id) as count,
sum(case result when 'PRE' then 1 else 0 end) as present,
sum(case result when 'AUS' then 1 else 0 end) as absent,
sum(case result when 'LE' then 1 else 0 end) as license_illness,
sum(case result when 'LO' then 1 else 0 end) as license_official,
sum(case result when 'LP' then 1 else 0 end) as license_personal,
sum(case result when 'FA' then 1 else 0 end) as fault,
sum(case result when 'F' then 1 else 0 end) as dead
FROM attendance_congressperson GROUP BY congressperson_id) summary) agg;
"

sqlcmd "
ALTER TABLE attendance_congressperson_metrics
  ADD CONSTRAINT attendance_congressperson_metrics_congressperson_fk1 
  FOREIGN KEY (\"congressperson_id\") 
  REFERENCES congressperson (\"cv_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  
"

echo "----------------------------------------------"
echo "#### Create metrics for parliamentary_group"
sqlcmd "
ALTER TABLE attendance_parliamentary_group
  ADD COLUMN IF NOT EXISTS present_percentage float8;
UPDATE attendance_parliamentary_group SET present_percentage =
CASE WHEN total!=0 THEN (present::float8 / total::float8)*100.0 ELSE 0.0 END;
;

ALTER TABLE attendance_parliamentary_group
  ADD COLUMN IF NOT EXISTS absent_percentage float8;
UPDATE attendance_parliamentary_group SET absent_percentage =
CASE WHEN total!=0 THEN (absent::float8 / total::float8)*100.0 ELSE 0.0 END;

ALTER TABLE attendance_parliamentary_group
  ADD COLUMN IF NOT EXISTS license_percentage float8;
UPDATE attendance_parliamentary_group SET license_percentage =
CASE WHEN total!=0 THEN (license::float8 / total::float8)*100.0 ELSE 0.0 END;

ALTER TABLE attendance_parliamentary_group
  ADD COLUMN IF NOT EXISTS other_percentage float8;
UPDATE attendance_parliamentary_group SET other_percentage =
CASE WHEN total!=0 THEN (other::float8 / total::float8)*100.0 ELSE 0.0 END;
"

sqlcmd "
DROP TABLE IF EXISTS attendance_parliamentary_group_metrics;
CREATE TABLE attendance_parliamentary_group_metrics AS
SELECT attendance_parliamentary_group.parliamentary_group_id, 
count(id) as count,
avg(present_percentage) as present_percentage_mean,
avg(absent_percentage) as absent_percentage_mean,
avg(license_percentage) as license_percentage_mean,
avg(other_percentage) as other_percentage_mean
FROM attendance_parliamentary_group
WHERE attendance_parliamentary_group.total != 0
GROUP BY parliamentary_group_id;
"

sqlcmd "
ALTER TABLE attendance_parliamentary_group_metrics
  ADD CONSTRAINT attendance_parliamentary_group_metrics_parliamentary_group_fk1 
  FOREIGN KEY (\"parliamentary_group_id\") 
  REFERENCES parliamentary_group (\"parliamentary_group_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  
"
