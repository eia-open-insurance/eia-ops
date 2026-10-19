#!/bin/sh
# One PostgreSQL cluster for local deployment; each expert service owns its database.
# Runs once, from the official postgres image entrypoint, when the data volume is empty.
# POSTGRES_USER (the superuser created by the image) owns every database.
set -eu

for db in \
  eia_party \
  eia_policy \
  eia_contract \
  eia_direct \
  eia_assumed \
  eia_cession \
  eia_retrocession \
  eia_document \
  eia_payment \
  eia_notifications
do
  echo "creating database ${db}"
  psql --username "${POSTGRES_USER}" --dbname postgres --set ON_ERROR_STOP=1 \
    --command "CREATE DATABASE ${db} OWNER \"${POSTGRES_USER}\";"
done
