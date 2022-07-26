#!/usr/bin/env bash

# CLUSTER=j4-appl-mr-demo
# LIFETIME="12h0m0s"
# MACHINE="n2-standard-2"
# RELEASE="v21.2.10"
# ZONES="us-west3-b,us-west1-b,us-east4-b,us-east1-b"
# NODES=16

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${MYDIR}/../demo.env

# Launching 16 nodes with 4 zones
# puts 4 nodes in each of the 4 zones,

roachprod create ${CLUSTER} \
   -n ${NODES} \
   --gce-machine-type=${MACHINE} \
   --gce-zones=${ZONES} \
   --geo \
   --lifetime=${LIFETIME}

roachprod stage ${CLUSTER} release ${RELEASE}


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "               Starting cluster"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# Start CRDB nodes
roachprod start ${CLUSTER}:1-3,5-7,9-11,13-15 --args "--max-offset 250ms"

roachprod adminurl ${CLUSTER}:1 --open
roachprod status ${CLUSTER}


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "               Configuring cluster"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# Set cluster settings
echo "
SET CLUSTER SETTING cluster.organization = 'J4 CRL Demo';
SET CLUSTER SETTING enterprise.license = 'crl-0-EMT6xJ0GGAIiC0o0IENSTCBEZW1v';
SET CLUSTER SETTING kv.snapshot_rebalance.max_rate = '4g'; 
SET CLUSTER SETTING kv.snapshot_recovery.max_rate = '4g';
SET CLUSTER SETTING server.time_until_store_dead = '1m15s';
" | roachprod sql $CLUSTER:1

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "               Installing HAProxy"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

function install_haproxy () {
    local driver=$1
    echo "---------- Installing on driver ${driver} --------"
    roachprod run $CLUSTER:${driver} -- sudo apt-get -qq update
    roachprod run $CLUSTER:${driver} -- sudo apt-get -qq install -y haproxy
}

function push_haproxy_cfg () {
    local driver=$1
    local nodes=$2
    # Put haproxy.cfg in /etc/haproxy/haproxy.cfg
    echo "---------- Building configuration for driver ${driver} --------"
    CFG="/tmp/haproxy.cfg.${driver}"
    cp $MYDIR/../haproxy.cfg.template ${CFG}
    for ip in `roachprod ip $CLUSTER:${nodes}`; do
        echo "    server cockroach-$ip $ip:26257 check port 26258" >> ${CFG}
    done

    echo "---------- Pushing configuration to driver ${driver} --------"
    roachprod put ${CLUSTER}:${driver} ${CFG}
    roachprod run ${CLUSTER}:${driver} -- sudo mv haproxy.cfg.${driver} /etc/haproxy/haproxy.cfg

    echo "---------- Re-loading configuration on driver ${driver} --------"
    roachprod run ${CLUSTER}:${driver} -- sudo systemctl restart haproxy
}

# Install HAProxy on 4 driver nodes (4, 8, 12, 16)
install_haproxy 4
push_haproxy_cfg 4 '1-3'

install_haproxy 8
push_haproxy_cfg 8 '5-7'

install_haproxy 12
push_haproxy_cfg 12 '9-11'

install_haproxy 16
push_haproxy_cfg 16 '13-15'

