#!/usr/bin/env bash

for instance in app fingerprint ingest
do

    kubectl exec -ti deployment.apps/postgresql-$instance-stolonctl -- \
        pg_dump -s -N _acoustid_repl --no-owner acoustid \
        | grep -v _acoustid_repl \
        | grep -v '^SET ' \
        | grep -v '^SET ' \
        | grep -v '^--' \
        | sed 's/public\.//g' \
        | sed '/^$/N;/^\n$/D' \
        > sql/$instance/schema.sql

    dos2unix sql/$instance/schema.sql

done
