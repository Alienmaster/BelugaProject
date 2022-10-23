#!/bin/bash
# library for building and running the Beluga Project

set -euo pipefail

# Global variables
container_name_db=postgresdb
path_postgresql=/var/lib/postgresql
path_db_content=$path_postgresql/dbContent

aircraft_database_filename=aircraftDatabase.csv
airport_database_filename=airports.csv
aircraft_database_url=https://opensky-network.org/datasets/metadata/$aircraft_database_filename
airport_database_url=https://davidmegginson.github.io/ourairports-data/$airport_database_filename

load_beluga_db=loadBelugaDb
load_beluga_db_filename=$load_beluga_db.sh
path_load_beluga_db=assets/scripts/$load_beluga_db_filename
load_beluga_db_output_file=$load_beluga_db-output.txt

_docker_run() {
  echo "Run the containers ..."
  docker compose up
}

_docker_run_background() {
  echo "Run the containers in the background ..."
  docker compose up -d
}

_docker_build() {
  if [ -z $1 ]; then
    echo "Build all images (force rebuild of existing images) ..."
    docker compose build --progress=plain --no-cache
  else
    echo "Build the image for $1 (force rebuild of existing image) ..."
    docker compose build --progress=plain --no-cache $1
  fi
}

_copy_db_content_to_container() {
  echo "Create dbContent directory in $path_db_content ..."
  docker exec -ti $container_name_db bash -c "mkdir $path_db_content"
  echo "-> Create dbContent directory in $path_db_content. Done."

  # copy content from dbContent to container
  echo "Copy content from assets/dbContent to $path_db_content ..."
  docker cp assets/dbContent $container_name_db:$path_postgresql
  echo "-> Copy content from assets/dbContent to $path_db_content. Done."
}

_download_aircraft_database() {
  # download aircraft database file in postgres container
  echo "Download $aircraft_database_filename from Opensky-Network ..."
  docker exec -ti $container_name_db bash -c "wget $aircraft_database_url -O $aircraft_database_filename"
  echo "-> Download $aircraft_database_filename from Opensky-Network. Done."

  echo "Copy $aircraft_database_filename to $path_db_content ..."
  docker exec -ti $container_name_db bash -c "cp $aircraft_database_filename $path_db_content"
  echo "-> Copy $aircraft_database_filename to $path_db_content. Done."
}

_download_airport_database() {
  # download airport database file in postgres container
  echo "Download $airport_database_filename from OurAirports ..."
  docker exec -ti $container_name_db bash -c "wget $airport_database_url -O $airport_database_filename"
  echo "-> Download $airport_database_filename from OurAirports. Done."

  echo "Copy $airport_database_filename to $path_db_content ..."
  docker exec -ti $container_name_db bash -c "cp $airport_database_filename $path_db_content"
  echo "-> Copy $airport_database_filename to $path_db_content. Done."
}

_copy_load_db_script_to_container() {
  echo "Copy $load_beluga_db_filename to container ..."
  docker cp $path_load_beluga_db $container_name_db:$load_beluga_db_filename
  echo "-> Copy $load_beluga_db_filename to container. Done."
}

_exec_load_db_script() {
  echo "Execute $load_beluga_db_filename on container to populate database with content ..."
  docker exec $container_name_db bash -c ". $load_beluga_db_filename" >$load_beluga_db_output_file
  echo "-> Execute $load_beluga_db_filename on container to populate database with content. Done."
}

_load_db_content() {
  echo "Load csv files into postgres database ..."
  if _check_tables_exist -eq 0; then
    exit
  fi

  echo "Create dbContent directory in $path_db_content ..."
  if [[ -z $(docker exec -ti $container_name_db bash -c "if [ -d $path_db_content ]; then echo does exist; fi") ]]; then
    _copy_db_content_to_container
  else
    echo "-> Directory $path_db_content already exists. Done."
  fi

  echo "Download $aircraft_database_filename and $airport_database_filename ... "
  if [[ -z $(docker exec -ti $container_name_db bash -c "if test -f $aircraft_database_filename; then echo exists; fi") ]]; then
    _download_aircraft_database
  else
    echo "-> File $aircraft_database_filename already exists. Done."
  fi

  if [[ -z $(docker exec -ti $container_name_db bash -c "if test -f $airport_database_filename; then echo exists; fi") ]]; then
    _download_airport_database
  else
    echo "-> File $airport_database_filename already exists. Done."
  fi

  # copy load database script to container
  _copy_load_db_script_to_container

  # execute load beluga db script on db container
  _exec_load_db_script
}

_env() {
  echo "Content of .env file:"
  cat .env
}

_check_tables_exist() {
  local table_does_not_exist=true
  local table_to_check=opensky_aircraft
  local postgres_db=$(docker exec $container_name_db bash -c "echo \$POSTGRES_DB")
  local postgres_user=$(docker exec $container_name_db bash -c "echo \$POSTGRES_USER")

  echo "Check if tables in postgres database were created by spring ..."
  while $table_does_not_exist; do
    if [[ -n $(docker exec -it $container_name_db psql $postgres_db $postgres_user -c "psql $postgres_db -U $postgres_user" -c "\c $postgres_db" -c "\dt" | grep $table_to_check) ]]; then
      echo "-> Check if tables in postgres database were created by spring. Done."
      table_does_not_exist=false
      return 1
    else
      echo "-> Tables in postgres database were not created by spring yet ... waiting ..."
      sleep 1
    fi
  done
}

_install() {
  echo "Install the Beluga Project ..."

  # Remind user to check if version should be updated
  read -p "Gentle reminder: Have you configured the values in the .env file (y/n)?" choice
  case "$choice" in
  y | Y) echo "-> Yes, let's continue ..." ;;
  n | N)
    echo "-> No, let's stop here. Please set the values in the .env file. Installation aborted."
    exit
    ;;
  *)
    echo "-> Invalid, let's stop here. Installation aborted."
    exit
    ;;
  esac

  _docker_run_background

  _load_db_content

  echo "-> The Beluga Project is running. Done."
}
