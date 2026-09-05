"""Warm single-connection SQLite benchmark, synthetic data only.
Run: python3 tool/benchmarks/sync_queue_queries.py > sync-queue-benchmark.json
Schema exported by SyncDatabase(inMemoryDatabase:true), sqlite_master at d9a4f2a99.
No wall-time assertions: native VM instruction count and results are deterministic.
"""
import json
import pathlib
import sqlite3
import statistics
import tempfile
import time

SCHEMA = (
    pathlib.Path(__file__).resolve().parents[2]
    / 'docs/perf/fixtures/sync-v29.sql'
).read_text()
QUERIES = {'pending_one': ('SELECT * FROM outbox WHERE status = 0 ORDER BY priority ASC, '
                 'created_at ASC, id ASC LIMIT ?',
                 (1,)),
 'pending_batch': ('SELECT * FROM outbox WHERE status = 0 ORDER BY priority ASC, '
                   'created_at ASC, id ASC LIMIT ?',
                   (20,)),
 'pending_exists_candidate': ('SELECT EXISTS(SELECT 1 FROM outbox WHERE status = 0) AS '
                              'present',
                              ()),
 'actionable_count': ('SELECT COUNT(*) AS cnt FROM outbox INDEXED BY '
                      'idx_outbox_actionable_priority_created_at WHERE status IN (0, '
                      '3)',
                      ()),
 'actionable_count_unhinted': ('SELECT COUNT(*) AS cnt FROM outbox WHERE status IN (0, '
                               '3)',
                               ()),
 'queue_marker': ('SELECT * FROM queue_markers WHERE room_id = ?', ('room-0000',)),
 'depth_current': ('SELECT status, producer, COUNT(*) AS cnt, MIN(enqueued_at) AS '
                   "oldest FROM inbound_event_queue WHERE status IN ('enqueued', "
                   "'leased', 'retrying', 'abandoned') GROUP BY status, producer",
                   ()),
 'depth_including_applied_legacy': ('SELECT status, producer, COUNT(*) AS cnt, '
                                    'MIN(enqueued_at) AS oldest FROM '
                                    "inbound_event_queue WHERE status IN ('enqueued', "
                                    "'leased', 'retrying', 'abandoned', 'applied') "
                                    'GROUP BY status, producer',
                                    ()),
 'applied_count': ('SELECT COUNT(queue_id) AS cnt FROM inbound_event_queue INDEXED BY '
                   "idx_inbound_event_queue_status_enqueued WHERE status = 'applied'",
                   ())}

# The dequeue companion may inspect sending leases even with no expired row.
QUERIES['expired_sending_none'] = (
    'SELECT * FROM outbox WHERE status = 3 AND updated_at < ? '
    'ORDER BY priority ASC, created_at ASC, id ASC LIMIT ?',
    (1700000000, 20),
)
QUERIES['expired_sending_all'] = (
    'SELECT * FROM outbox WHERE status = 3 AND updated_at < ? '
    'ORDER BY priority ASC, created_at ASC, id ASC LIMIT ?',
    (1900000000, 20),
)

def measure(c, sql, args):
    expected = c.execute(sql, args).fetchall()
    times = []
    for _ in range(21):
        start = time.perf_counter_ns()
        actual = c.execute(sql, args).fetchall()
        times.append((time.perf_counter_ns() - start) / 1000000.0)
        assert actual == expected
    steps = 0

    def step():
        nonlocal steps
        steps += 1
        return 0
    c.set_progress_handler(step, 1)
    c.execute(sql, args).fetchall()
    c.set_progress_handler(None, 0)
    return {
        'median_ms': statistics.median(times),
        'p95_ms': sorted(times)[19],
        'vm_steps': steps,
        'result_rows': len(expected),
        'plan': [r[3] for r in c.execute('EXPLAIN QUERY PLAN ' + sql, args)],
    }


results = []
for history, active in [(0, 100), (100000, 0), (100000, 100), (100000, 10000), (100000, 100000)]:
    with tempfile.TemporaryDirectory(prefix='lotti-sync-benchmark-') as tmp:
        c = sqlite3.connect(str(pathlib.Path(tmp) / 'sync.sqlite'))
        c.executescript(SCHEMA)
        c.execute('PRAGMA journal_mode=WAL')
        c.execute('PRAGMA synchronous=NORMAL')
        payload = json.dumps({'synthetic': True, 'text': 'x' * 1000})
        outbox = 'INSERT INTO outbox(created_at,updated_at,status,message,subject,priority) VALUES(?,?,?,?,?,?)'
        c.executemany(outbox, ((1700000000 + i, 1700000000 + i, 1, payload, 'synthetic-history', i % 3) for i in range(history)))
        c.executemany(outbox, ((1800000000 + i, 1800000000 + i, 0 if i % 2 == 0 else 3, payload, 'synthetic-active', i % 3) for i in range(active)))
        inbound = 'INSERT INTO inbound_event_queue(event_id,room_id,origin_ts,producer,raw_json,enqueued_at,status) VALUES(?,?,?,?,?,?,?)'
        statuses = ['enqueued', 'leased', 'retrying', 'abandoned']
        c.executemany(inbound, ((f'history-{i}', 'room-0000', 1700000000000 + i, f'producer-{i % 3}', payload, 1700000000000 + i, 'applied') for i in range(history)))
        c.executemany(inbound, ((f'active-{i}', 'room-0000', 1800000000000 + i, f'producer-{i % 3}', payload, 1800000000000 + i, statuses[i % 4]) for i in range(active)))
        c.executemany('INSERT INTO queue_markers(room_id,last_applied_ts) VALUES(?,?)', ((f'room-{i:04}', 1700000000000 + i) for i in range(1 if history == 0 else 1000)))
        c.commit()
        assert c.execute(QUERIES['actionable_count'][0]).fetchone()[0] == active
        assert c.execute(QUERIES['applied_count'][0]).fetchone()[0] == history
        assert sum((r[2] for r in c.execute(QUERIES['depth_current'][0]))) == active
        pending = c.execute(*QUERIES['pending_batch']).fetchall()
        assert [r[0] for r in pending] == [history + i + 1 for i in sorted(range(0, active, 2), key=lambda i: (i % 3, i))[:20]]
        for analyzed in [False, True]:
            if analyzed:
                c.execute('ANALYZE')
            row = {'history': history, 'active': active, 'rooms': 1 if history == 0 else 1000, 'analyzed': analyzed, 'queries': {name: measure(c, *query) for name, query in QUERIES.items()}}
            # Excludes commit/fsync; reads above also exclude Drift transport.
            c.execute('SAVEPOINT insert_probe')
            times = []
            for i in range(21):
                start = time.perf_counter_ns()
                c.execute(outbox, (1900000000 + i, 1900000000 + i, 0, payload, 'synthetic-insert', i % 3))
                times.append((time.perf_counter_ns() - start) / 1000000.0)
            c.execute('ROLLBACK TO insert_probe')
            c.execute('RELEASE insert_probe')
            row['insert_no_commit'] = {'median_ms': statistics.median(times), 'p95_ms': sorted(times)[19]}
            results.append(row)
        c.close()
print(json.dumps({'sqlite_version': sqlite3.sqlite_version, 'source_commit': 'd9a4f2a99', 'payload_bytes': len(payload), 'results': results}, indent=2))
