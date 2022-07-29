# CockroachDB MovR multi-region demo

This demo demonstrates the latencies expected from the three types of multi-region tables (Global, Regional, Regional-by-row) using a modified variant of the MovR app. It then demonstrates what happens to the application when a region fails.

The scripts in this demo were created for use with `roachprod`. However they could be modified to be used with any deployment of CockroachDB. To be able to simulate region failure, the CockroachDB deployment would need to have the ability to manually bring down nodes and leave them down (i.e. not possible with CockroachCloud today).

# Walkthrough of the demo
## Setup
I recommend opening three terminals, and arrange them like so:

![](/docs/mr-demo-1-latencies.png)

The top-left terminal you will use for controlling the demo. The bottom two terminals are for running the `demo.py` application in two regions (OR and SC, respectively). The [regions.png](/docs/regions.jpg) graphic is in this repositories `/docs` folder.


Assuming each terminal has it's current working directory at the root of this repository, run these commands to prepare the demo:

**Top-left (controller terminal)**

For `roachprod` to work, you need to modify the `CLUSTER` variable in the file `demo.env`:
```
# You must change this for roachprod to work
CLUSTER=j4-movr-mr-demo

...
...
```

Run these command in this terminal to launch and prepare the cluster and the application servers:
```
source demo.env
run/init_demo.sh
```

**Bottom-left (West/OR app)**

SSH into the app server in that region (i.e. the 4th server in that region):
```
source demo.env
roachprod ssh $CLUSTER:8
```

…then start the app in that region.
```
crdb-movr-demo/demo.py
```

**Bottom-right (East/SC app)**

SSH into the app server in that region (i.e. the 4th server in that region):
```
source demo.env
roachprod ssh $CLUSTER:16
```

…then start the app in that region.
```
crdb-movr-demo/demo.py
```

**Top-right (Diagram)**

Load up [regions.png](/docs/regions.jpg) in an image viewer

![regions.png](/docs/regions.jpg)

## Explain the terminals
To start the demo, it's a good idea to explain how you will be using the three terminals. You may want to mention that the app is configured to connect to the CockroachDB nodes in its same region through an HAProxy load balancer. However, each region's app is not configured to connect to another region's CockroachDB nodes if its CockroachDB nodes are down. Instead, the app will just enter a retry loop and wait for the CockroachDB nodes to return.


## Discus the latencies
Explain why the read and write latencies for each category of table are the way we see. This helps the viewers undestand the latency and staleness tradeoffs for each category of table.
- Call out which are the tables in that type
- Highlight the read or write times
- Explain why they are different between the regions

![](/docs/mr-demo-1-latencies.png)

After you have discussed how the latencies are during normal operation, move on to failing a region so you can discuss how the application and cluster behaves after the failure.

## Prep for failure
You should explain what will happen to applications before you initiate the failure. That way, the viewers know what to look for.

Asuuming you are failing the OR region (us-west1):
- The OR app will enter retry loop, waiting for the nodes to return
- The SC will continue reading and writing after the failure
  - The SC app will likely see about 5 seconds of high latency as the leaseholders in OR are re-elected. This is also the refresh interval of the app output, therefore it should be at most 2 app update cyles of higher-than-normal latency.
- Leaseholders for the regional table (rides) will move to a surviving region
  - So the reads will have less latency since any surviving region would be closer to SC than OR was.

Bring up DB Console and show the nodes status page
- Highlight the top status bar showing 12 nodes live, 0 suspect, 0 dead
- Highlight the top status bar showing 0 under-replicated and unavailable ranges
- After stoping the region's nodes, you'll revisit this page to show how the cluster is managing the failure

## Fail the OR region
In the control terminal, run the `run/nodes.sh` script with the arguments `stop OR` to stop all CockroachDB nodes in us-west1/OR.
```
run/nodes.sh stop OR
```

After failing the region:
- Highlight that the failed region's app entered the retry loop
- Highlight that the surviving region's app continues to read and write
- Then switch over to the DB Console to show the nodes as Suspect and the ranges as under-replicated
  - The cluster is set to declare nodes dead after 1m15s, so do this before the nodes are declared dead
- After the nodes are declared dead, show in DB console that there are no longer any under-replicated ranges
- Highlight in the surviving region's app that the Global and RBR tables have the same latencies as before. The read and write latencies of the Regional table will have changed (either slightly or a lot depending on where the leaseholders moved to)
  - Explain why the Regional table's latencies are the way they are (i.e. based on the latencies, which region has the leaseholders now?)

![](/docs/mr-demo-2-OR-fail.png)

The leaseholders in OR will move to some region, but due to the low throughput of the application, they can likely move to any region. The viewers may ask how to control which region the leaseholder will fail over to. You can optionally show them changing the primary region for the database, which will control exactly where the leaseholders will move to.

Optionally, change the database's primary region via SQL:
```
roachprod sql $CLUSTER:1
```

Then run the SQL statement:
```
alter database movr_demo primary region "us-east1";
```

## Restore OR
If you changed the database's primary region, revert it back:
```
alter database movr_demo primary region "us-west1";
```

Then bring up the OR CockroachDB nodes
```
run/nodes.sh start OR
```

After re-starting the failed region
- Highlight how the application in that region reconnects automatically via the retry loop
- Quickly highlight that the latencies for the Regional (rides) table is higher in the primary region, because the leaseholder has not yet moved back
  - Likewise, you can highlight that the Regional table's latencies in SC are lower than the normal situation

![](/docs/mr-demo-3-OR-restore.png)

Within abut 30 seconds, the leaseholders should move back to OR
  - You can call attention to this as it's happening if you watch the latencies in the OR region

![](/docs/mr-demo-4-normal.png)
