#!/usr/bin/env bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $MYDIR/../demo.env

if [[ $# -lt 2 ]]; then
    echo
    echo "$0 start|stop region"
    echo
    exit 1
fi

OP=$1

case $2 in
    OR)
        NODES="5-7"
        ;;
    SLC)
        NODES="1-3"
        ;;

    ASH)
        NODES="9-11"
        ;;

    SC)
        NODES="13-15"
        ;;
    *)
        echo "error"
        exit 1
    ;;
esac

roachprod status $CLUSTER

if [[ $OP == "start" ]]; then
    roachprod start $CLUSTER:${NODES} --args '--max-offset=250ms'
else
    echo
    read -p "Press ENTER to continue ..."
    roachprod stop $CLUSTER:${NODES}
fi

roachprod status $CLUSTER
