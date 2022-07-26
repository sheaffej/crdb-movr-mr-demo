#!/usr/bin/env bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${MYDIR}/../demo.env

PROJECT_DIR=${MYDIR}/../

TARBALL="crdb-movr-demo.tgz"

pushd ${MYDIR}/../../
tar czf /tmp/${TARBALL} crdb-movr-demo

roachprod run ${CLUSTER}:4,8,12,16 -- rm -Rf crdb-movr-demo
roachprod put ${CLUSTER}:4,8,12,16 /tmp/${TARBALL}
roachprod run ${CLUSTER}:4,8,12,16 -- tar xzf ${TARBALL}
roachprod run ${CLUSTER}:4,8,12,16 -- rm -f ${TARBALL}
roachprod run ${CLUSTER}:4,8,12,16 -- ls -ld crdb-movr-demo\*


roachprod run ${CLUSTER}:4,8,12,16 -- sudo apt-get -qq -y install python3-pip
roachprod run ${CLUSTER}:4,8,12,16 -- pip install -r crdb-movr-demo/requirements.txt
