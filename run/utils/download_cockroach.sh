#!/usr/bin/env bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

URL='https://binaries.cockroachdb.com/cockroach-v21.2.10.linux-amd64.tgz'

cd /tmp
wget ${URL}

tar xf cockroach-v*.linux-amd64.tgz

CRDBBIN=`find \`pwd\` -name "cockroach-v*.linux-amd64" -print | head -1`
ln -s $CRDBBIN/cockroach /usr/local/bin/cockroach

