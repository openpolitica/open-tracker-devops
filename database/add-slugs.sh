#!/bin/bash
# This script add slugs to names in database
####### REQUIRES TO SET ENVIRONMENT VALUES #########
# export PGDATABASE=database_name
# export PGHOST=localhost_or_remote_host
# export PGPORT=database_port
# export PGUSER=database_user
# export PGPASSWORD=database_password
# References:
# https://www.kdobson.net/2019/ultimate-postgresql-slug-function/
# https://medium.com/broadlume-product/using-postgresql-to-generate-slugs-5ec9dd759e88

SQLCMD="psql -U ${PGUSER} -w  -h ${PGHOST} -c "

$SQLCMD "
CREATE EXTENSION IF NOT EXISTS \"unaccent\";

CREATE OR REPLACE FUNCTION slugify(\"value\" TEXT)
RETURNS TEXT AS \$\$
  -- removes accents (diacritic signs) from a given string --
  WITH \"unaccented\" AS (
    SELECT unaccent(\"value\") AS \"value\"
  ),
  -- lowercases the string
  \"lowercase\" AS (
    SELECT lower(\"value\") AS \"value\"
    FROM \"unaccented\"
  ),
  -- remove single and double quotes
  \"removed_quotes\" AS (
    SELECT regexp_replace(\"value\", '[''\"]+', '', 'gi') AS \"value\"
    FROM \"lowercase\"
  ),
  -- replaces anything that's not a letter, number, hyphen('-'), or underscore('_') with a hyphen('-')
  \"hyphenated\" AS (
    SELECT regexp_replace(\"value\", '[^a-z0-9\\-_]+', '-', 'gi') AS \"value\"
    FROM \"removed_quotes\"
  ),
  -- trims hyphens('-') if they exist on the head or tail of the string
  \"trimmed\" AS (
    SELECT regexp_replace(regexp_replace(\"value\", '\-+$', ''), '^\-', '') AS \"value\"
    FROM \"hyphenated\"
  )
  SELECT \"value\" FROM \"trimmed\";
\$\$ LANGUAGE SQL STRICT IMMUTABLE;
"

echo "----------------------------------------------"
echo "#### Add slug to congressperson table "
$SQLCMD "
ALTER TABLE congressperson ADD COLUMN IF NOT EXISTS congressperson_slug text;
UPDATE congressperson SET congressperson_slug =
slugify(concat(congressperson.id_name, ' ',
congressperson.id_first_surname, ' ', id_second_surname));
CREATE INDEX IF NOT EXISTS congressperson_slug_idx on congressperson(cv_id,
congressperson_slug);
"
