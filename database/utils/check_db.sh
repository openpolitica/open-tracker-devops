#!/bin/bash

source utils/sql.sh
source utils/parser.sh

function check_null_values() {
  table_name="$1"
  column_name="$2"
  sql_query="SELECT count(*) as count from ${table_name} 
    where ${column_name} is null;"

  columns=(count)
  read_sql_result_one "$sql_query" ${columns[@]}

  for value in ${VALUES[@]}; do
    if [[ $value > 0 ]]; then
      echo "Fail check, ${table_name} has $value null records in ${column_name} column"
      return -1
    fi
  done
}

function check_null_values_reference() {
  table_name="$1"
  column_name="$2"
  column_reference="$3"
  sql_query="SELECT count(*) as count from ${table_name} 
    where ${column_reference} is not null and ${column_name} is null;"

  columns=(count)
  read_sql_result_one "$sql_query" ${columns[@]}

  for value in ${VALUES[@]}; do
    if [[ $value > 0 ]]; then
      echo "Fail check, ${table_name} has $value null records in ${column_name} column that not are null in ${column_reference}"
      return -1
    fi
  done
}
