# Transaction waits: evidence and remaining uncertainty

The September log review found unrelated, indexed queries completing after
similar multi-second or multi-minute waits. Their recorded duration wraps an
executor await. A clean query plan does not distinguish executor queueing,
isolate transport, SQLite execution, disk work, or application suspension.
The historical records do not establish which of these caused the stalls.

## Reproduced mechanism

The repository pins Drift 2.34.4. Its remote executor server waits for the
active transaction to finish before dispatching unrelated work on that
executor. Transaction creation is lazy: the opening await acquires that turn.
Application work between statements can therefore extend the wait even when
each statement uses an efficient index. Read pools can route reads elsewhere,
so transaction overlap is not sufficient evidence of blocking.

The regression named `native transaction delays an unrelated indexed read
until commit` in
[`slow_query_logging_test.dart`](../../test/database/slow_query_logging_test.dart)
reproduces the mechanism with real `NativeDatabase.memory()` execution:

1. Create a synthetic primary-key table and open a transaction.
2. Insert a row inside that transaction.
3. Start an unrelated primary-key read through the parent executor.
4. Yield a microtask and assert the read has not completed.
5. Commit, then assert the read returns the inserted row and its timing entry
   identifies the overlapping transaction.

This is a deterministic regression without timed sleeps. It demonstrates
executor serialization and diagnostic correlation, not historical causality,
disk contention, a production read pool, or a measured performance gain.

## Diagnostic change

The interceptor now observes transaction acquisition, completion, and lifetime
alongside queries. The authoritative field definitions, lifecycle, gate
behavior, and attribution limits are in
[persistence](../../knowledge/architecture/persistence.md#transaction-overlap).
Transaction origins are captured when the optional stack setting is enabled.
No SQL query, index, SQLite pragma, or transaction boundary changes here.

Diagnostics must preserve database behavior. A regression also reproduced a
reporter exception escaping after an acknowledged transaction opening. The
interceptor now contains reporter exceptions. Tests cover successful commit,
original SQL failures, failed commit followed by rollback, failed rollback,
nested transactions, repeated opening awaits, and disabling logging during a
transaction. Mutating transaction observation, safe reporting, origin capture,
and lifetime formatting separately makes the corresponding regressions fail.

## Next capture

With slow-query logging enabled before the workload, compare query timing
bounds with transaction opening and completion records in the same connection.
Keep lifetime spans separate from SQL counts and avoid double-counting records
duplicated in the super-slow file. An overlapping long transaction and its
origin identify a concrete path to investigate; absence of overlap does not
rule out an unobserved transaction or another kind of shared stall.

Exact native-versus-queue attribution still requires worker-side timing
correlated across Drift's isolate transport. Application lifecycle and disk
telemetry would be needed to distinguish suspension or storage stalls. These
measurements are not present in the original archive, so no claim is made that
the historical longest waits have been fixed or fully explained.
