#!/usr/bin/env python3
import os

from sqlalchemy import create_engine

from movr.transactions2 import read_ride_info

DB_URI = os.getenv('DB_URI', 'cockroachdb://root@127.0.0.1:26257/movr_demo?application_name=movr_demo')
db_engine = create_engine(DB_URI)


with db_engine.connect() as conn:
    while True:
        read_ride_info(conn, '00000000-0000-4000-8000-000000000000')
