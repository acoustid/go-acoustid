#!/usr/bin/env bash

set -e

#if [ -n "$POSTGRES_HOST" ]
#then
#    export PGHOST="$POSTGRES_HOST"
#fi

#if [ -n "$POSTGRES_PORT" ]
#then
#    export PGPORT="$POSTGRES_PORT"
#fi

if [ -n "$POSTGRES_USER" ]
then
    export PGUSER="$POSTGRES_USER"
fi

if [ -n "$POSTGRES_PASSWORD" ]
then
    export PGPASSWORD="$POSTGRES_PASSWORD"
fi

psql -v ON_ERROR_STOP=1 --dbname "$POSTGRES_DB" <<-EOSQL

    CREATE USER acoustid WITH PASSWORD 'acoustid';

    CREATE DATABASE acoustid_app OWNER acoustid;
    CREATE DATABASE acoustid_fingerprint OWNER acoustid;
    CREATE DATABASE acoustid_ingest OWNER acoustid;
    CREATE DATABASE musicbrainz OWNER acoustid;

    CREATE DATABASE acoustid_app_test OWNER acoustid;
    CREATE DATABASE acoustid_fingerprint_test OWNER acoustid;
    CREATE DATABASE acoustid_ingest_test OWNER acoustid;
    CREATE DATABASE musicbrainz_test OWNER acoustid;

    \c acoustid_fingerprint
    CREATE EXTENSION intarray;
    CREATE EXTENSION acoustid;

    \c musicbrainz
    CREATE EXTENSION cube;
    CREATE EXTENSION earthdistance;

    \c acoustid_fingerprint_test
    CREATE EXTENSION intarray;
    CREATE EXTENSION acoustid;

    \c musicbrainz_test
    CREATE EXTENSION cube;
    CREATE EXTENSION earthdistance;

EOSQL

export PGUSER=acoustid
export PGPASSWORD=acoustid

psql -v ON_ERROR_STOP=1 --dbname acoustid_app -f $ACOUSTID_SQL_DIR/app/schema.sql
psql -v ON_ERROR_STOP=1 --dbname acoustid_fingerprint -f $ACOUSTID_SQL_DIR/fingerprint/schema.sql
psql -v ON_ERROR_STOP=1 --dbname acoustid_ingest -f $ACOUSTID_SQL_DIR/ingest/schema.sql
psql -v ON_ERROR_STOP=1 --dbname musicbrainz -f $ACOUSTID_SQL_DIR/musicbrainz/schema.sql

psql -v ON_ERROR_STOP=1 --dbname acoustid_app_test -f $ACOUSTID_SQL_DIR/app/schema.sql
psql -v ON_ERROR_STOP=1 --dbname acoustid_fingerprint_test -f $ACOUSTID_SQL_DIR/fingerprint/schema.sql
psql -v ON_ERROR_STOP=1 --dbname acoustid_ingest_test -f $ACOUSTID_SQL_DIR/ingest/schema.sql
psql -v ON_ERROR_STOP=1 --dbname musicbrainz_test -f $ACOUSTID_SQL_DIR/musicbrainz/schema.sql
