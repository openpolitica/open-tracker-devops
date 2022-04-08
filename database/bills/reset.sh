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

INIT_DIR=${PWD}

if [[ -z $PROJECT_DIRECTORY ]]; then
	PROJECT_DIRECTORY=${HOME}/congreso
fi

DATA_DIRECTORY=${PROJECT_DIRECTORY}/congreso-proyecto-ley
BILLS_DB_FILENAME=proyectos-ley-2021-2026.db
BILLS_DB_PATH=${DATA_DIRECTORY}/${BILLS_DB_FILENAME}

if [[ ! -f ${BILLS_DB_PATH}  ]]; then
  ./bills/prepare.sh
fi

LOCAL_DB_FOLDER=./bills/db
mkdir -p ${LOCAL_DB_FOLDER}

LOCAL_BILLS_DB_PATH=${LOCAL_DB_FOLDER}/${BILLS_DB_FILENAME}

# Copy from repository to local directory to be used by pgloader
echo "Copying dbs from repository to local path"
cp ${BILLS_DB_PATH} ${LOCAL_BILLS_DB_PATH}

# Includes all working tables
working_tables=(\
  firmante \
  iniciativa_agrupada \
  seguimiento \
  proyecto_ley \
  #Corresponding english name
  authorship \
  grouped_initiative \
  tracking \
  bill \
)

# Drop foreign keys to avoid locks
sqlcmd "
ALTER TABLE IF EXISTS seguimiento 
DROP CONSTRAINT IF EXISTS seguimiento_proyecto_ley_id_fkey;
ALTER TABLE IF EXISTS tracking 
DROP CONSTRAINT IF EXISTS seguimiento_proyecto_ley_id_fkey;
"

for table_name in ${working_tables[@]}; do
  sqlcmd "DROP TABLE IF EXISTS \"$table_name\" CASCADE;"
done

# Import Congreso
# Requires pgloader
echo "----------------------------------------------"
echo "#### Import bills"
command_file="$(cat << EOF
load database
     from ${LOCAL_BILLS_DB_PATH}
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
# Add slugs to facilitate comparison with congressname
echo "----------------------------------------------"
echo "#### Add slug to authorship table "
sqlcmd "
ALTER TABLE authorship ADD COLUMN IF NOT EXISTS congressperson_slug text;
UPDATE authorship SET congressperson_slug =
slugify(concat(split_part(congressperson::TEXT,',', 2), ' ',
split_part(congressperson::TEXT,',', 1)));
"

echo "----------------------------------------------"
echo "#### Add slugs to tracking table "
sqlcmd "
ALTER TABLE tracking ADD COLUMN IF NOT EXISTS committee_slug text;
UPDATE tracking SET committee_slug =
slugify(committee::TEXT);
"

sqlcmd "
ALTER TABLE tracking ADD COLUMN IF NOT EXISTS status_slug text;
UPDATE tracking SET status_slug =
slugify(status::TEXT);
"

echo "----------------------------------------------"
echo "#### Add slug to bill table "
sqlcmd "
ALTER TABLE bill ADD COLUMN IF NOT EXISTS last_committee_slug text;
UPDATE bill SET last_committee_slug =
slugify(last_committee::TEXT);
"

sqlcmd "
ALTER TABLE bill ADD COLUMN IF NOT EXISTS legislature_slug text;
UPDATE bill SET legislature_slug =
slugify(legislature::TEXT);
"

sqlcmd "
ALTER TABLE bill ADD COLUMN IF NOT EXISTS last_status_slug text;
UPDATE bill SET last_status_slug =
slugify(last_status::TEXT);
"

sqlcmd "
ALTER TABLE bill ADD COLUMN IF NOT EXISTS parliamentary_group_slug text;
UPDATE bill SET parliamentary_group_slug =
slugify(parliamentary_group::TEXT);
"

# 2. Fix if they are wrong (not matched values)
# Some names are wrong in the congress project page
echo "----------------------------------------------"
echo "#### Fix slug names"

wrong_slugs=(\
  "arturo-alegria-garcia" \
  "freddy-roland-diaz-monago" \
  "vivian-olivos-martinez" \
)

right_slugs=(\
  "luis-arturo-alegria-garcia" \
  "freddy-ronald-diaz-monago" \
  "leslie-vivian-olivos-martinez" \
)

j=0
for slug in ${wrong_slugs[@]}; do
  sqlcmd "
   UPDATE authorship SET congressperson_slug = '${right_slugs[j]}' WHERE
   congressperson_slug = '${wrong_slugs[j]}';"
  ((j++))
done

# In case of avanza pais, their name is too long so, use the short name
non_common_slugs=(\
  "avanza-pais---partido-de-integracion-social" \
)

common_slugs=(\
  "avanza-pais" \
)

j=0
for slug in ${non_common_slugs[@]}; do
  sqlcmd "
   UPDATE bill SET parliamentary_group_slug = '${common_slugs[j]}' WHERE
   parliamentary_group_slug = '${non_common_slugs[j]}';"
  ((j++))
done

# 3. Add corresponding IDs
echo "----------------------------------------------"
echo "#### Add id to authorship table "
sqlcmd "
ALTER TABLE authorship ADD COLUMN IF NOT EXISTS congressperson_id integer;
UPDATE authorship SET congressperson_id = congressperson.cv_id
FROM congressperson 
WHERE authorship.congressperson_slug = congressperson.congressperson_slug;
"

echo "----------------------------------------------"
echo "#### Add id to tracking table "
sqlcmd "
ALTER TABLE tracking ADD COLUMN IF NOT EXISTS committee_id uuid;
UPDATE tracking SET committee_id = committee.committee_id
FROM committee 
WHERE tracking.committee_slug = committee.committee_slug;
"

sqlcmd "
ALTER TABLE tracking ADD COLUMN IF NOT EXISTS status_id uuid;
UPDATE tracking SET status_id = bill_status.bill_status_id
FROM bill_status 
WHERE tracking.status_slug = bill_status.bill_status_slug;
"

echo "----------------------------------------------"
echo "#### Add id to bill table "
sqlcmd "
ALTER TABLE bill ADD COLUMN IF NOT EXISTS last_committee_id UUID;
UPDATE bill SET last_committee_id = committee.committee_id
FROM committee 
WHERE bill.last_committee_slug = committee.committee_slug;
"

sqlcmd "
ALTER TABLE bill ADD COLUMN IF NOT EXISTS legislature_id UUID;
UPDATE bill SET legislature_id = legislature.legislature_id
FROM legislature 
WHERE bill.legislature_slug = legislature.legislature_slug;
"

sqlcmd "
ALTER TABLE bill ADD COLUMN IF NOT EXISTS last_status_id UUID;
UPDATE bill SET last_status_id = bill_status.bill_status_id
FROM bill_status 
WHERE bill.last_status_slug = bill_status.bill_status_slug;
"

sqlcmd "
ALTER TABLE bill ADD COLUMN IF NOT EXISTS parliamentary_group_id UUID;
UPDATE bill SET parliamentary_group_id =
parliamentary_group.parliamentary_group_id
FROM parliamentary_group 
WHERE bill.parliamentary_group_slug =
parliamentary_group.parliamentary_group_slug;
"

#4. Update datatypes
echo "----------------------------------------------"
echo "#### Update datatypes"
sqlcmd "
ALTER TABLE bill ALTER COLUMN presentation_date TYPE date USING
presentation_date::date;
ALTER TABLE tracking ALTER COLUMN date TYPE date USING date::date;
"

#5. Add missing indexes and foreign keys
echo "----------------------------------------------"
echo "#### Add indexes and foreign keys"
sqlcmd "
ALTER TABLE bill
  ADD CONSTRAINT bill_committee_fk1 FOREIGN KEY (\"last_committee_id\") 
  REFERENCES committee (\"committee_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  

ALTER TABLE bill
  ADD CONSTRAINT bill_bill_status_fk1 FOREIGN KEY (\"last_status_id\") 
  REFERENCES bill_status (\"bill_status_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  

ALTER TABLE bill
  ADD CONSTRAINT bill_legislature_fk1 FOREIGN KEY (\"legislature_id\") 
  REFERENCES legislature (\"legislature_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  
  
ALTER TABLE bill
  ADD CONSTRAINT bill_parliamentary_group_fk1 FOREIGN KEY
  (\"parliamentary_group_id\") 
  REFERENCES parliamentary_group (\"parliamentary_group_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  

ALTER TABLE tracking
  ADD CONSTRAINT tracking_committee_fk1 FOREIGN KEY
  (\"committee_id\") 
  REFERENCES committee (\"committee_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  

ALTER TABLE tracking
  ADD CONSTRAINT tracking_bill_status_fk1 FOREIGN KEY
  (\"status_id\") 
  REFERENCES bill_status (\"bill_status_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  

ALTER TABLE authorship
  ADD CONSTRAINT authorship_congressperson_fk1 FOREIGN KEY
  (\"congressperson_id\") 
  REFERENCES congressperson (\"cv_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  

CREATE INDEX bill_idx ON bill(id, period, number,legislature_id,
  last_committee_id,parliamentary_group_id, last_status_id);

CREATE INDEX authorship_idx ON authorship(bill_id, congressperson_id, 
  authorship_type);
"
