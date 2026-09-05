# Pending scheduled-wake query investigation — 2026-09-05

The current pending-list SQL scales with the **pending set**, not accumulated
agent history. This follow-up found no justification for another index or a
scheduler cache. The historical long delays remain unexplained by this isolated
benchmark; the archived logs do not record returned-row counts.

## Scope and method

Investigated source at `d9a4f2a99`, specifically
`AgentDatabase.getPendingScheduledWakeRecords` (archive query shape 8), its
repository adapter, `pendingWakeRecordsProvider`, and the separate due-record
path in `ScheduledWakeManager`. The archive contained 4,637 calls over the slow
logging threshold, including 1,976 in September. Those are **slow-call counts**,
not total request frequency. The September slow-only median was 41.8 ms and p95
114.9 ms; its maximum was 2,126.7 ms. They measure the executor await rather than
isolated SQLite execution.

The reproducer below loads the actual current entity schema and SQL from source
into a Python SQLite 3.45.1 database on Linux ARM64. This is the system Python
engine, not the app native engine: `pubspec.lock` pins Dart `sqlite3` 3.5.2,
which is a package version rather than the SQLite runtime version. It varies 0,
10,000 and 100,000 history rows independently of 0, 10, 1,000 and 10,000 pending
rows. Half the history rows are consumed scheduled wakes; half are another
entity type. Synthetic wake payloads are about 310–320 bytes. Each case has one
warmup followed by 21 samples. SQL timings include `fetchall()` materialization
into Python tuples. Separate JSON decoding timings are Python diagnostics,
**not Dart/Freezed hydration timings**. These runs exclude Drift isolate
transport, transaction contention and application load; warm timings also
exclude file I/O and SQLite page-cache misses.

`ANALYZE` runs after each fixture update. The SQLite progress handler counts
100-opcode blocks in one further query execution, outside timing samples;
reported work is rounded down to that resolution. Fixture insertion and index
maintenance are not included. No real user data or databases are used.

Each fixture is also backed up to a temporary synthetic database. Each query's
first read opens a fresh SQLite connection to that snapshot; this has a cold
SQLite page/statement cache but a potentially warm operating-system cache from
the backup. The first-read timer includes query preparation and fetching, not
opening the connection. These are **not cold physical-disk measurements** and
are single observations rather than percentiles. Snapshot files are cleaned up
at the end. Warm measurements use the original in-memory database.

## Results

| History rows | Pending rows returned | Fresh connection ms | Warm fetch median ms | Warm fetch p95 ms | JSON decode median ms | Approximate VM steps |
|---|---|---|---|---|---|---|
| 0 | 0 | 0.367 | 0.001 | 0.001 | 0.000 | 0 |
| 0 | 10 | 0.119 | 0.013 | 0.016 | 0.014 | 100 |
| 0 | 1,000 | 1.522 | 1.007 | 1.253 | 1.449 | 13,000 |
| 0 | 10,000 | 15.519 | 11.780 | 14.905 | 17.807 | 130,000 |
| 10,000 | 0 | 0.173 | 0.001 | 0.002 | 0.000 | 0 |
| 10,000 | 10 | 0.671 | 0.013 | 0.016 | 0.014 | 100 |
| 10,000 | 1,000 | 1.434 | 1.209 | 2.353 | 1.623 | 13,000 |
| 10,000 | 10,000 | 13.277 | 11.721 | 15.728 | 16.659 | 130,000 |
| 100,000 | 0 | 0.139 | 0.001 | 0.001 | 0.000 | 0 |
| 100,000 | 10 | 0.155 | 0.012 | 0.014 | 0.013 | 100 |
| 100,000 | 1,000 | 1.546 | 1.025 | 1.159 | 1.363 | 13,000 |
| 100,000 | 10,000 | 13.713 | 11.436 | 12.826 | 15.342 | 130,000 |

Every pending-list plan is:

```text
SCAN agent_entities USING INDEX idx_agent_entities_pending_scheduled_wake_at
```

This is a walk over the pending partial index, not a scan of the entire entity
table. There is no temporary sort. With 10,000 pending wakes, the query returns
about 3.2 MB of serialized JSON and performs approximately 130,000 VM steps.
The caller requests every pending wake, so that growth is expected. This stress
case is not an estimate of the user's actual pending-set size.

The 10 ms slow-log threshold is crossed by the complete fetch around the
10,000-row stress point on this machine; 1,000 rows remain around 1 ms.
That is a bracket, not a measured exact crossover, and it excludes application
hydration and contention. First reads of the snapshot include schema/query
preparation and page-cache work; none approach the logged multi-second stalls.

The due-record query uses:

```text
SEARCH agent_entities USING INDEX idx_agent_entities_pending_scheduled_wake_at (<expr><?)
```

Its cutoff selects only the first five pending records. With nonempty pending
fixtures it returns five rows regardless of history or pending-set size, taking
roughly 0.006–0.008 ms median in this run. Its VM work stays near 100 steps.
SQLite's plan renders the inclusive bound as `<expr><?`; the source predicate
remains `<= ?1`, and the reproducer verifies all five rows including the cutoff.

## Refresh and hydration audit

`AgentRepoEvolution.getPendingScheduledWakeRecords` has one production caller:
`pendingWakeRecordsProvider`. That provider is shared by the sidebar activity
summary, sidebar queue, agent settings count and pending-wakes view model. They
watch the same provider instance; there is no separate query per mounted
consumer in one provider container.

The provider refreshes on the global `agentNotification` topic. For each build,
it reads identities, the complete pending scheduled-record list, then one batch
of latest states filtered for pending wake fields. It explicitly includes agents
from scheduled records in the state request. That inclusion is necessary:
workspace-scoped wakes do not require a state-level wake field. Scheduled
records are decoded once in the repository before the merged timeline is built.
The complete identity/state objects support labels, linked subjects and cancel
actions; an SQL projection is not an established improvement here.

`UpdateNotifications` already batches UI-only and local notifications over
100 ms, and sync notifications over one second. Separate origin batches can
still emit separately. The global topic is broad, but identity, lifecycle,
state wake fields and scheduled records can all change the merged result.
`persistedStateChangedNotifier` carries an affected id and the global topic,
not an entity-type-specific change classification. Filtering global events or
caching just the scheduled list without a complete invalidation contract could
hide cancellations, sync updates or newly scheduled work. This audit does not
prove that every current refresh is necessary; it establishes why a blanket
cache or event filter is not justified by the archive alone.

`ScheduledWakeManager` does **not** call the all-pending listing. Its startup,
hourly, explicit and lease retry passes use due-range reads. Overlapping checks
already coalesce with one requested rerun. Fresh reads around awaited identity
and state writes protect cancellation and lifecycle transitions. The generation
guards and restart handoff prevent stopped passes from launching work. These
reads must not be removed merely because their SQL shapes repeat in the logs.

## Disposition

No runtime change is proposed for this query family. Before changing it, capture
pending rows returned, payload size and refresh origin alongside executor timing
in a representative post-fix workload. If a genuinely large pending backlog is
confirmed, investigate why records remain pending before imposing a limit that
would hide real wakes. If repeated scans dominate despite a small pending set,
measure shared executor waiting and the entire provider build; the isolated SQL
cost here does not explain the archived delays.

The existing `agent_database_test.dart` contains a pending/due index-plan check.
This investigation adds no Dart code or tests, so it does not claim a new Dart
regression fix or a Flutter performance measurement. The reproducer asserts
returned counts, pending status and chronological order for every case.

## Reproduce

From the repository root, run this Python program. It reads the current source,
creates in-memory databases plus temporary synthetic snapshots, and prints all cardinalities, plans and raw
summary measurements. Python's standard library is sufficient.

```python
import datetime, json, pathlib, sqlite3, statistics, tempfile, time
root = pathlib.Path.cwd()
schema = (root / 'lib/features/agents/database/agent_database.drift').read_text().split('CREATE TABLE agent_links')[0]
source = (root / 'lib/features/agents/database/agent_database.dart').read_text()
def query(method):
    return source.split('Selectable<AgentEntity> ' + method + '(')[1].split("r'''", 1)[1].split("'''", 1)[0]
queries = {'pending': query('getPendingScheduledWakeRecords'), 'due': query('getDueScheduledWakeRecords')}
base = datetime.datetime(2026, 9, 5)
cutoff = (base + datetime.timedelta(minutes=4)).isoformat(timespec='milliseconds')
scratch = tempfile.TemporaryDirectory(prefix='lotti-wake-benchmark-')
snapshot = pathlib.Path(scratch.name) / 'synthetic.sqlite'
report = {'sqlite': sqlite3.sqlite_version, 'clock': 'perf_counter', 'samples': 21, 'measurements': []}
for history in (0, 10000, 100000):
    db = sqlite3.connect(':memory:')
    db.executescript(schema)
    def rows(count, pending):
        for i in range(count):
            kind = 'scheduledWake' if pending or i % 2 == 0 else 'agentState'
            stamp = (base + datetime.timedelta(minutes=i)).isoformat(timespec='milliseconds')
            key = ('pending-' if pending else 'history-') + str(i)
            payload = {'runtimeType': kind, 'id': key, 'agentId': f'agent-{i % 100}', 'scheduledAt': stamp, 'status': 'pending' if pending else 'consumed', 'reason': 'synthetic scheduled work', 'updatedAt': stamp, 'vectorClock': None, 'workspaceKey': f'day:synthetic-{i}', 'triggerTokens': [f'synthetic-token-{i}']}
            yield (key, f'agent-{i % 100}', kind, None, None, 1788566400, 1788566400, None, json.dumps(payload), 1)
    db.executemany('INSERT INTO agent_entities VALUES (?,?,?,?,?,?,?,?,?,?)', rows(history, False))
    for pending in (0, 10, 1000, 10000):
        db.execute("DELETE FROM agent_entities WHERE id LIKE 'pending-%'")
        db.executemany('INSERT INTO agent_entities VALUES (?,?,?,?,?,?,?,?,?,?)', rows(pending, True))
        db.commit()
        db.execute('ANALYZE')
        snapshot.unlink(missing_ok=True)
        disk = sqlite3.connect(snapshot)
        db.backup(disk)
        disk.close()
        for name, sql in queries.items():
            args = {'1': cutoff} if name == 'due' else ()
            cold = sqlite3.connect(snapshot)
            start = time.perf_counter()
            cold_result = cold.execute(sql, args).fetchall()
            cold_ms = (time.perf_counter() - start) * 1000
            cold.close()
            plan = [r[3] for r in db.execute('EXPLAIN QUERY PLAN ' + sql, args)]
            timings, decoded = [], []
            for iteration in range(22):
                start = time.perf_counter()
                result = db.execute(sql, args).fetchall()
                elapsed = (time.perf_counter() - start) * 1000
                start = time.perf_counter()
                payloads = [json.loads(r[8]) for r in result]
                decoding = (time.perf_counter() - start) * 1000
                if iteration:
                    timings.append(elapsed)
                    decoded.append(decoding)
            assert cold_result == result
            assert len(result) == (min(pending, 5) if name == 'due' else pending)
            assert all(p['status'] == 'pending' for p in payloads)
            assert [p['scheduledAt'] for p in payloads] == sorted(p['scheduledAt'] for p in payloads)
            callbacks = [0]
            def progress():
                callbacks[0] += 1
                return 0
            db.set_progress_handler(progress, 100)
            db.execute(sql, args).fetchall()
            db.set_progress_handler(None, 0)
            report['measurements'].append({'historyRows': history, 'pendingRows': pending, 'query': name, 'returnedRows': len(result), 'serializedBytes': sum(len(r[8].encode()) for r in result), 'freshConnectionMs': round(cold_ms, 3), 'medianMs': round(statistics.median(timings), 3), 'p95Ms': round(sorted(timings)[19], 3), 'jsonDecodeMedianMs': round(statistics.median(decoded), 3), 'vmStepsRoundedDown100': callbacks[0] * 100, 'plan': plan})
    db.close()
scratch.cleanup()
print(json.dumps(report, indent=2))
```
