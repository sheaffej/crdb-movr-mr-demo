#!/usr/bin/env bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_DIR=${MYDIR}/../..
source ${PROJECT_DIR}/demo.env

roachprod put ${CLUSTER}:1 ${PROJECT_DIR}/sql/import.sql
roachprod run ${CLUSTER}:1 -- "cat import.sql | ./cockroach sql --insecure"