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
  firmante \
  iniciativa_agrupada \
  seguimiento \
  proyecto_ley \
  #Corresponding english name
  signatory \
  grouped_initiative \
  tracking \
  law_project \
)

SQLCMD="psql -U ${PGUSER} -w  -h ${PGHOST} -c "


# Drop foreign keys to avoid locks
$SQLCMD "
ALTER TABLE IF EXISTS seguimiento 
DROP CONSTRAINT IF EXISTS seguimiento_proyecto_ley_id_fkey;
ALTER TABLE IF EXISTS tracking 
DROP CONSTRAINT IF EXISTS seguimiento_proyecto_ley_id_fkey;
"

for table_name in ${working_tables[@]}; do
  $SQLCMD "DROP TABLE IF EXISTS \"$table_name\" CASCADE;"
done


function update_with_pgloader() {
  if [[ -z $OUTSIDE_DOCKER_NETWORK ]]; then

    if [[ -z $DOCKER_NETWORK ]]; then
      DOCKER_NETWORK=nginx-proxy
    fi
    docker run --rm --name pgloader --net $DOCKER_NETWORK --env PGPASSWORD=$PGPASSWORD -v "$PWD":/home -w /home dimitri/pgloader:ccl.latest pgloader $1
  else 
    echo "Deploy outside docker network"
    docker run --rm --name pgloader --env PGPASSWORD=$PGPASSWORD -v "$PWD":/home -w /home dimitri/pgloader:ccl.latest pgloader $1
  fi
}

# Import Congreso
# Requires pgloader
echo "----------------------------------------------"
echo "#### Import projects"
command_file="$(cat << EOF
load database
     from https://congreso-proyecto-ley-ba5dldyyv-openpolitica-user.vercel.app/proyectos-ley-2021-2026.db
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
echo "#### Add slug to signatory table "
$SQLCMD "
ALTER TABLE signatory ADD COLUMN IF NOT EXISTS congressperson_slug text;
UPDATE signatory SET congressperson_slug =
slugify(concat(split_part(congressperson::TEXT,',', 2), ' ',
split_part(congressperson::TEXT,',', 1)));
"

echo "----------------------------------------------"
echo "#### Add slug to tracking table "
$SQLCMD "
ALTER TABLE tracking ADD COLUMN IF NOT EXISTS commission_slug text;
UPDATE tracking SET commission_slug =
slugify(commission::TEXT);
"

echo "----------------------------------------------"
echo "#### Add slug to law_project table "
$SQLCMD "
ALTER TABLE law_project ADD COLUMN IF NOT EXISTS last_commission_slug text;
UPDATE law_project SET last_commission_slug =
slugify(last_commission::TEXT);
"

$SQLCMD "
ALTER TABLE law_project ADD COLUMN IF NOT EXISTS parliamentary_group_slug text;
UPDATE law_project SET parliamentary_group_slug =
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
  $SQLCMD "
   UPDATE signatory SET congressperson_slug = '${right_slugs[j]}' WHERE
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
  $SQLCMD "
   UPDATE law_project SET parliamentary_group_slug = '${common_slugs[j]}' WHERE
   parliamentary_group_slug = '${non_common_slugs[j]}';"
  ((j++))
done

# 3. Add corresponding IDs
echo "----------------------------------------------"
echo "#### Add id to signatory table "
$SQLCMD "
ALTER TABLE signatory ADD COLUMN IF NOT EXISTS congressperson_id integer;
UPDATE signatory SET congressperson_id = congressperson.cv_id
FROM congressperson 
WHERE signatory.congressperson_slug = congressperson.congressperson_slug;
"

echo "----------------------------------------------"
echo "#### Add id to tracking table "
$SQLCMD "
ALTER TABLE tracking ADD COLUMN IF NOT EXISTS commission_id uuid;
UPDATE tracking SET commission_id = commission.commission_id
FROM commission 
WHERE tracking.commission_slug = commission.commission_slug;
"

echo "----------------------------------------------"
echo "#### Add id to law_project table "
$SQLCMD "
ALTER TABLE law_project ADD COLUMN IF NOT EXISTS last_commission_id UUID;
UPDATE law_project SET last_commission_id = commission.commission_id
FROM commission 
WHERE law_project.last_commission_slug = commission.commission_slug;
"

$SQLCMD "
ALTER TABLE law_project ADD COLUMN IF NOT EXISTS parliamentary_group_id UUID;
UPDATE law_project SET parliamentary_group_id =
parliamentary_group.parliamentary_group_id
FROM parliamentary_group 
WHERE law_project.parliamentary_group_slug =
parliamentary_group.parliamentary_group_slug;
"

#4. Update datatypes
echo "----------------------------------------------"
echo "#### Update datatypes"
$SQLCMD "
ALTER TABLE law_project ALTER COLUMN presentation_date TYPE date USING
presentation_date::date;
ALTER TABLE tracking ALTER COLUMN date TYPE date USING date::date;
"

#5. Add missing indexes and foreign keys
echo "----------------------------------------------"
echo "#### Add indexes and foreign keys"
$SQLCMD "
ALTER TABLE law_project
  ADD CONSTRAINT law_project_commission_fk1 FOREIGN KEY (\"last_commission_id\") 
  REFERENCES commission (\"commission_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  

ALTER TABLE law_project
  ADD CONSTRAINT law_project_parliamentary_group_fk1 FOREIGN KEY
  (\"parliamentary_group_id\") 
  REFERENCES parliamentary_group (\"parliamentary_group_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  

ALTER TABLE tracking
  ADD CONSTRAINT tracking_commission_fk1 FOREIGN KEY
  (\"commission_id\") 
  REFERENCES commission (\"commission_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  

ALTER TABLE signatory
  ADD CONSTRAINT signatory_congressperson_fk1 FOREIGN KEY
  (\"congressperson_id\") 
  REFERENCES congressperson (\"cv_id\") 
  ON DELETE NO ACTION ON UPDATE NO ACTION;  

CREATE INDEX law_project_idx ON law_project(id, period, number,legislature,
  last_commission_id,parliamentary_group_id);

CREATE INDEX signatory_idx ON signatory(law_project_id, congressperson_id, 
  signatory_type);
"
