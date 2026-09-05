# Agent query follow-up — 2026-09-05

The original archive identified frequent agent reads but did not isolate native
SQLite time from executor queueing and transport. This experiment measures native
SQLite plus Python row materialization on synthetic data, independently of those
shared stalls. No profile database or log arguments are used.

## Result on the common case

Current state and report/soul-head updates normally overwrite stable ids. On a
fixture of 900 such agents, requesting 897 existing ids plus an absent id within
the production chunk cap, replacing window ranking with an indexed `NOT EXISTS`
newer-row check reduced warm native time from **4.176 to 3.030 ms** and first-read
time on a new SQLite connection from **5.285 to 3.708 ms**. Approximate VM work
fell from **82,500 to 46,800 instructions**. These are modest native-query gains,
not an end-to-end latency claim.

For the pending-wake variant where every latest row has cleared its wake, the
same fixture returned zero rows in **2.738 versus 1.365 ms** warm. The anti-join
always checks newer records independently of their wake fields, so an older
matching wake cannot be promoted when its newer record cleared it.

## Reproduce

Run `python3 tool/perf/agent_latest_queries.py` from the repository root. The
script creates and removes private temporary databases, loads the checked-in
agent entity table and indexes, extracts the current `latestEntitiesByAgentIds`
SQL from production, and compares it with the preceding window query. Output
includes plans, returned cardinalities, median timings and approximate SQLite VM
instruction counts. It fails if full result equality fails or if the current
multi-agent query exceeds 70% of the baseline VM instruction count. Python's
standard SQLite 3.45.1 was used on Linux ARM64.

There are 100 synthetic agents with 1, 100 or 500 records each, plus 900 agents
with one record each, containing 2,048 bytes of JSON padding. Scenarios request
one or many existing agents plus an absent agent, with/without subtype and
with/without an outer JSON predicate. Rows include equal creation times,
tombstones, and newer states that clear the predicate. Twelve paired runs
alternate variant order on the same connection. First-read measurements use
separate newly opened SQLite connections; OS page caches are not flushed.

| Records per agent | Requested existing agents | Window warm ms | Anti-join warm ms | Window cold connection ms | Anti-join cold connection ms |
|---|---:|---:|---:|---:|---:|
| 1 | 100 | 0.371 | 0.244 | 0.686 | 0.482 |
| 1 | 897 | 4.176 | 3.030 | 5.285 | 3.708 |
| 100 (stress) | 100 | 33.095 | 3.616 | 30.216 | 3.836 |
| 500 (stress) | 100 | 157.872 | 17.252 | 152.864 | 17.489 |

These are type-only cases without an outer predicate. The old query carries
all candidate payloads through a window. The replacement scans candidate index
entries and rejects a row if a greater `(created_at, id)` pair exists in the
same active agent/type[/subtype] partition. It does not hydrate non-winners for
the no-predicate variant. No migration, new index or cross-call cache is needed.

Work remains linear in the number of candidate records. At 100 versus 500
records per agent, the replacement executes approximately 239,400 versus
1,187,500 instructions: roughly five times the work for five times the records,
not quadratic growth. JSON outer predicates may be evaluated on historical
candidates before the indexed exclusion; the stress case with that predicate
costs 14.317 / 64.680 ms. The logical winner semantics remain identical.

The progress callback counts in units of 100; a reported zero for a tiny PK query
means fewer than 100 instructions, not no work. The VM-work budget is independent
of wall-clock load. Tests in `agent_repo_core_test.dart` additionally capture,
execute and explain the actual repository statement through real Drift to guard
indexed newer-row checks without a historical window scan. Compatibility tests
cover outer-filter rejection, ties, duplicate/missing ids, tombstones, chunk
boundaries, transaction read-your-writes and rollback. Those compatibility tests
are expected to pass before and after the performance change.

## Alternatives rejected

A correlated `LIMIT 1` seek per requested agent was dramatically faster on the
large-history stress case but regressed fresh-connection performance on the
normal one-row case: **4.605 to 5.721 ms**, with only a small warm gain
(**3.817 to 3.595 ms**) in that comparison run. Another in-memory run also found
a slight warm regression. It is not the shipped query.

Ranking only ids and hydrating winners afterward reduced large-payload cost,
but its common-case gains were smaller than the anti-join and one subtype
scenario regressed slightly. The selected anti-join improved both single-row
and aged fixtures across the tested subtype and outer-predicate cases.

## Other original query families

- **PK batch (shape 2):** one-row warm reads remain around 0.006 ms for all three
  ages, using the primary-key index. Already coalesced in the repository; this
  benchmark does not justify another cache or index.
- **Agent/type history (shape 1):** `LIMIT 1` stays near 0.016 ms through the
  existing ordered index. Unlimited reads return 1 / 91 / 455 live rows and cost
  approximately 0.015 / 0.141 / 0.698 ms. Their work grows with returned content.
  Current query providers bound previews to 50 or 200 messages; full chat
  projection, observation reads, prompt reconstruction and recommendation
  workflows also have intentionally unrestricted calls. Truncating those calls
  without changing their consumer contract would discard relevant history.
- **Agent/type/subtype (shape 21):** the one-row ordered lookup remains around
  0.016–0.017 ms through the existing subtype index.
- **Lifecycle identities (shape 4):** a separate fixture has 900 or 9,000 identity
  rows, 10% active, with the same payload padding. The current forced type index
  returns 90 or 900 rows in approximately 0.773 or 10.119 ms warm. This isolates
  real cardinality-dependent JSON filtering work, but does not establish those
  cardinalities, lifecycle selectivity or timings on the user's database.
  Goal consumers now share their identity provider. No new lifecycle cache or
  schema index is included without evidence that remaining calls justify it.
- **Latest-per-agent (shapes 5/15):** the measured fix above covers both subtype
  and type-only reads, with the outer predicate kept out of the newer-row check.

## Limits

Current state updates preserve state ids, and report/soul head writers reuse
`existingHead?.id` (`wake_output_writer.dart`, `event_agent_workflow.dart` and
`soul_version_ops.dart`). The one-row-per-agent fixtures are therefore the
relevant common case. The 100/500-row partitions are stress cases for multiple
records, not the expected growth model of these stable registers or a measured
cardinality from the log archive.

Python uses a different SQLite build from the app. Targeted Dart tests verify
SQL compatibility and behavior with the app's dependency. The experiment excludes
Dart JSON decoding, isolates, transaction contention, OS suspend/resume and I/O
stalls. It cannot explain the historical 13–15-second or 17-minute shared delays.
Post-fix logs and workload cardinalities remain necessary to measure the real
application effect and choose any further lifecycle or call-site optimization.
