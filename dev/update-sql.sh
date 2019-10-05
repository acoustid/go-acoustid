#!/usr/bin/env bash

for instance in app fingerprint ingest musicbrainz
do

    if [ "$instance" = "musicbrainz" ]
    then
        db=musicbrainz
    else
        db=acoustid
    fi

    mkdir -p sql/$instance

    kubectl exec -ti deployment.apps/postgresql-$instance-stolonctl -- \
        pg_dump -s -N _acoustid_repl --no-owner $db \
        | grep -v _acoustid_repl \
        | grep -v '^COMMENT ON EXTENSION ' \
        | grep -v '^SELECT pg_catalog.set_config' \
        | grep -v '^--' \
        > sql/$instance/schema.sql

    dos2unix sql/$instance/schema.sql

done
