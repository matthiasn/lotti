# Journal `due_at` Denormalized Indexed Column — Implementation Plan

Date: 2026-05-01
Status: Drafted (deferred — capture for future PR)
Related work:
- Slow-query investigation (this branch): rating prefetch removed, DailyOS off-screen prefetch gated off. Remaining hot path is `getTasksDueOn` / `getTasksDueOnOrBefore` running once per DailyOS navigation.
- `lib/database/database.dart:2509-2553` — existing JSON-extract pinned-index path with documented `SqliteException(1): no query solution` fallback.
- `lib/database/database.drift:82-88` — current `idx_journal_tasks_due_open` partial expression index.

## 0. Goals & Non-Goals

**Goals**
- Replace the `json_extract(serialized, '$.data.due')` expression-keyed partial index with a normal partial index over a real `due_at INTEGER` column on `journal`.
- Remove the planner-fragility that necessitates the pinned `INDEXED BY idx_journal_tasks_due_open` + JSON-fallback safety net in `_selectTasksDue`.
- Keep `serialized` as the source of truth; `due_at` is a denormalized convenience column populated on every upsert from the entity's `data.due`.

**Non-Goals (this PR)**
- No `estimate_us` column. The estimate query (`SELECT id, json_extract(serialized,'$.data.estimate')`) appears 24× in the slow log vs. 513× for due, and is not on the DailyOS navigation critical path. Track as a follow-up using the same recipe.
- No removal of `idx_journal_tasks_due_active` if any non-due-targeted query still relies on its `(type, deleted, json_extract(due))` shape — audit during implementation; if unused, drop.
- No change to the JSON payload in `serialized` — `data.due` stays exactly where it is. The DB column is purely a query-acceleration shadow.

## 1. Background

The slow-query log (`logs/desktop/slow_queries-2026-05-01.log`) shows
`getTasksDueOnOrBefore` / `getTasksDueOn` materializing as:

```sql
SELECT * FROM journal INDEXED BY idx_journal_tasks_due_open
WHERE type = 'Task' AND task = 1 AND deleted = FALSE
  AND task_status NOT IN ('DONE', 'REJECTED')
  AND json_extract(serialized, '$.data.due') IS NOT NULL
  AND json_extract(serialized, '$.data.due') <= ?1
  AND private IN (?2, ?3)
ORDER BY json_extract(serialized, '$.data.due') ASC
```

The query is well-formed against the existing partial expression index, but two
issues remain:

1. **Planner fragility.** The current code at `database.dart:2533-2553` documents
   `SqliteException(1): no query solution` observed on TestFlight — the planner
   sometimes refuses to prove the partial-index pin and the query falls back to
   an unpinned form, which then scans `journal`. A real column with a normal
   index cannot fail to apply.
2. **Per-row JSON parse cost.** Even when the index is used, `json_extract` is
   evaluated for every row that passes the prefix predicates (and again for the
   ORDER BY when SQLite can't reuse the indexed expression). With a real
   `due_at` column the planner can stream sorted from the index without
   touching `serialized` at all on the filter/sort path.

## 2. Schema Changes

`lib/database/database.drift`:

1. Add column to `journal`:
   ```sql
   due_at DATETIME,   -- denormalized from json_extract(serialized,'$.data.due'),
                      -- populated by toDbEntity on every upsert.
                      -- NULL when the task has no due date or the row is non-Task.
   ```

2. Replace the existing partial expression index:
   ```sql
   -- DROP: CREATE INDEX idx_journal_tasks_due_open ON journal(
   --   json_extract(serialized, '$.data.due') ASC
   -- ) WHERE type='Task' AND task=1 AND deleted=FALSE
   --   AND task_status NOT IN ('DONE','REJECTED');

   CREATE INDEX idx_journal_tasks_due_open ON journal(due_at ASC)
   WHERE type = 'Task'
     AND task = 1
     AND deleted = FALSE
     AND task_status NOT IN ('DONE', 'REJECTED');
   ```

3. Audit `idx_journal_tasks_due_active` (the non-partial composite at
   `database.drift:72-76`). If `getTasksSortedByDueDate` is its only consumer
   and we update that query to use `due_at`, drop it. If it still has callers,
   replace its `json_extract(serialized,'$.data.due')` segment with `due_at`.

## 3. Migration (v40 → v41)

Bump `schemaVersion` in `database.dart:113` from 40 to 41. Add a new branch in
`onUpgrade`:

```dart
if (from < 41) {
  await () async {
    DevLogger.log(
      name: 'JournalDb',
      message: 'Adding due_at column and re-creating tasks-due partial index',
    );

    // 1. Add the nullable column. Idempotent via column-existence check
    //    (mirrors the project_id / task_priority_rank migration shape).
    if (!await _columnExists('journal', 'due_at')) {
      await customStatement(
        'ALTER TABLE journal ADD COLUMN due_at DATETIME',
      );
    }

    // 2. Backfill from JSON for **every** task with a non-null `data.due`,
    //    regardless of status. Reasoning: the column drives more than just
    //    the open-task hot path — `getTasksSortedByDueDate` reads across
    //    all statuses, and range queries like "tasks due yesterday" must
    //    light up completed/rejected tasks too. Leaving closed tasks NULL
    //    would silently drop them from range scans and corrupt the sort
    //    order.
    //
    //    Encoding: `strftime('%s', ...)` returns Unix seconds as TEXT;
    //    `CAST(... AS INTEGER)` matches Drift's default DateTime mapping
    //    (`SqlTypes.mapToSqlVariable`: `millisecondsSinceEpoch ~/ 1000`).
    //    Do NOT use `datetime(...)` — that returns a TEXT string and
    //    corrupts the integer column.
    await customStatement(
      "UPDATE journal "
      "SET due_at = CAST(strftime('%s', "
      "  json_extract(serialized, '\$.data.due')) AS INTEGER) "
      "WHERE type = 'Task' AND task = 1 AND deleted = FALSE "
      "  AND json_extract(serialized, '\$.data.due') IS NOT NULL",
    );

    // 3. Drop the expression-keyed partial index and re-create on the column.
    await customStatement('DROP INDEX IF EXISTS idx_journal_tasks_due_open');
    await customStatement(
      'CREATE INDEX idx_journal_tasks_due_open ON journal(due_at ASC) '
      "WHERE type = 'Task' AND task = 1 AND deleted = FALSE "
      "AND task_status NOT IN ('DONE', 'REJECTED')",
    );
  }();
}
```

**Backfill scope decision.** All tasks with non-null `data.due` are
backfilled, not just the open-task subset. Two reasons:
1. `getTasksSortedByDueDate` (`database.dart:1453`) reads across every
   task status. Restricting the backfill to open tasks would corrupt sort
   order for legacy closed tasks until they were re-upserted.
2. The whole point of the column is fast range queries (e.g. "due
   yesterday across all statuses"). A range scan that silently skips
   completed/rejected tasks is worse than slow.

The backfill cost is bounded by the number of Task rows (a small fraction
of `journal`), so widening it is cheap. The partial *index* still covers
only open tasks — that's a separate decision driven by the index
footprint, not by data completeness in the column.

**Encoding decision.** Drift 2.30.0 stores DATETIME as **integer Unix
seconds** by default (verified in
`pub-cache/.../drift-2.30.0/lib/src/runtime/types/mapping.dart:72`:
`return dartValue.millisecondsSinceEpoch ~/ 1000;`). The migration must
produce the same integer encoding so reads through `Variable<DateTime>`
parse correctly. `strftime('%s', json_extract(...))` extracts ISO-8601
text from the JSON payload (which is what `DateTime.toIso8601String()`
writes) and converts it to a Unix-seconds *string*; `CAST(... AS
INTEGER)` lands it in the column as a real integer. Do **not** use
`datetime(...)` — that returns canonical TEXT and would corrupt the
column.

**Self-heal in `beforeOpen`.** The existing pattern at
`database.dart:130-137` self-heals `idx_journal_tasks_due_open` and
`idx_journal_task_status_private` on every open. Two updates required:
1. **Column self-heal (new).** Before any index work, check
   `_columnExists('journal', 'due_at')` and run
   `ALTER TABLE journal ADD COLUMN due_at DATETIME` when missing. Without
   this, a device that aborted v41 mid-migration would re-run the index
   self-heal against a non-existent column and crash. Backfill is *not*
   re-run from `beforeOpen` — the column starts empty and lazy-fills via
   `toDbEntity` as tasks are touched. (If we ever need a wider belt-and-
   braces, we could re-run the backfill UPDATE here too, gated on a
   PRAGMA `user_version`-style flag, but lazy fill is sufficient.)
2. **Index self-heal (update).** Update
   `_createIdxJournalTasksDueOpenSql` constant in `database.dart:33` to
   the new column-keyed form. The new SQL must be no-op when run twice
   (use `CREATE INDEX IF NOT EXISTS` through the existing
   `_asIfNotExists` helper).

**Pre-migration backup.** `onUpgrade` already calls `createDbBackup`
(`database.dart:148-163`). No extra work.

## 4. Write Path

`lib/database/conversions.dart` — extend `toDbEntity`:

```dart
final dueAt = entity.maybeMap(
  task: (task) => task.data.due,
  orElse: () => null,
);
```

Add `dueAt: dueAt` to the `JournalDbEntity(...)` constructor at line 54.

`upsertJournalDbEntity` at `database.dart:573-583` already calls
`insertOnConflictUpdate(entry)`, which writes every column including
`due_at`. No additional restore step is needed (unlike `project_id`, which
isn't in the JSON payload — `due` is).

## 5. Read Path

### 5.1 `_selectTasksDue` (`database.dart:2557-2602`)

Replace JSON extraction throughout. Variables become Drift `DateTime` —
Drift's default DateTime mapping serializes them to integer **Unix
seconds** (`millisecondsSinceEpoch ~/ 1000`), which is exactly what the
backfill writes:

```dart
String _buildSelectTasksDue({
  required DateTime endInclusive,
  required List<bool> privateStatuses,
  required List<Variable<Object>> variables,
  required String? indexedBy,
  DateTime? startInclusive,
}) {
  final buffer = StringBuffer()
    ..write('SELECT * FROM journal ')
    ..write(indexedBy != null ? 'INDEXED BY $indexedBy ' : '')
    ..write("WHERE type = 'Task' ")
    ..write('AND task = 1 ')
    ..write('AND deleted = FALSE ')
    ..write("AND task_status NOT IN ('DONE', 'REJECTED') ")
    ..write('AND due_at IS NOT NULL ');

  if (startInclusive != null) {
    variables.add(Variable<DateTime>(startInclusive));
    buffer.write('AND due_at >= ?${variables.length} ');
  }

  variables.add(Variable<DateTime>(endInclusive));
  buffer
    ..write('AND due_at <= ?${variables.length} ')
    ..write('AND private IN (');
  // ... (private placeholders unchanged) ...
  buffer
    ..write(') ')
    ..write('ORDER BY due_at ASC');

  return buffer.toString();
}
```

Update callers in `_selectTasksDue`'s wrapper to drop the `endIso`/`startIso`
ISO string conversions and pass `DateTime` straight through.

### 5.2 `getTasksSortedByDueDate` (`database.dart:1453-1456`)

Replace the dual-`json_extract` ORDER BY with:

```sql
ORDER BY CASE WHEN due_at IS NULL THEN 1 ELSE 0 END,
         due_at ASC,
         date_from DESC
```

This query reads tasks across all statuses (open, done, rejected). The
section-3 backfill is already widened to populate `due_at` for every task
with non-null `data.due`, so closed-task ordering works correctly from the
moment the migration completes — no re-upsert needed.

### 5.3 Fallback path

`database.dart:2533-2553` wraps the pinned query in a try/catch that falls
back to the unpinned form on `SqliteException(1)`. With a real column the
fallback is no longer expected to fire. **Keep the structure for one release
as belt-and-suspenders**, but log a warning when it does fire (so we notice
if the migration silently failed on some device).

## 6. Tests

### 6.1 Migration

Add `test/database/due_at_migration_test.dart` (mirror
`test/database/labels_migration_test.dart`):

- Open DB at v40, insert several Tasks with `data.due` set in JSON, mix of
  open/closed statuses (including DONE and REJECTED).
- Insert at least one Task with `data.due == null` to confirm the
  `IS NOT NULL` guard in the backfill.
- Insert at least one non-Task journal row to confirm the type filter
  leaves it untouched.
- Run migration to v41.
- Assert `due_at` column exists and equals the JSON `data.due` for **every**
  task with a non-null `data.due`, regardless of status — this is the
  cross-status sorting / range-query guarantee.
- Assert `due_at` is NULL for the no-due Task and for the non-Task row.
- Assert `idx_journal_tasks_due_open` exists, is partial (open-task-only),
  and is keyed on the `due_at` column (not the JSON expression).
- Run a query that should use the index and assert `EXPLAIN QUERY PLAN`
  shows `USING INDEX idx_journal_tasks_due_open`.

### 6.2 Round-trip

Add to existing conversion tests (find via
`test/database/database_test.dart`'s task-write coverage):

- Create a Task with `data.due` set, upsert, read back, assert
  `dbEntity.dueAt == task.data.due`.
- Update the task's `due` in the entity, upsert, assert `due_at` reflects
  the new value (no stale-column bugs).
- Clear `due` to null, upsert, assert `due_at` is NULL.

### 6.3 Coalescer regression

The microtask coalescer at `database.dart:2456-2490` is unchanged in shape.
Rerun `test/database/tasks_due_coalescing_test.dart` unmodified — it should
pass as-is once the `_selectTasksDue` signature is updated to accept
`DateTime` directly.

## 7. Rollout & Risk

**Risk: migration fails on a device.**
- Mitigated by `beforeOpen` self-heal (column add + index create are both
  idempotent via `IF NOT EXISTS` / `_columnExists`).
- Worst case: `due_at` is NULL on every row for that device. The pinned query
  returns no results. The fallback path (kept for one release) catches this
  and logs a warning, but the user sees no due-task results until the next
  upsert. Acceptable for a soft-fail mode; we'll know via logs.

**Risk: a closed task gets re-opened and its `due_at` is stale NULL.**
- The status change goes through `toDbEntity` → `upsertJournalDbEntity` →
  `insertOnConflictUpdate`, which rewrites every column including `due_at`
  from the live entity. Self-correcting on first mutation after re-open.

**Risk: someone reads `due_at` directly and gets stale data.**
- Don't expose `due_at` outside the database layer. UI continues to read
  `task.data.due` from the entity. The column is a query-acceleration
  shadow, not a UI source.

**Risk: query planner regression on some platforms.**
- After migration, run `EXPLAIN QUERY PLAN` against the hot query in tests
  and assert it uses the new index. Catches a planner picking a worse plan.

## 8. Out-of-Scope Follow-ups

- **`estimate_us`** column for `json_extract(serialized,'$.data.estimate')`
  (24 hits in slow log). Same recipe — extract from `task.data.estimate`,
  index partially, replace JSON read sites. Lower priority; tackle after
  `due_at` lands and we have a fresh slow-query baseline.
- **Project rollup index** — `lib/database/database.drift:99-103` already
  has `idx_journal_project_id` partial. Confirm the rollup query uses it
  via `EXPLAIN QUERY PLAN`; if not, the issue is the SUM(CASE) cardinality
  and a covering `(project_id, task_status)` partial would help.
- **Re-enable DailyOS off-screen prefetch** once the per-date query cost is
  low enough that warming 5 neighbors no longer saturates the read pool.
  Flag is at
  `lib/features/daily_os/ui/widgets/time_history_header/time_history_header_widget.dart:_prefetchEnabled`.

## 9. Implementation Checklist

- [ ] Bump `schemaVersion` to 41 in `database.dart:113`.
- [ ] Add `due_at DATETIME` column to `journal` in `database.drift`.
- [ ] Replace `idx_journal_tasks_due_open` definition in `database.drift`.
- [ ] Update `_createIdxJournalTasksDueOpenSql` constant in `database.dart:33`.
- [ ] Add v40→v41 migration branch with column-add, backfill (all tasks,
      `CAST(strftime('%s', ...) AS INTEGER)`), and index swap.
- [ ] In `beforeOpen`, ensure `journal.due_at` exists (`_columnExists` +
      `ALTER TABLE ... ADD COLUMN` when missing) **before** the existing
      index self-heal block so a partial-migration device recovers cleanly.
- [ ] Audit & update `idx_journal_tasks_due_active` if it's still consumed.
- [ ] Extend `toDbEntity` in `conversions.dart` with `dueAt`.
- [ ] Rewrite `_buildSelectTasksDue` to use `due_at` and `DateTime` variables.
- [ ] Rewrite `getTasksSortedByDueDate` ORDER BY to use `due_at`.
- [ ] Migration test (`test/database/due_at_migration_test.dart`).
- [ ] Round-trip column test in conversion tests.
- [ ] `EXPLAIN QUERY PLAN` assertion on the hot path.
- [ ] Rerun `tasks_due_coalescing_test.dart` unchanged.
- [ ] Update `database` and `daily_os` feature READMEs to describe the
      denormalized `due_at` column (architecture-first style).
- [ ] CHANGELOG entry under current `pubspec.yaml` version.
- [ ] `flatpak/com.matthiasn.lotti.metainfo.xml` entry alongside CHANGELOG.
