#!/usr/bin/env bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_DIR=${MYDIR}/../..
PROJECT_NAME="crdb-movr-mr-demo"
source ${PROJECT_DIR}/demo.env

TARBALL="crdb-movr-demo.tgz"

pushd ${PROJECT_DIR}/..
tar czf /tmp/${TARBALL} crdb-movr-mr-demo

roachprod run ${CLUSTER}:4,8,12,16 -- rm -Rf ${PROJECT_NAME}
roachprod put ${CLUSTER}:4,8,12,16 /tmp/${TARBALL}
roachprod run ${CLUSTER}:4,8,12,16 -- tar xzf ${TARBALL}
roachprod run ${CLUSTER}:4,8,12,16 -- rm -f ${TARBALL}
roachprod run ${CLUSTER}:4,8,12,16 -- ls -ld ${PROJECT_NAME}\*


roachprod run ${CLUSTER}:4,8,12,16 -- sudo apt-get -qq -y install python3-pip
roachprod run ${CLUSTER}:4,8,12,16 -- pip install -r ${PROJECT_NAME}/requirements.txt
