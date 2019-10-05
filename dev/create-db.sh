#!/usr/bin/env bash

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

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

psql -v ON_ERROR_STOP=1 --username acoustid --dbname acoustid_app -f /mnt/sql/app/schema.sql
psql -v ON_ERROR_STOP=1 --username acoustid --dbname acoustid_fingerprint -f /mnt/sql/fingerprint/schema.sql
psql -v ON_ERROR_STOP=1 --username acoustid --dbname acoustid_ingest -f /mnt/sql/ingest/schema.sql
psql -v ON_ERROR_STOP=1 --username acoustid --dbname musicbrainz -f /mnt/sql/musicbrainz/schema.sql

psql -v ON_ERROR_STOP=1 --username acoustid --dbname acoustid_app_test -f /mnt/sql/app/schema.sql
psql -v ON_ERROR_STOP=1 --username acoustid --dbname acoustid_fingerprint_test -f /mnt/sql/fingerprint/schema.sql
psql -v ON_ERROR_STOP=1 --username acoustid --dbname acoustid_ingest_test -f /mnt/sql/ingest/schema.sql
psql -v ON_ERROR_STOP=1 --username acoustid --dbname musicbrainz_test -f /mnt/sql/musicbrainz/schema.sql
