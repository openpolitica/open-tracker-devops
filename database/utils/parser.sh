#!/bin/bash

source utils/sql.sh

# Based on: https://www.pontikis.net/blog/store-mysql-result-to-array-from-bash
function read_sql_result_one(){
  local column_names="${@:2}"
  i=0
  VALUES=()
  cmd=`build_sql_command $1`
  while IFS=$'\t' read ${column_names[0]} ;do
    name="${column_names[0]}"
    VALUES[$i]="${!name}"
    ((i++))
  done < <( eval $cmd )
}

# Based on https://stackoverflow.com/a/16453214/5107192
function read_sql_result_two(){
  local column_names="${@:2}"
  i=0
  VALUES_1=()
  VALUES_2=()
  cmd=`build_sql_command $1`
  while IFS=$'\t' read ${column_names[@]} ;do
      IFS=' ' read -a ARRAY <<< "${column_names[@]}"
      name_1="${ARRAY[0]}"
      name_2="${ARRAY[1]}"
      VALUES_1[$i]="${!name_1}"
      VALUES_2[$i]="${!name_2}"
      ((i++))
  done < <( eval $cmd )
}
# Converts the array to a coma separated string
# Based on: https://stackoverflow.com/a/53839433/5107192
function join_arr() {
  local IFS="$1"
  shift
  echo "$*" | sed s/"$IFS"/"$IFS"\ /g
}

function join_arr_string() {
  printf -v var "\"%s\", " ${@}
  echo ${var%,\ }
}

# Get index of value in array
# Based on: https://stackoverflow.com/a/15028821/5107192
function get_index() {
  local value="$1"
  shift
  IFS=' ' read -a my_array <<< "$*"
  for i in "${!my_array[@]}"; do
     if [[ "${my_array[$i]}" = "${value}" ]]; then
         echo "${i}"
         break
     fi
  done
}
