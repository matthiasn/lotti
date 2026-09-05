# Sync query follow-up

The remaining outbox and inbound-queue queries already have appropriate indexes.
The September log clusters do not establish that those SQL statements themselves
took seconds. This investigation found a separate source of avoidable demand:
the Matrix metrics panel guarded periodic polls, but its initial and manual
refreshes bypassed that guard. A held initial request admitted another periodic
request; three manual refreshes during a held poll admitted three more requests.
The panel now serializes all its metric loads, skips overlapping periodic ticks,
and preserves one trailing manual refresh. Finishing retry/rescan after the panel
is disposed cannot invalidate its providers or start another metrics load.

## Experiment

Run from the repository root:

```sh
python3 tool/benchmarks/sync_queue_queries.py > /tmp/sync-queue-benchmark.json
```

The [script](../../tool/benchmarks/sync_queue_queries.py) uses the exact
[fresh-install schema snapshot](fixtures/sync-v29.sql) from
`SyncDatabase(inMemoryDatabase: true)` at `d9a4f2a99`, schema 29. The snapshot was
exported through a temporary Dart MCP test using:

```dart
final rows = await db.customSelect(
  'SELECT sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type DESC, name',
).get();
```

The export omits only SQLite's automatic `sqlite_sequence` table declaration;
AUTOINCREMENT creates it. This is a fixed experiment fixture, not a maintained
migration schema. The script executes the production query shapes at that commit,
plus explicitly labeled comparison candidates. It does not read the app's files.

Measurements: Linux ARM64 VM, Python's SQLite 3.45.1 (not Flutter's bundled SQLite),
file-backed WAL databases, synchronous=NORMAL, one connection, warm reads, 21 timed
runs per statement after an untimed read. Each dataset is measured before and
after ANALYZE. Synthetic JSON payloads are approximately 1 KB. The history column
means that many sent outbox rows and that many applied inbound rows; the active
column means that many pending/sending outbox rows and that many inbound
active/abandoned rows. Outbox active rows split equally pending/sending, inbound
rows split equally enqueued/leased/retrying/abandoned, with three producers.
The small corpus has one room marker; aged corpora have 1,000.

Every timed read must equal its untimed result. Independent checks assert active
and applied counts and the exact IDs/order returned by the priority-first
pending batch. VM steps are measured separately with SQLite's progress handler;
its instrumentation overhead is excluded from timings. These are isolated
statement measurements, not app latency, production percentiles, or a reproduction
of the multi-second shared stalls. Warm caches, one connection, OS/filesystem,
SQLite version, and payload distribution limit generalization. Inserts are timed
inside a savepoint and exclude commit/fsync; they do not rule out storage latency.

## Results and decisions

Rounded median milliseconds after ANALYZE (the JSON report also has p95, before
ANALYZE results, query plans, and VM instruction counts):

| Retained rows | Active rows | Pending batch, limit 20 | Actionable count | Queue marker | Inbound depth | Applied count |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 100 | 0.030 | 0.004 | 0.003 | 0.020 | 0.002 |
| 100000 | 0 | 0.002 | 0.002 | 0.003 | 0.003 | 4.059 |
| 100000 | 100 | 0.029 | 0.004 | 0.003 | 0.020 | 4.049 |
| 100000 | 10000 | 0.031 | 0.186 | 0.003 | 0.757 | 4.110 |
| 100000 | 100000 | 0.031 | 2.697 | 0.003 | 9.312 | 4.132 |

- **Pending outbox, shape 6:** the status/priority/creation index satisfies
  filtering and ordering. A full 20-row result costs 330 VM steps regardless of
  the tested retained history or backlog size; there is no temporary sort.
  Keep the existing query and index.
  The claim transaction's companion query also checks expired sending leases.
  A 20-row expired result remains bounded (371 steps), but 50,000 unexpired
  sending rows take 250,012 steps and about 41 ms to establish there is no
  expired row. This is a synthetic stress boundary, not a backlog inferred
  from the logs: queued pending rows are not outstanding sending leases.
  Normal batches limit sending concurrency; the priority-first reclaim policy
  intentionally uses the existing ordering index. No new index is proposed
  without evidence of a substantial unexpired-sending population in practice.
- **Actionable count, shape 9:** the existing partial index scans the actionable
  subset, not the sent ledger. Its cost is linear in the number still queued
  (311 steps at 100 rows; 300,011 at 100,000). Removing the index hint changes to
  the existing covering status index and has similar step counts; microsecond
  differences at smaller backlogs do not justify a change. Large simultaneous
  backlogs still make repeated exact counts material.
- **Room marker, shape 11:** a primary-key seek costs 17 VM steps at both one and
  1,000 rooms. Another index would not address the observed shared waits.
- **Inbound aggregate, shape 12:** the existing status/producer/enqueued covering
  index needs no heap reads or temporary grouping sort. The current depth path
  already excludes applied history. With 100,000 retained rows and only 100
  active/abandoned rows it performs 1,445 steps; including applied history in
  the older aggregate would perform 1,201,501. Full `stats()` deliberately counts
  the applied ledger separately, costing 400,011 steps for 100,000 rows. Keep
  the bounded depth path and reduce duplicate full-statistics demand.
- **Outbox insert, shape 25:** statement medians inside the synthetic transaction
  were roughly 0.003 ms. All current indexes were present. No new insert-specific
  SQL change is supported; transaction, commit, scheduling, and storage behavior
  need separate diagnostics.
- **Pending existence candidate:** replacing a one-row full fetch with EXISTS
  reduced roughly 0.004 ms to 0.002 ms for this payload. This does not justify an
  extra accessor in this change. Much larger inline payloads would be a different
  workload and have not been validated by this experiment.

## Refresh amplification audit

The outbox badge and service use Drift's watched actionable count; sends can
invalidate it when rows change status even when the total count is unchanged.
Those reads still count only the active subset. The runner already debounces
its DB-driven nudges, and the query log alone cannot identify redundant emissions
or prove an unbounded refresh loop. No cache or invalidation shortcut was added.

The inbound depth emitter already shares an in-flight aggregate and retains one
rerun; transaction holds collapse batch mutations into one post-transaction
emission. The full metrics panel additionally reads the applied count. Its
five-second periodic guard did not cover initial loads or manual actions, which
is the reproduced amplification fixed here. Regressions use held futures and
fake widget time to assert query counts, the delivered latest metrics, retained
manual work after a null service response, and disposal safety. They fail with
the scheduling/disposal fixes reverted. The service catches normal metric
collection failures and returns null or retained queue values; the panel does
not introduce an automatic retry loop for backend failures.

The shared historical sync stalls remain unexplained by this benchmark. The
executor/transaction diagnostics investigation is separate; these measurements
support avoiding speculative indexes on already-bounded lookup paths.
