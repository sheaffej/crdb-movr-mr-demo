from datetime import datetime as dt
from statistics import mean
from time import perf_counter, sleep
from threading import RLock

import psycopg2
from sqlalchemy.engine import Engine as SAEngine
from sqlalchemy.exc import DatabaseError


class OpStats():
    def __init__(self, op_name: str) -> None:
        self.name = op_name

        # Stats as they are collected
        self.count = 0
        self.ms_sum = 0.0

        # Stats after being calcuated for a reporting interval
        self.last_count = 0
        self.last_ops = 0.0
        self.last_ms_avg = 0.0

    def __str__(self):
        return f"OpStats: name={self.name} count={self.count} ms_sum={self.ms_sum} last_count={self.last_count} last_ops={self.last_ops} last_ms_avg={self.last_ms_avg}"


class DemoStats():
    """This is thread safe. All threads would share the same instance."""

    OP_READ_USER = 'read_user'
    OP_READ_VEHICLE = 'read_vehicle'
    OP_READ_RIDE = 'read_ride'
    OP_READ_RIDE_AOST = 'read_ride_aost'
    OP_INSERT_RIDE = 'insert_ride'
    OP_UPDATE_RIDE = 'update_ride'
    OP_INSERT_LOCATION = 'insert_location'
    OP_READ_LAST_LOCATION = 'read_last_location'
    OP_UPDATE_VEHICLE_STATUS = 'update_vehicle_status'

    def __init__(self, reporting_inteval_secs: int) -> None:

        self.reporting_secs = reporting_inteval_secs
        self.lock = RLock()  # Make this thread safe

        self.reporting_timer = DemoTimer()
        self.reporting_timer.start()

        self.op_names = [
            DemoStats.OP_READ_USER,
            DemoStats.OP_READ_VEHICLE,
            DemoStats.OP_INSERT_RIDE,
            DemoStats.OP_UPDATE_RIDE,
            DemoStats.OP_INSERT_LOCATION,
            DemoStats.OP_READ_LAST_LOCATION,
            DemoStats.OP_READ_RIDE,
            DemoStats.OP_UPDATE_VEHICLE_STATUS,
            DemoStats.OP_READ_RIDE_AOST
        ]

        self.stats_objs = {}
        for op_name in self.op_names:
            self.stats_objs[op_name] = OpStats(op_name)

    def add_to_stats(self, op_name: str, time_ms: float) -> None:
        with self.lock:
            stat = self.stats_objs.get(op_name, time_ms)  # type: OpStats
            stat.count += 1
            stat.ms_sum += time_ms

    def calc_and_reset_stats(self) -> dict:
        with self.lock:
            for op_name in self.op_names:
                stat = self.stats_objs.get(op_name)  # type: OpStats

                # Calc aggregate stats
                if stat.count > 0:
                    stat.last_count = stat.count
                    stat.last_ops = stat.count / self.reporting_secs
                    stat.last_ms_avg = stat.ms_sum / stat.count

                # Reset counting stats
                stat.count = 0
                stat.ms_sum = 0.0

    def display_if_ready(self):
        if self.reporting_timer.get() > self.reporting_secs * 1000:

            self.reporting_timer.start()  # Reset the stats timer
            self.calc_and_reset_stats()

            statstime = dt.now()  # For displaying the time of the stats

            global_reads_ms = mean([self.stats_objs[DemoStats.OP_READ_USER].last_ms_avg, self.stats_objs[DemoStats.OP_READ_VEHICLE].last_ms_avg])
            global_writes_ms = mean([self.stats_objs[DemoStats.OP_UPDATE_VEHICLE_STATUS].last_ms_avg])
            regional_reads_ms = mean([self.stats_objs[DemoStats.OP_READ_RIDE].last_ms_avg])
            regional_writes_ms = mean(
                [
                    self.stats_objs[DemoStats.OP_INSERT_RIDE].last_ms_avg,
                    self.stats_objs[DemoStats.OP_UPDATE_RIDE].last_ms_avg
                ]
            )
            regional_aost_reads_ms = mean([self.stats_objs[DemoStats.OP_READ_RIDE_AOST].last_ms_avg])
            rbr_reads_ms = mean([self.stats_objs[DemoStats.OP_READ_LAST_LOCATION].last_ms_avg])
            rbr_writes_ms = mean([self.stats_objs[DemoStats.OP_INSERT_LOCATION].last_ms_avg])

            print(statstime)
            print('---------------------------------------')
            print('Global tables (users, vehicles)')
            print(f"  reads:  {global_reads_ms:>8.2f} ms avg")
            print(f"  writes: {global_writes_ms:>8.2f} ms avg")
            print()
            print('Regional tables (rides)')
            print(f"  reads:  {regional_reads_ms:>8.2f} ms avg")
            print(f"  AOST:   {regional_aost_reads_ms:>8.2f} ms avg")
            print(f"  writes: {regional_writes_ms:>8.2f} ms avg")
            # print(f"OP_INSERT_RIDE: {self.stats_objs[DemoStats.OP_INSERT_RIDE].last_ms_avg}")
            # print(f"OP_UPDATE_RIDE: {self.stats_objs[DemoStats.OP_UPDATE~~_RIDE].last_ms_avg}")
            print()
            print('RBR tables (vehicle_location_histories)')
            print(f"  reads:  {rbr_reads_ms:>8.2f} ms avg")
            print(f"  writes: {rbr_writes_ms:>8.2f} ms avg")
            print()


class DemoTimer():
    """This is NOT thread safe. Each thread should use its own instance."""

    def __init__(self) -> None:
        self.starttime: float = None   # Seconds

    def start(self) -> None:
        self.starttime = perf_counter()

    def stop(self) -> float:
        """Stops the timer, and returns the elapsed time in milliseconds"""
        stoptime = perf_counter()
        time_ms = (stoptime - self.starttime) * 1000
        return time_ms

    def get(self) -> float:
        """Does the same thing as stop, since stop doesn't actually stop the timer"""
        return self.stop()


def run_transaction(db_engine: SAEngine, txn_func, max_retries=10):
    # psycopg2 exceptions doc: https://www.psycopg.org/docs/errors.html
    retry_count = 0
    while True:
        try:
            with db_engine.connect().execution_options(isolation_level='AUTOCOMMIT') as conn:
                result = txn_func(conn)
                return result

        except DatabaseError as e:
            if max_retries is not None and retry_count >= max_retries:
                raise
            retry_count += 1

            # Broken connection will be
            # -------------------------
            # Execption <class 'sqlalchemy.exc.OperationalError'>
            # Orig execption <class 'psycopg2.OperationalError'>
            # PG error #: None
            if isinstance(e.orig, psycopg2.OperationalError) and e.orig.pgcode is None:
                print("Connection lost, attempting to reconnect...")
                retry_count = 0   # try indefinitely
                sleep(1)
                continue

            # Transaction isolation error will be
            # -----------------------------------
            # Execption <class 'sqlalchemy.exc.OperationalError'>
            # Orig execption <class 'psycopg2.errors.SerializationFailure'>
            # PG error #: 40001
            #
            # Transient txn error will be
            # ---------------------------
            # Execption <class 'sqlalchemy.exc.OperationalError'>
            # Orig execption <class 'psycopg2.errors.StatementCompletionUnknown'>
            # PG error #: 40003
            elif isinstance(e.orig, psycopg2.OperationalError) and e.orig.pgcode is not None:
                print(f"Retrying {retry_count}/{max_retries} on PG error # {e.orig.pgcode}")
                continue

            # Raise everything else
            else:
                raise
