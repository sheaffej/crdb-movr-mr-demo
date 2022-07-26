#!/usr/bin/env bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${MYDIR}/../demo.env

roachprod destroy ${CLUSTER}
