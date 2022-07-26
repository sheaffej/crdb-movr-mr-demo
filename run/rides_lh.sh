#!/usr/bin/env bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source $MYDIR/../demo.env

echo
echo "Leasholders for table: rides"
echo

echo \
"select table_name, r.range_id, r.node_id as leaseholder_node, n.locality from
  [select table_name, range_id, unnest(replicas) as node_id, lease_holder
    from [select * from crdb_internal.ranges where table_name = 'rides']
    group by table_name, range_id, node_id, lease_holder order by node_id]
  AS r INNER JOIN crdb_internal.gossip_nodes n on r.node_id = n.node_id
where r.node_id = r.lease_holder
;" | roachprod sql $CLUSTER:1 -- --format table 2>/dev/null