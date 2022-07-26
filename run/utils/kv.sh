#!/usr/bin/env bash

READ_PCT=90
CONCURRENCY=48
MAX_RATE=1000

cockroach workload run kv \
--tolerate-errors --read-percent ${READ_PCT} --concurrency ${CONCURRENCY} --max-rate ${MAX_RATE} \
${KV_DB_URI} 2>/dev/null