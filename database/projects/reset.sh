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
    docker run --rm --name pgloader --net $DOCKER_NETWORK --env PGPASSWORD=$PGPASSWORD -v "$PWD":/home -w /home dimitri/pgloader:latest pgloader $1
  else 
    docker run --rm --name pgloader --env PGPASSWORD=$PGPASSWORD -v "$PWD":/home -w /home dimitri/pgloader:latest pgloader $1
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

  SET work_mem to '16MB', maintenance_work_mem to '512 MB'

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
ALTER TABLE signatory ADD COLUMN IF NOT EXISTS congressperson_id text;
UPDATE signatory SET congressperson_id = congressperson.cv_id
FROM congressperson 
WHERE signatory.congressperson_slug = congressperson.congressperson_slug;
"

echo "----------------------------------------------"
echo "#### Add id to tracking table "
$SQLCMD "
ALTER TABLE tracking ADD COLUMN IF NOT EXISTS commission_id text;
UPDATE tracking SET commission_id = commission.commission_id
FROM commission 
WHERE tracking.commission_slug = commission.commission_slug;
"

echo "----------------------------------------------"
echo "#### Add id to law_project table "
$SQLCMD "
ALTER TABLE law_project ADD COLUMN IF NOT EXISTS last_commission_id text;
UPDATE law_project SET last_commission_id = commission.commission_id
FROM commission 
WHERE law_project.last_commission_slug = commission.commission_slug;
"

$SQLCMD "
ALTER TABLE law_project ADD COLUMN IF NOT EXISTS parliamentary_group_id text;
UPDATE law_project SET parliamentary_group_id =
parliamentary_group.parliamentary_group_id
FROM parliamentary_group 
WHERE law_project.parliamentary_group_slug =
parliamentary_group.parliamentary_group_slug;
"
