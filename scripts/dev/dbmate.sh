#!/usr/bin/env bash

if [[ -z $1 ]]
then
  echo missing database name parameter
  exit 1
fi

NAME=${1?}
ROOT_DIR=$(cd $(dirname $0)/../.. && pwd)

export DBMATE_MIGRATIONS_DIR=$ROOT_DIR/database/sql/$NAME/migrations
export DBMATE_SCHEMA_FILE=$ROOT_DIR/database/sql/$NAME/schema.sql

if [[ ! -f $DBMATE_SCHEMA_FILE ]]
then
  echo incorrect database name parameter
  exit 1
fi

if [[ $NAME == "musicbrainz" ]]
then
  DBNAME=$NAME
else
  DBNAME=acoustid_$NAME
fi

shift

exec dbmate -u "postgres://postgres:notreallyapassword@127.0.0.1:15432/$DBNAME?sslmode=disable" "$@"
