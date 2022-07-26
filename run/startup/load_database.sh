#!/usr/bin/env bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${MYDIR}/../demo.env

roachprod put ${CLUSTER}:1 ${MYDIR}/../sql/import.sql
roachprod run ${CLUSTER}:1 -- "cat import.sql | ./cockroach sql --insecure"