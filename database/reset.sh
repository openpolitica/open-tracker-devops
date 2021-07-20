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

# Import Congreso
# Requires pgloader
echo "----------------------------------------------"
echo "#### Import candidates: Congresistas"
command_file="$(cat << EOF
load database
     from https://github.com/openpolitica/jne-elecciones/raw/main/data/plataformaelectoral/2021-candidatos-congresales.db
     into pgsql://${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE}

 WITH include drop, create tables, create indexes, reset sequences

  SET work_mem to '16MB', maintenance_work_mem to '512 MB'

 CAST type string to text;
EOF
)"
echo "$command_file" | pgloader /dev/stdin


# Store in temporary table VicePresidentes that we know are Congresistas
echo "----------------------------------------------"
echo "#### Getting the 'Vicepresidentes' that are 'Congresistas' and storing their ID in temporary table"
$SQLCMD "
DROP TABLE IF EXISTS \"temp_vp_congreso\";
CREATE TABLE temp_vp_congreso AS
SELECT hoja_vida_id
FROM candidato
WHERE cargo_nombre LIKE '%VICEPRESIDENTE%';
"

# Import Parlamento Andino
# Requires pgloader
echo "----------------------------------------------"
echo "#### Import candidates: Parlamento Andino"
command_file="$(cat << EOF
load database
     from https://github.com/openpolitica/jne-elecciones/raw/main/data/plataformaelectoral/2021-candidatos-parlamento-andino.db
     into pgsql://${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE}

 WITH include no drop, create no tables, create indexes, reset sequences

  SET work_mem to '16MB', maintenance_work_mem to '512 MB'

 CAST type string to text;
EOF
)"
echo "$command_file" | pgloader /dev/stdin

# Store in temporary table VicePresidentes that we know are Parlamento Andino
echo "----------------------------------------------"
echo "#### Getting the 'Vicepresidentes' that are 'Parlamento Andino' and storing their ID in temporary table"
$SQLCMD "
DROP TABLE IF EXISTS \"temp_vp_pa\";
CREATE TABLE temp_vp_pa AS
SELECT hoja_vida_id
FROM candidato
WHERE cargo_nombre LIKE '%VICEPRESIDENTE%' AND hoja_vida_id NOT IN
(SELECT hoja_vida_id FROM \"temp_vp_congreso\");
"

# Modify datatypes in candidates
echo "----------------------------------------------"
echo "#### Modifying the datatypes in table"
$SQLCMD '''
ALTER TABLE "candidato" ALTER COLUMN hoja_vida_id TYPE int;
ALTER TABLE "candidato" ALTER COLUMN id_dni TYPE int USING id_dni::integer;
ALTER TABLE "candidato" ALTER COLUMN id_ce TYPE varchar(1);
ALTER TABLE "candidato" ALTER COLUMN id_sexo TYPE varchar(1);
ALTER TABLE "candidato" ALTER COLUMN nacimiento_fecha TYPE varchar(10);
ALTER TABLE "candidato" ALTER COLUMN nacimiento_ubigeo TYPE int USING nacimiento_ubigeo::integer;
ALTER TABLE "candidato" ALTER COLUMN domicilio_ubigeo TYPE int USING domicilio_ubigeo::integer;
ALTER TABLE "candidato" ALTER COLUMN postula_ubigeo TYPE int USING postula_ubigeo::integer;
ALTER TABLE "candidato" ALTER COLUMN postula_distrito TYPE varchar(48);
ALTER TABLE "candidato" ALTER COLUMN postula_anio TYPE smallint;
ALTER TABLE "candidato" ALTER COLUMN proceso_electoral_id TYPE smallint;
ALTER TABLE "candidato" ALTER COLUMN candidato_id TYPE int;
ALTER TABLE "candidato" ALTER COLUMN posicion TYPE smallint;
ALTER TABLE "candidato" ALTER COLUMN cargo_id TYPE smallint;
ALTER TABLE "candidato" ALTER COLUMN cargo_nombre TYPE varchar(64);
ALTER TABLE "candidato" ALTER COLUMN org_politica_id TYPE smallint;
ALTER TABLE "candidato" ALTER COLUMN org_politica_nombre TYPE varchar(46);
ALTER TABLE "candidato" ALTER COLUMN estado_id TYPE smallint;
ALTER TABLE "candidato" ALTER COLUMN expediente_id TYPE int;
ALTER TABLE "candidato" ALTER COLUMN expediente_estado TYPE varchar(12);
ALTER TABLE "candidato" ALTER COLUMN tipo_eleccion_id TYPE int;
ALTER TABLE "candidato" ALTER COLUMN lista_solicitud_id TYPE int;
ALTER TABLE "candidato" ALTER COLUMN jurado_electoral_id TYPE smallint;
ALTER TABLE "candidato" ALTER COLUMN candidatos_mujeres TYPE smallint;
ALTER TABLE "candidato" ALTER COLUMN candidatos_hombres TYPE smallint;
ALTER TABLE "candidato" ALTER COLUMN ubicacion_jurado_id TYPE smallint;
ALTER TABLE "bien_mueble" ALTER COLUMN hoja_vida_id TYPE int;
ALTER TABLE "bien_inmueble" ALTER COLUMN hoja_vida_id TYPE int;
ALTER TABLE "educacion" ALTER hoja_vida_id TYPE int;
ALTER TABLE "experiencia" ALTER hoja_vida_id TYPE int;
ALTER TABLE "ingreso" ALTER COLUMN hoja_vida_id TYPE int;
ALTER TABLE "sentencia_civil" ALTER COLUMN hoja_vida_id TYPE int;
ALTER TABLE "sentencia_penal" ALTER COLUMN hoja_vida_id TYPE int;
'''

# Change applicable Vicepresidentes to VP+Congresistas
echo "----------------------------------------------"
echo "#### Creating new 'cargo_nombre' type that mixes 'Vicepresidente + Congresista' where applicable"
$SQLCMD "
ALTER TABLE \"temp_vp_congreso\" ALTER COLUMN hoja_vida_id TYPE int;
UPDATE candidato
SET cargo_nombre='PRIMER VICEPRESIDENTE Y CONGRESISTA DE LA REPÚBLICA'
WHERE cargo_nombre LIKE 'PRIMER VICEPRESIDENTE%'
AND hoja_vida_id in (SELECT * FROM temp_vp_congreso);
UPDATE candidato
SET cargo_nombre='SEGUNDO VICEPRESIDENTE Y CONGRESISTA DE LA REPÚBLICA'
WHERE cargo_nombre LIKE 'SEGUNDO VICEPRESIDENTE%'
AND hoja_vida_id in (SELECT * FROM temp_vp_congreso);
DROP TABLE IF EXISTS \"temp_vp_congreso\";
"

# Change applicable Vicepresidentes to VP+PA
echo "----------------------------------------------"
echo "#### Creating new 'cargo_nombre' type that mixes 'Vicepresidente + Parlamento Andino' where applicable"
$SQLCMD "
ALTER TABLE \"temp_vp_pa\" ALTER COLUMN hoja_vida_id TYPE int;
UPDATE candidato
SET cargo_nombre='PRIMER VICEPRESIDENTE Y REPRESENTANTE ANTE EL PARLAMENTO ANDINO'
WHERE cargo_nombre LIKE 'PRIMER VICEPRESIDENTE%'
AND hoja_vida_id in (SELECT * FROM temp_vp_pa);
UPDATE candidato
SET cargo_nombre='SEGUNDO VICEPRESIDENTE Y REPRESENTANTE ANTE EL PARLAMENTO ANDINO'
WHERE cargo_nombre LIKE 'SEGUNDO VICEPRESIDENTE%'
AND hoja_vida_id in (SELECT * FROM temp_vp_pa);
DROP TABLE IF EXISTS \"temp_vp_pa\";
"

# Add temp elected table
echo "----------------------------------------------"
echo "#### Add temp elected candidate"
$SQLCMD '''
DROP TABLE IF EXISTS "temp_electos";
CREATE TABLE "temp_electos" (
  "hoja_vida_id" int DEFAULT NULL,
  "nombre" text DEFAULT NULL,
  "partido" text DEFAULT NULL
);
'''
$SQLCMD "\copy \"temp_electos\" (
  \"hoja_vida_id\",
  \"nombre\",
  \"partido\")
FROM './congresistas_pa_electos.csv' DELIMITER ',' QUOTE '\"' CSV HEADER;
"

#Deleting all not elected
echo "----------------------------------------------"
echo "#### Removing no elected"
$SQLCMD '''
DELETE FROM "candidato"
WHERE "candidato".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM temp_electos);
DROP TABLE IF EXISTS temp_electos;
'''

#Create column with cargo_electo
echo "----------------------------------------------"
echo "#### Crear columna con cargos elegidos"
$SQLCMD "
ALTER TABLE candidato ADD COLUMN cargo_electo VARCHAR(64);
UPDATE candidato
SET cargo_electo='CONGRESISTA DE LA REPÚBLICA'
WHERE cargo_nombre LIKE '%CONGRESISTA%';
UPDATE candidato
SET cargo_electo='REPRESENTANTE ANTE EL PARLAMENTO ANDINO'
WHERE cargo_nombre LIKE '%PARLAMENTO%';
"

# Expand cargo_nombre field and remove new duplicates
echo "----------------------------------------------"
echo "#### Removing duplicate entries individually"
$SQLCMD "
DELETE FROM \"candidato\"
WHERE expediente_estado LIKE '%IMPROCEDENTE%'
OR expediente_estado LIKE '%EXCLUSION%'
OR expediente_estado LIKE '%RENUNCI%'
OR expediente_estado LIKE '%RETIRO%';
"

$SQLCMD '''
CREATE TABLE temp_educacion AS SELECT DISTINCT * FROM educacion;
ALTER TABLE educacion RENAME TO junk;
ALTER TABLE temp_educacion RENAME TO educacion;
DROP TABLE IF EXISTS junk;
DROP TABLE IF EXISTS temp_educacion;

CREATE TABLE temp_ingreso AS SELECT DISTINCT * FROM ingreso;
ALTER TABLE ingreso RENAME TO junk;
ALTER TABLE temp_ingreso RENAME TO ingreso;
DROP TABLE IF EXISTS junk;
DROP TABLE IF EXISTS temp_ingreso;

CREATE TABLE temp_bien_mueble AS SELECT DISTINCT * FROM bien_mueble;
ALTER TABLE bien_mueble RENAME TO junk;
ALTER TABLE temp_bien_mueble RENAME TO bien_mueble;
DROP TABLE IF EXISTS junk;
DROP TABLE IF EXISTS temp_bien_mueble;

CREATE TABLE temp_bien_inmueble AS SELECT DISTINCT * FROM bien_inmueble;
ALTER TABLE bien_inmueble RENAME TO junk;
ALTER TABLE temp_bien_inmueble RENAME TO bien_inmueble;
DROP TABLE IF EXISTS junk;
DROP TABLE IF EXISTS temp_bien_inmueble;

CREATE TABLE temp_experiencia AS SELECT DISTINCT * FROM experiencia;
ALTER TABLE experiencia RENAME TO junk;
ALTER TABLE temp_experiencia RENAME TO experiencia;
DROP TABLE IF EXISTS junk;
DROP TABLE IF EXISTS temp_experiencia;

CREATE TABLE temp_sentencia_civil AS SELECT DISTINCT * FROM sentencia_civil;
ALTER TABLE sentencia_civil RENAME TO junk;
ALTER TABLE temp_sentencia_civil RENAME TO sentencia_civil;
DROP TABLE IF EXISTS junk;
DROP TABLE IF EXISTS temp_sentencia_civil;

CREATE TABLE temp_sentencia_penal AS SELECT DISTINCT * FROM sentencia_penal;
ALTER TABLE sentencia_penal RENAME TO junk;
ALTER TABLE temp_sentencia_penal RENAME TO sentencia_penal;
DROP TABLE IF EXISTS junk;
DROP TABLE IF EXISTS temp_sentencia_penal;
'''

# Create extra_data table
echo "----------------------------------------------"
echo "#### Creating new table for storing extra data that comes from other sources"
$SQLCMD '''
DROP TABLE IF EXISTS "extra_data";
CREATE TABLE IF NOT EXISTS "extra_data" (
  "hoja_vida_id" int DEFAULT NULL,
  "educacion_primaria" smallint DEFAULT 0,
  "educacion_secundaria" smallint DEFAULT 0,
  "educacion_superior_tecnica" smallint DEFAULT 0,
  "educacion_superior_nouniversitaria" smallint DEFAULT 0,
  "educacion_superior_universitaria" smallint DEFAULT 0,
  "educacion_postgrado" smallint DEFAULT 0,
  "educacion_mayor_nivel" varchar(32) DEFAULT NULL,
  "vacancia" smallint DEFAULT NULL,
  "sentencias_ec_civil_cnt" smallint DEFAULT 0,
  "sentencias_ec_penal_cnt" smallint DEFAULT 0,
  "experiencia_publica" smallint DEFAULT 0,
  "experiencia_privada" smallint DEFAULT 0,
  "bienes_muebles_valor" numeric(12,2) DEFAULT 0,
  "bienes_inmuebles_valor" numeric(12,2) DEFAULT 0
);
'''

# Populate extra_data table
echo "----------------------------------------------"
echo "#### Populating extra_data table"
## hoja_vida_id
$SQLCMD '''
INSERT INTO extra_data (hoja_vida_id)
SELECT hoja_vida_id FROM candidato
'''
## vacancia
$SQLCMD "
UPDATE extra_data
SET vacancia=1
WHERE hoja_vida_id IN (SELECT hoja_vida_id FROM candidato c WHERE
c.org_politica_nombre LIKE 'ACCION POPULAR'
OR c.org_politica_nombre LIKE 'ALIANZA PARA EL PROGRESO'
OR c.org_politica_nombre LIKE 'EL FRENTE AMPLIO POR JUSTICIA, VIDA Y LIBERTAD'
OR c.org_politica_nombre LIKE 'FUERZA POPULAR'
OR c.org_politica_nombre LIKE 'PARTIDO DEMOCRATICO SOMOS PERU'
OR c.org_politica_nombre LIKE 'PODEMOS PERU'
OR c.org_politica_nombre LIKE 'UNION POR EL PERU'
OR c.org_politica_nombre LIKE 'FRENTE POPULAR AGRICOLA FIA DEL PERU - FREPAP');
UPDATE extra_data
SET vacancia=0
WHERE hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato c WHERE
c.org_politica_nombre LIKE 'ACCION POPULAR'
OR c.org_politica_nombre LIKE 'ALIANZA PARA EL PROGRESO'
OR c.org_politica_nombre LIKE 'EL FRENTE AMPLIO POR JUSTICIA, VIDA Y LIBERTAD'
OR c.org_politica_nombre LIKE 'FUERZA POPULAR'
OR c.org_politica_nombre LIKE 'PARTIDO DEMOCRATICO SOMOS PERU'
OR c.org_politica_nombre LIKE 'PODEMOS PERU'
OR c.org_politica_nombre LIKE 'UNION POR EL PERU'
OR c.org_politica_nombre LIKE 'FRENTE POPULAR AGRICOLA FIA DEL PERU - FREPAP');
"
## Experiencia pública y privada
$SQLCMD '''
DROP TABLE IF EXISTS "temp_experiencia";
CREATE TABLE "temp_experiencia" (
  "hoja_vida_id" int DEFAULT NULL,
  "experiencia_publica" smallint DEFAULT NULL,
  "experiencia_privada" smallint DEFAULT NULL
);
'''
$SQLCMD "\copy \"temp_experiencia\" (
\"hoja_vida_id\", 
\"experiencia_privada\",
\"experiencia_publica\")
FROM './experiencia.csv' DELIMITER ',' QUOTE '\"' CSV HEADER;
UPDATE extra_data
SET experiencia_publica=1
WHERE hoja_vida_id IN (SELECT hoja_vida_id FROM temp_experiencia t WHERE t.experiencia_publica=1);
UPDATE extra_data
SET experiencia_publica=0
WHERE hoja_vida_id NOT IN (SELECT hoja_vida_id FROM temp_experiencia t WHERE t.experiencia_publica=1);
UPDATE extra_data
SET experiencia_privada=1
WHERE hoja_vida_id IN (SELECT hoja_vida_id FROM temp_experiencia t WHERE t.experiencia_privada=1);
UPDATE extra_data
SET experiencia_privada=0
WHERE hoja_vida_id NOT IN (SELECT hoja_vida_id FROM temp_experiencia t WHERE t.experiencia_privada=1);
DROP TABLE IF EXISTS \"temp_experiencia\";
"

## Alias de partido
$SQLCMD '''
DROP TABLE IF EXISTS "partidos_alias";
CREATE TABLE "partidos_alias" (
  "id" smallint DEFAULT NULL,
  "orden_cedula" smallint DEFAULT NULL,
  "nombre" varchar(56) DEFAULT NULL,
  "alias" varchar(56) DEFAULT NULL,
  "plan_de_gobierno_url" varchar(96) DEFAULT NULL,
  PRIMARY KEY (id)
);
'''
$SQLCMD "\copy \"partidos_alias\" (
  \"id\",
  \"orden_cedula\",
  \"nombre\",
  \"alias\",
  \"plan_de_gobierno_url\")
FROM './partidos_alias.csv' DELIMITER ',' QUOTE '\"' CSV HEADER;
"

## Educación mayor nivel
$SQLCMD "
UPDATE extra_data
SET educacion_mayor_nivel='Primaria', educacion_primaria=1
WHERE hoja_vida_id IN (SELECT hoja_vida_id FROM educacion e 
WHERE e.tipo = 'BASICA_PRIMARIA' AND e.concluyo = true);
UPDATE extra_data
SET educacion_mayor_nivel='Secundaria', educacion_secundaria=1
WHERE hoja_vida_id IN (SELECT hoja_vida_id FROM educacion e 
WHERE e.tipo = 'BASICA_SECUNDARIA' AND e.concluyo = true);
UPDATE extra_data
SET educacion_mayor_nivel='Superior - Técnica', educacion_superior_tecnica=1
WHERE hoja_vida_id IN (SELECT hoja_vida_id FROM educacion e
WHERE e.tipo = 'TECNICA' AND e.concluyo = true);
UPDATE extra_data
SET educacion_mayor_nivel='Superior - No Universitaria', educacion_superior_nouniversitaria=1
WHERE hoja_vida_id IN (SELECT hoja_vida_id FROM educacion e 
WHERE e.tipo = 'NO_UNIVERSITARIA' AND e.concluyo = true);
UPDATE extra_data
SET educacion_mayor_nivel='Superior - Universitaria', educacion_superior_universitaria=1
WHERE hoja_vida_id IN (SELECT hoja_vida_id FROM educacion e 
WHERE e.tipo = 'UNIVERSITARIA' AND e.concluyo = true);
UPDATE extra_data
SET educacion_mayor_nivel='Postgrado', educacion_postgrado=1
WHERE hoja_vida_id IN (SELECT hoja_vida_id FROM educacion e 
WHERE e.tipo = 'POSTGRADO' AND e.concluyo = true);
UPDATE extra_data
SET educacion_mayor_nivel='No Registra'
WHERE educacion_mayor_nivel IS NULL;
"

# New sentencias_ec table and populate extra_data
echo "----------------------------------------------"
echo "#### Creating new table 'sentencias_ec' for data coming from EC source"
$SQLCMD '''
DROP TABLE IF EXISTS "sentencias_ec";
CREATE TABLE "sentencias_ec" (
  "hoja_vida_id" int DEFAULT NULL,
  "delito" varchar(64) DEFAULT NULL, 
  "procesos" smallint DEFAULT NULL,
  "tipo" varchar(32) DEFAULT NULL,
  "fallo" varchar(96) DEFAULT NULL
);
'''
$SQLCMD "\copy \"sentencias_ec\" (
  \"hoja_vida_id\",
  \"delito\",
  \"procesos\",
  \"tipo\",
  \"fallo\")
FROM './sentencias_input_data.csv' DELIMITER ',' QUOTE '\"' CSV HEADER;
UPDATE extra_data e
SET sentencias_ec_penal_cnt =
(SELECT COUNT(*) as count
FROM sentencias_ec t
WHERE e.hoja_vida_id = t.hoja_vida_id AND tipo='Penal');
UPDATE extra_data e
SET sentencias_ec_civil_cnt =
(SELECT COUNT(*) as count
FROM sentencias_ec t
WHERE e.hoja_vida_id = t.hoja_vida_id AND tipo='Civil');

DELETE FROM \"sentencias_ec\"
WHERE \"sentencias_ec\".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
"

# Update 'bienes' total values in extra_data
echo "----------------------------------------------"
echo "#### Populating 'bienes' total value in extra_data"
$SQLCMD '''
UPDATE extra_data e 
SET bienes_inmuebles_valor = b.valor FROM (SELECT hoja_vida_id, CAST(SUM(auto_valuo) as numeric(12,2)) as valor
FROM bien_inmueble
GROUP BY bien_inmueble.hoja_vida_id) b
WHERE e.hoja_vida_id = b.hoja_vida_id;
UPDATE extra_data e 
SET bienes_muebles_valor = b.valor FROM (SELECT hoja_vida_id, CAST(SUM(valor) as numeric(12,2)) as valor
FROM bien_mueble
GROUP BY bien_mueble.hoja_vida_id) b
WHERE e.hoja_vida_id = b.hoja_vida_id;
'''

# New data_ec table and populate
echo "----------------------------------------------"
echo "#### Creating new table 'data_ec' for data coming from EC-TD source"
$SQLCMD '''
DROP TABLE IF EXISTS "data_ec";
CREATE TABLE "data_ec" (
  "hoja_vida_id" int DEFAULT NULL,
  "designado" varchar(16) DEFAULT NULL,
  "inmuebles_total" varchar(16) DEFAULT 0,
  "muebles_total" varchar(16) DEFAULT 0,
  "deuda_sunat" varchar(16) DEFAULT 0,
  "aportes_electorales" varchar(16) DEFAULT 0,
  "procesos_electorales_participados" smallint DEFAULT 0,
  "procesos_electorales_ganados" smallint DEFAULT 0,
  "papeletas_sat" smallint DEFAULT 0,
  "papeletas_monto" varchar(16) DEFAULT 0,
  "licencia_conducir" varchar(64) DEFAULT NULL,
  "sancion_servir_registro" varchar(96) DEFAULT NULL,
  "sancion_servir_institucion" varchar(256) DEFAULT NULL
);
'''
$SQLCMD "\copy \"data_ec\" (
  \"hoja_vida_id\",
  \"designado\",
  \"inmuebles_total\",
  \"muebles_total\",
  \"deuda_sunat\",
  \"aportes_electorales\",
  \"procesos_electorales_participados\",
  \"procesos_electorales_ganados\",
  \"papeletas_sat\",
  \"papeletas_monto\",
  \"licencia_conducir\",
  \"sancion_servir_registro\",
  \"sancion_servir_institucion\")
FROM './data_ec.csv' DELIMITER ',' QUOTE '\"' CSV HEADER;

DELETE FROM \"data_ec\"
WHERE \"data_ec\".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);

UPDATE \"data_ec\"
SET inmuebles_total = 0
WHERE inmuebles_total LIKE 'No%';

UPDATE \"data_ec\"
SET inmuebles_total = CAST(REPLACE(inmuebles_total, ',', '') as decimal(12,2));

ALTER TABLE data_ec 
ALTER COLUMN inmuebles_total TYPE numeric(12,2) USING inmuebles_total::numeric(12,2);

UPDATE \"data_ec\"
SET muebles_total = 0
WHERE muebles_total LIKE 'No%';

UPDATE \"data_ec\"
SET muebles_total = CAST(REPLACE(muebles_total, ',', '') as decimal(12,2));

ALTER TABLE data_ec 
ALTER COLUMN muebles_total TYPE numeric(12,2) USING muebles_total::numeric(12,2);

UPDATE \"data_ec\"
SET aportes_electorales = 0
WHERE aportes_electorales LIKE 'No%';

UPDATE \"data_ec\"
SET aportes_electorales = CAST(REPLACE(aportes_electorales, ',', '') as decimal(12,2));

ALTER TABLE data_ec 
ALTER COLUMN aportes_electorales TYPE DECIMAL(12,2) USING aportes_electorales::numeric(12,2);

UPDATE \"data_ec\"
SET deuda_sunat = 0
WHERE deuda_sunat LIKE 'No%';

UPDATE \"data_ec\"
SET deuda_sunat = CAST(REPLACE(deuda_sunat, ',', '') as decimal(12,2));

ALTER TABLE \"data_ec\"
ALTER COLUMN deuda_sunat TYPE numeric(12,2) USING deuda_sunat::numeric(12,2);

UPDATE \"data_ec\"
SET sancion_servir_registro = 'No registra'
WHERE sancion_servir_registro IS NULL OR sancion_servir_registro = '';

UPDATE \"data_ec\"
SET sancion_servir_institucion = 'No registra'
WHERE sancion_servir_institucion IS NULL OR CHAR_LENGTH(sancion_servir_institucion) = 1;
"

# New locations table and populate
echo "----------------------------------------------"
echo "#### Creating new table 'locations' for seats & geographical coordinates"
$SQLCMD '''
DROP TABLE IF EXISTS "locations";
CREATE TABLE "locations" (
  "id" smallint DEFAULT NULL,
  "location" varchar(48) DEFAULT NULL,
  "lat" varchar(32) DEFAULT NULL,
  "lng" varchar(32) DEFAULT NULL,
  "seats" smallint DEFAULT NULL,
  "apicounts" int DEFAULT 0,
  "si_vacancia" int DEFAULT 0,
  "no_vacancia" int DEFAULT 0
);
'''
$SQLCMD "\copy \"locations\" (
  \"id\",
  \"location\",
  \"lat\",
  \"lng\",
  \"seats\")
FROM './locations.csv' DELIMITER ',' QUOTE '\"' CSV HEADER;
"

# New dirty lists table and populate
echo "----------------------------------------------"
echo "#### Creating new dirty_lists table for parties with sanctions"
$SQLCMD "
CREATE table dirty_lists
AS
SELECT
  postula_distrito,
  candidato.org_politica_nombre,
  sum(extra_data.sentencias_ec_penal_cnt) as sentencias_penales,
  sum(extra_data.sentencias_ec_civil_cnt) as sentencias_civiles,
  sum(data_ec.deuda_sunat) as deuda_sunat,
  sum(data_ec.papeletas_sat) as papeletas_sat,
  sum(case
    when cast(data_ec.sancion_servir_registro as varchar) not like 'No registra' then 1
    else 0
  end) as sancion_servir,
  string_agg(cast(data_ec.licencia_conducir as varchar), ',') as licencia_conducir
FROM candidato
  JOIN extra_data
    ON candidato.hoja_vida_id = extra_data.hoja_vida_id
  JOIN data_ec
    ON candidato.hoja_vida_id = data_ec.hoja_vida_id
where (
  cast(candidato.cargo_nombre as varchar) like '%CONGRESISTA%'
  and (
    (
      candidato.postula_distrito = 'LIMA'
      and candidato.posicion > 0
      and candidato.posicion < 6
    )
    or (
      candidato.postula_distrito <> 'LIMA'
      and candidato.posicion > 0
      and candidato.posicion < 3
    )
  )
  and (
    extra_data.sentencias_ec_penal_cnt > 0
    or extra_data.sentencias_ec_civil_cnt > 0
    or data_ec.deuda_sunat > 0
    or data_ec.papeletas_sat > 0
    or cast(data_ec.sancion_servir_registro as varchar) not like 'No registra'
    or cast(data_ec.licencia_conducir as varchar) like '%retenida%'
    or cast(data_ec.licencia_conducir as varchar) like '%inhabilita%'
    or cast(data_ec.licencia_conducir as varchar) like '%cancelada%'
    or cast(data_ec.licencia_conducir as varchar) like '%suspendida%'
  )
)
group by postula_distrito, org_politica_nombre
"

# Delete useless data
echo "----------------------------------------------"
echo "#### Delete data from tables that does not belong to any candidate"
$SQLCMD '''
DELETE FROM "ingreso"
WHERE "ingreso".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
DELETE FROM "experiencia"
WHERE "experiencia".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
DELETE FROM "educacion"
WHERE "educacion".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
DELETE FROM "sentencia_civil"
WHERE "sentencia_civil".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
DELETE FROM "sentencia_penal"
WHERE "sentencia_penal".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
DELETE FROM "bien_mueble"
WHERE "bien_mueble".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
DELETE FROM "bien_inmueble"
WHERE "bien_inmueble".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
DELETE FROM "data_ec"
WHERE "data_ec".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
DELETE FROM "extra_data"
WHERE "extra_data".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
DELETE FROM "sentencias_ec"
WHERE "sentencias_ec".hoja_vida_id NOT IN (SELECT hoja_vida_id FROM candidato);
'''

# Update data for special cases
echo "----------------------------------------------"
echo "#### Updating candidates special information"
$SQLCMD "
UPDATE candidato
SET id_nombres = 'GAHELA TSENEG', id_sexo = 'F'
WHERE hoja_vida_id = 136670
"

# Add social network table
echo "----------------------------------------------"
echo "#### Add information for social_network"
$SQLCMD '''
DROP TABLE IF EXISTS "redes_sociales";
CREATE TABLE "redes_sociales" (
  "hoja_vida_id" int DEFAULT NULL,
  "facebook" text DEFAULT NULL,
  "twitter" text DEFAULT NULL
);
'''
$SQLCMD "\copy \"redes_sociales\" (
  \"hoja_vida_id\",
  \"facebook\",
  \"twitter\")
FROM './redes_sociales.csv' DELIMITER ',' QUOTE '\"' CSV HEADER;
"

# Militancy: Congreso 
echo "----------------------------------------------"
echo "#### Militancy: Importing candidates: Congresistas"
command_file="$(cat << EOF
load database
     from https://github.com/openpolitica/jne-elecciones/raw/main/data/infogob/2021-militancia-candidatos-congresales.db
     into pgsql://${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE}

 WITH include drop, create tables, create indexes, reset sequences

  SET work_mem to '16MB', maintenance_work_mem to '512 MB'

 CAST type string to text;
EOF
)"
echo "$command_file" | pgloader /dev/stdin

# Militancy: Parlamento Andino
echo "----------------------------------------------"
echo "#### Militancy: Importing candidates: Parlamento Andino"
command_file="$(cat << EOF
load database
     from https://github.com/openpolitica/jne-elecciones/raw/main/data/infogob/2021-militancia-candidatos-parlamento-andino.db
     into pgsql://${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE}

 WITH include no drop, create no tables, create indexes, reset sequences

  SET work_mem to '16MB', maintenance_work_mem to '512 MB'

 CAST type string to text;
EOF
)"
echo "$command_file" | pgloader /dev/stdin

# Modify datatypes in afiliacion
echo "----------------------------------------------"
echo "#### Modifying the datatypes in table"
$SQLCMD '''
ALTER TABLE "afiliacion" ALTER COLUMN dni TYPE int USING dni::integer;
ALTER TABLE "afiliacion" ALTER COLUMN org_politica TYPE varchar(75);
ALTER TABLE "afiliacion" ALTER COLUMN afiliacion_inicio TYPE varchar(10);
ALTER TABLE "afiliacion" ALTER COLUMN afiliacion_cancelacion TYPE varchar(10);
ALTER TABLE "proceso_electoral" ALTER COLUMN dni TYPE int USING dni::integer;
'''

# Militancy: Remove duplicates and useless
echo "----------------------------------------------"
echo "#### Militancy: removing duplicate entries individually"
$SQLCMD '''
CREATE TABLE temp_afiliacion AS SELECT DISTINCT * FROM afiliacion;
ALTER TABLE afiliacion RENAME TO junk;
ALTER TABLE temp_afiliacion RENAME TO afiliacion;
DROP TABLE IF EXISTS "junk";
DROP TABLE IF EXISTS "temp_afiliacion";
DELETE FROM "afiliacion"
WHERE "afiliacion".dni NOT IN (SELECT id_dni FROM candidato);
'''


# Create definite indexes and relations!
echo "----------------------------------------------"
echo "#### Creating indexes and relations betweeen tables"
$SQLCMD '''
CREATE INDEX on candidato(hoja_vida_id, postula_distrito, cargo_nombre, org_politica_nombre, org_politica_id, id_sexo, expediente_estado, id_dni);
ALTER TABLE candidato ADD PRIMARY KEY(id_dni);
ALTER TABLE candidato ADD CONSTRAINT unique_candidate UNIQUE ("hoja_vida_id");
ALTER TABLE "ingreso"
  ADD CONSTRAINT "ingreso_fk1" FOREIGN KEY ("hoja_vida_id") 
  REFERENCES "candidato" ("hoja_vida_id") 
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ingreso"
  ALTER COLUMN total TYPE numeric(15,2);
ALTER TABLE "ingreso"
  ALTER COLUMN total_publico TYPE numeric(15,2);
ALTER TABLE "ingreso"
  ALTER COLUMN total_privado TYPE numeric(15,2);
ALTER TABLE "experiencia"
  ADD CONSTRAINT "experiencia_fk1" FOREIGN KEY ("hoja_vida_id") 
  REFERENCES "candidato" ("hoja_vida_id") 
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "educacion"
  ADD CONSTRAINT "educacion_fk1" FOREIGN KEY ("hoja_vida_id") 
  REFERENCES "candidato" ("hoja_vida_id") 
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "sentencia_civil"
  ADD CONSTRAINT "sentencia_civil_fk1" FOREIGN KEY ("hoja_vida_id") 
  REFERENCES "candidato" ("hoja_vida_id") 
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "sentencia_penal"
  ADD CONSTRAINT "sentencia_penal_fk1" FOREIGN KEY ("hoja_vida_id") 
  REFERENCES "candidato" ("hoja_vida_id") 
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "bien_inmueble"
  ADD CONSTRAINT "bien_inmueble_fk1" FOREIGN KEY ("hoja_vida_id") 
  REFERENCES "candidato" ("hoja_vida_id") 
  ON DELETE CASCADE ON UPDATE CASCADE;  
ALTER TABLE "bien_mueble"
  ADD CONSTRAINT "bien_mueble_fk1" FOREIGN KEY ("hoja_vida_id") 
  REFERENCES "candidato" ("hoja_vida_id") 
  ON DELETE CASCADE ON UPDATE CASCADE;  
ALTER TABLE "data_ec"
  ADD CONSTRAINT "data_ec_fk1" FOREIGN KEY ("hoja_vida_id") 
  REFERENCES "candidato" ("hoja_vida_id") 
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "extra_data"
  ADD CONSTRAINT "extra_data_fk1" FOREIGN KEY ("hoja_vida_id") 
  REFERENCES "candidato" ("hoja_vida_id") 
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "sentencias_ec"
  ADD CONSTRAINT "sentencias_ec_fk1" FOREIGN KEY ("hoja_vida_id") 
  REFERENCES "candidato" ("hoja_vida_id") 
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "afiliacion"
  ADD CONSTRAINT "afiliacion_fk1" FOREIGN KEY ("dni")
  REFERENCES "candidato" ("id_dni")
  ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX ON ingreso(total, hoja_vida_id);
CREATE INDEX ON extra_data(vacancia, experiencia_publica, sentencias_ec_civil_cnt, sentencias_ec_penal_cnt, educacion_mayor_nivel);
CREATE INDEX ON locations(location, seats, lat, lng);
CREATE INDEX ON partidos_alias(alias, id, orden_cedula, plan_de_gobierno_url);
CREATE INDEX ON data_ec(hoja_vida_id, designado, inmuebles_total, muebles_total, deuda_sunat, aportes_electorales, procesos_electorales_participados, procesos_electorales_ganados, papeletas_sat, sancion_servir_registro);
CREATE INDEX ON afiliacion(vigente, dni, org_politica, afiliacion_inicio, afiliacion_cancelacion)
'''

