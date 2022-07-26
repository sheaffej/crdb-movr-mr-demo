#!/usr/bin/env bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${MYDIR}/../demo.env

${MYDIR}/startup/cluster.sh
${MYDIR}/startup/load_database.sh
${MYDIR}/startup/push_demo.sh

roachprod status ${CLUSTER}