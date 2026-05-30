# Handoff: split `burned` out of `unresolvable` in the sync sequence log

**Status:** ready to implement · **Author:** investigation session 2026-05-30 · **Schema:** Drift v23 → v24

> **Executor note.** This doc is written to be run **autonomously in a VM where no
> approvals are required**. Do not ask questions — execute, verify, and iterate until
> the Definition of Done holds. You have full permission to edit files, regenerate
> generated code, run `fvm`/`make`, and run tests. `dart-mcp` is **not** wired in this
> environment; use `fvm` + `make` via the shell. Line numbers below were captured on
> 2026-05-30 and will drift as you edit — always re-anchor on the quoted symbol names
> and unique strings, never on the bare line number.

---

## 1. Problem & decision (the "why")

The sync sequence log (`sync_sequence_log`, one row per `(hostId, counter)`) tracks every
host's monotonic vector-clock counter so the recipient can detect gaps and backfill them.
A counter can legitimately carry **no payload** — it was reserved by
`VectorClockService` and released without a write, or superseded before being recorded
(rapid edits whose intermediate versions never persisted). That is a **vector-clock
counter burn**: a benign non-event, exactly like a *voided number in a monotonic invoice
sequence*. There is nothing to fetch.

Today every terminal "we will never get a payload here" outcome collapses into a single
status, `SyncSequenceStatus.unresolvable` (index **5**). But two semantically very
different things land there:

1. **Authoritative burn** — the originating host confirms its own counter is a non-event
   (proactive broadcast on release, or an own-host miss when answering a backfill
   request). *Clean, benign, terminal.*
2. **Receiver give-up** — a `missing`/`requested` row that never resolved after exhausting
   backfill retries (`retireExhaustedRequestedEntries`) or aging past the 7-day amnesty
   (`retireAgedOutRequestedEntries`). *We genuinely do not know what this was; it may be
   recoverable from a peer.*

The Backfill-sync settings screen shows a red **"Unresolvable: 674"** that is, per the
log evidence below, **~95% clean burns**. Operators read it as data loss; it mostly is not.

**Decision (locked with the requester):**

- **2-way split.** Add a new terminal status **`burned`** (the authoritative non-event).
  Keep `unresolvable` for receiver give-ups only. No third state.
- **`burned` is terminal.** A later backfill hint must NOT reopen a `burned` row (covering
  an own-host burn from a different entity is explicitly unsound — see
  `backfill_response_handler.dart:451-460`). `unresolvable` give-ups remain reopenable.
- **No wire-format change.** A backfill response with `unresolvable=true` is only ever
  sent by the originating host for its *own* counter (foreign-host requests get covering
  hints, never `unresolvable`). So the receiver maps **every incoming `unresolvable=true`
  → `burned`**. Old peers keep sending the same flag; new receivers classify it correctly.
  Backward/forward compatible.
- **Migration of the existing ~674 = re-ask peers (no new code).** On upgrade, legacy
  `unresolvable` rows stay `unresolvable` (their provenance was never stored). The existing
  **"Ask peers again for unresolvable"** action (`resetAllUnresolvable`) already flips
  `unresolvable` → `missing` and re-asks. Once the receiver path writes `burned`, re-asking
  **self-classifies**: authoritative `unresolvable=true` answers become `burned`; genuine
  losses retire back to `unresolvable`.

### Evidence (from `logs/desktop` + `logs/mobile`, 2026-05-28→30)

- `unresolvable=true` events: **354 distinct** counters (723 raw lines). Authoritative burn
  markers `sequence.ownUnresolvable` fire **369×**; receiver give-up sweeps
  (`retireExhaustedRequestedEntries`) only **20×** → burns dominate ~35:1.
- Watermark churn: a non-terminal row "blocks the contiguous-prefix watermark … causing
  every new event on the same host to re-emit the same gap range" (`sync_db.dart:1989`).
  `backfill.cooldownSkip` fires **839×** — the same counters re-requested until throttled.
  This is why **`burned` must count as resolved for the watermark** (Footgun #2).

---

## 2. Definition of Done (the autonomous stop condition)

All of the following must hold:

1. `make build_runner` has regenerated `lib/database/sync_db.g.dart` (the `@TableIndex.sql`
   change requires it). Generated files committed.
2. `make l10n` regenerated `app_localizations_*.dart`; `make sort_arb_files` clean.
3. `fvm dart format .` produces no diff.
4. `make analyze` reports **zero** warnings/infos for the whole project.
5. The full suite passes: `make test` (and the new Glados tests pass under
   `make test_glados`, correctly tagged `tags: 'glados'`).
6. **100% patch coverage** on every changed/added production line (verify with
   `make coverage` + inspect lcov for the touched files; add tests for any uncovered
   changed line).
7. Docs updated: `lib/features/sync/README.md` + `current_architecture.md` (with a Mermaid
   `stateDiagram-v2`), `CHANGELOG.md`, and `flatpak/com.matthiasn.lotti.metainfo.xml`.

---

## 3. Footguns — read before editing

1. **Append the enum value only; never reorder.** `SyncSequenceStatus` indices are
   persisted as integers in the DB and hardcoded as SQL literals and in migrations.
   `burned` MUST be index **8** (appended after `burnPending`).
2. **`burned` must be in the "resolved" set everywhere or churn returns.** There are
   **five** copies of the resolved set `(received=0, backfilled=3, deleted=4,
   unresolvable=5)`:
   - `_isResolvedSequenceStatusIndex` in `sync_db.dart` (~line 75)
   - `_isResolvedSequenceStatusIndex` in `sync_sequence_log_service.dart` (~line 106)
   - `@TableIndex.sql` `idx_sync_sequence_log_resolved_host_counter` (`sync_db.dart` ~227)
   - CTE in `_rebuildSequenceWatermarkForHost` (`sync_db.dart` ~1315)
   - CTE in `_advanceSequenceWatermarkForHost` (`sync_db.dart` ~1401)

   All five must gain `burned` (Dart: add the enum term; SQL: `IN (0, 3, 4, 5)` →
   `IN (0, 3, 4, 5, 8)`). **Strongly recommended: kill the duplication** by adding a single
   public source of truth (see Phase 1) and having both Dart predicates delegate to it.
3. **Do NOT edit the frozen v23 migration step** (`sync_db.dart` ~2704-2733, the
   `if (from < 23)` block that creates the index with `IN (0, 3, 4, 5)`). History is
   immutable; the new v24 step supersedes it.
4. **No wire-format change.** Do not add a `burned` field to `SyncMessage` /
   `SyncBackfillResponse`. The receiver derives `burned` from `unresolvable=true`.
5. **Drift schemaVersion ≠ app version.** Bumping `schemaVersion` 23→24 is internal and
   expected. Do **not** bump the app version (`pubspec.yaml`), and do **not** add a new
   `CHANGELOG`/flatpak release header — fold the CHANGELOG entry under the existing top
   version.
6. **Test rules** (`AGENTS.md`, `test/README.md`): no `DateTime.now()` in tests (use fixed
   dates e.g. `DateTime(2024, 3, 15)`); no `Future.delayed`/`sleep`/real `Timer` (use
   `fakeAsync`); no `// ignore:` to silence test failures; centralized mocks
   (`test/mocks/mocks.dart`) + fallbacks (`test/helpers/fallbacks.dart`); one test file per
   source file; Glados tests MUST carry `tags: 'glados'`.

---

## 4. Current shape (verified 2026-05-30)

```text
SyncSequenceStatus (lib/database/sync_db.dart:42-73)
  received(0) missing(1) requested(2) backfilled(3) deleted(4)
  unresolvable(5) reserved(6) burnPending(7)        ← append burned(8)

Resolved set = {received, backfilled, deleted, unresolvable}  (→ add burned)

Writers of unresolvable(5):
  AUTHORITATIVE BURN  → becomes burned(8)
    • sync_db.dart recordOwnUnresolvableSequenceCounter      (~1073, 1081, 1094, 1104)
    • sync_sequence_log_service.dart handleBackfillResponse, `if (unresolvable)` (~1255)
  RECEIVER GIVE-UP    → stays unresolvable(5) (NO CHANGE)
    • sync_db.dart retireExhaustedRequestedEntries           (~1964)
    • sync_db.dart retireAgedOutRequestedEntries             (~2031)

Stats model: lib/features/sync/tuning.dart
  BackfillHostStats (2-18), BackfillStats (21-59), getBackfillStats pivot
  in sync_db.dart (1713-1756).

UI: lib/features/sync/ui/backfill_settings_page.dart — "leader-dot ledger"
  rows at ~438-475 (Total/Received/Backfilled/Missing/Requested/Deleted/Unresolvable).

Migration: schemaVersion=23 (sync_db.dart:2302); steps in onUpgrade up to `from < 23`.
Migration tests assert `user_version == 23` in 13 places + `db.schemaVersion, 23`
  (sync_db_migration_test.dart:99,157,333,412,493,585,697,813,903,1025,1121,1177;
   sync_db_test.dart:5456).

Blast radius for SyncSequenceStatus in lib/: sync_db.dart, sync_sequence_log_service.dart,
  get_it.dart. NO exhaustive switch on it → appending compiles cleanly.
```

---

## 5. Implementation phases (do in order; keep analyzer green between phases)

### Phase 0 — preflight
- `git switch -c feat/burned-sequence-status` (work off `main`).
- `fvm flutter --version` to confirm FVM resolves; `make deps` if needed.

### Phase 1 — enum + single source of truth for "resolved"
`lib/database/sync_db.dart`:
- Append to `SyncSequenceStatus`:
  ```dart
    /// Authoritative non-event: the originating host confirmed this counter
    /// carries no payload — a vector-clock reservation released without a
    /// write, or a value superseded before being recorded. Terminal and
    /// benign, like a voided number in a monotonic invoice sequence: there is
    /// nothing to fetch. Reached on the originator via
    /// [recordOwnUnresolvableSequenceCounter] and on a peer when a backfill
    /// response carries `unresolvable=true` (the originator is authoritative
    /// for its own counters). Counts as resolved for the watermark so it never
    /// blocks the contiguous prefix. Distinct from [unresolvable].
    burned,
  ```
- Rewrite the `unresolvable` doc comment to describe the **give-up** meaning only
  (retry-exhausted / amnesty-aged), and cross-reference `[burned]`. Update the
  `burnPending` doc to say it upgrades to a **burned** broadcast.
- Add a public single-source-of-truth and route the predicate through it:
  ```dart
  extension SyncSequenceStatusX on SyncSequenceStatus {
    /// Terminal states that satisfy the contiguous-prefix watermark.
    bool get isResolved =>
        this == SyncSequenceStatus.received ||
        this == SyncSequenceStatus.backfilled ||
        this == SyncSequenceStatus.deleted ||
        this == SyncSequenceStatus.unresolvable ||
        this == SyncSequenceStatus.burned;
  }

  bool _isResolvedSequenceStatusIndex(int status) =>
      status >= 0 &&
      status < SyncSequenceStatus.values.length &&
      SyncSequenceStatus.values[status].isResolved;
  ```
- In `lib/features/sync/sequence/sync_sequence_log_service.dart` (~106) make
  `_isResolvedSequenceStatusIndex` delegate to the same extension (import it), or at
  minimum add `|| status == SyncSequenceStatus.burned.index`. Prefer delegation (DRY).

> `SyncSequenceStatusX.isResolved` is **pure** → primary Glados target (Phase 8).

### Phase 2 — retarget authoritative-burn writes to `burned`
`lib/database/sync_db.dart` → `recordOwnUnresolvableSequenceCounter` (~1049-1111):
- Change all four `SyncSequenceStatus.unresolvable.index` (~1073, 1081, 1094, 1104) to
  `SyncSequenceStatus.burned.index`. (1081 & 1104 are the `status:` arg passed to
  `_refreshSequenceWatermark` — keep them aligned with what is written.)
- Add `SyncSequenceStatus.burned.index` to the `isNotIn([...])` guard so an already-burned
  row is left untouched (makes a repeat burn idempotent; mirrors the terminal-skip guard in
  `handleBackfillResponse`).
- Update the docstring: it now writes `burned`.

`lib/features/sync/sequence/sync_sequence_log_service.dart` → `handleBackfillResponse`,
the `if (unresolvable)` branch (~1213-1265):
- Add `burned` to the "do not downgrade an existing terminal-success row" guard (~1231-1234)
  so an already-`burned` row is left alone:
  `existing.status == SyncSequenceStatus.burned.index` in the OR-set.
- Change the write at ~1255 `status: Value(SyncSequenceStatus.unresolvable.index)` →
  `SyncSequenceStatus.burned.index`. Update the `_trace` text/subDomain to read `burned`.
- In the **non-deleted hint** path further down (~1299-1335): add `burned` to the
  "Don't overwrite already received/backfilled/deleted" guard (~1300-1302) so a later hint
  **never reopens** a `burned` row (terminal). Leave the `unresolvable → requested` reopen
  (~1313, 1330) unchanged — give-ups stay reopenable.

> Naming: the methods `recordOwnUnresolvableSequenceCounter` /
> `markOwnCounterUnresolvable` / `enqueueOwnUnresolvableMarker` now produce `burned`.
> Renaming to `…Burned…` is encouraged for clarity but optional; if you rename, update
> every caller (`get_it.dart`, the service, and tests) in the same phase so the analyzer
> stays green.

### Phase 3 — stats model + query
`lib/features/sync/tuning.dart`:
- `BackfillHostStats`: add `required this.burnedCount` + `final int burnedCount;`.
- `BackfillStats`: add `totalBurned` to the constructor + `fromHostStats`
  (`totalBurned: stats.fold(0, (s, h) => s + h.burnedCount)`) + the field + include it in
  `totalEntries`.

`lib/database/sync_db.dart` → `getBackfillStats` (~1713-1756):
- Add `final burned = SyncSequenceStatus.burned.index;` and
  `burnedCount: perHost[host]![burned] ?? 0,` in the `BackfillHostStats(...)` construction.

> `BackfillStats.fromHostStats` is **pure** → Glados target (sum invariants).

### Phase 4 — schema migration (v24) for the resolved index
`lib/database/sync_db.dart`:
- Annotation `idx_sync_sequence_log_resolved_host_counter` (~227-230):
  `WHERE status IN (0, 3, 4, 5)` → `WHERE status IN (0, 3, 4, 5, 8)`. Update its doc comment
  to mention `burned`.
- CTE in `_rebuildSequenceWatermarkForHost` (~1315): `status IN (0, 3, 4, 5)` →
  `status IN (0, 3, 4, 5, 8)`.
- CTE in `_advanceSequenceWatermarkForHost` (~1401): same change.
- `schemaVersion` (~2302): `23` → `24`.
- Add a new step at the end of `onUpgrade`, after the `if (from < 23)` block:
  ```dart
  if (from < 24) {
    // burned(8) is a new terminal/resolved status. Rebuild the resolved
    // partial index so the watermark CTE can use it for burned rows (which
    // become the largest resolved bucket). Drop + recreate because the
    // partial WHERE changed.
    await customStatement(
      'DROP INDEX IF EXISTS idx_sync_sequence_log_resolved_host_counter',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS '
      'idx_sync_sequence_log_resolved_host_counter '
      'ON sync_sequence_log (host_id, counter) '
      'WHERE status IN (0, 3, 4, 5, 8)',
    );
    await customStatement('ANALYZE');
  }
  ```
- Run `make build_runner` to regenerate `sync_db.g.dart` (the annotation change must
  propagate to `onCreate`/`allSchemaEntities`). Commit the regenerated file.

### Phase 5 — get_it wiring (verify; behavioral change is downstream)
`lib/get_it.dart`:
- The proactive burn handler (`setBurnHandler`, ~481-512) and startup reconciliation
  (~519-566) call `enqueueOwnUnresolvableMarker`, which records the own counter via the
  service → `recordOwnUnresolvableSequenceCounter` (now writes `burned`) and enqueues the
  wire broadcast (`unresolvable=true`, unchanged). **No functional change required.**
- Read `enqueueOwnUnresolvableMarker` and confirm the local-record path flows through the
  now-`burned` DB method. If you did the optional rename in Phase 2, update names here.

### Phase 6 — UI: add the "Burned" row
`lib/features/sync/ui/backfill_settings_page.dart`:
- In the sync-statistics ledger (~438-475) add a **Burned** row. Mirror the existing
  `Deleted`/`Unresolvable` rows: `label: messages.backfillStatsBurned`,
  `value: stats.totalBurned`. **Tone: benign** — do NOT use the `error` tone that
  `unresolvable` uses when `> 0` (burns are not a problem); use the same low-emphasis tone
  as the other benign rows. Place it adjacent to `Unresolvable`.
- Update the docstring "leader-dot ledger of seven counts" → eight.
- No new recovery action needed — the existing "Ask peers again for unresolvable"
  (`resetAllUnresolvable`) is the migration affordance (Section 1).

### Phase 7 — l10n
- Add `"backfillStatsBurned"` to **every** ARB: `app_en.arb` (primary, "Burned"),
  `app_cs.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_ro.arb`. Use **informal**
  tone. Suggested user-facing labels (voided-counter sense; adjust if preferred):
  en `Burned`, de `Entwertet`, es `Anulado`, fr `Annulé`, ro `Anulat`, cs `Anulováno`.
  Add to `app_en_GB.arb` only if it differs from US English (it does not).
- Run `make l10n` then `make sort_arb_files`. Confirm `missing_translations.txt` has no new
  gaps for this key.

### Phase 8 — tests (Glados-first for pure logic; 100% patch coverage)
**Glados (tag `tags: 'glados'`):**
- `SyncSequenceStatusX.isResolved`: property over `any.choose(SyncSequenceStatus.values)`
  asserting `isResolved` is true exactly for {received, backfilled, deleted, unresolvable,
  burned} and false for {missing, requested, reserved, burnPending}. (Now that `isResolved`
  is public this is clean — see Phase 1.)
- `BackfillStats.fromHostStats`: generate `List<BackfillHostStats>` (per-field
  `any.positiveInt`-style generators), assert each `total*` equals the fold of the
  corresponding host field (including `totalBurned`), and `totalEntries` equals the sum of
  all seven totals. Cover the empty-list identity.

**Update existing tests:**
- `test/database/sync_db_migration_test.dart`: bump every `user_version` assertion
  `23 → 24` (13 sites) and `db.schemaVersion, 23 → 24` (line ~99). Add a **v23→v24** test:
  build a v23 DB (raw `sqlite3`, create the old index `WHERE status IN (0,3,4,5)`,
  `PRAGMA user_version = 23`), open via `SyncDatabase` to trigger v24, then assert via
  `SELECT sql FROM sqlite_master WHERE name='idx_sync_sequence_log_resolved_host_counter'`
  that the DDL now contains `8`. Also insert a contiguous run of resolved rows plus a
  `burned`(8) row and assert `getLastCounterForHost` advances past the burned counter.
- `test/database/sync_db_test.dart`: `db.schemaVersion` guard `23 → 24` (~5456); the
  `getBackfillStats` group — add `burned`(8) rows and assert `totalBurned` /
  per-host `burnedCount`, and that `totalUnresolvable` now **excludes** burned.
- `test/features/sync/sequence/sync_sequence_log_service_test.dart`: every
  `BackfillStats.fromHostStats([...])` / `BackfillHostStats(...)` now needs `burnedCount`;
  `handleBackfillResponse(..., unresolvable: true)` now yields `status == burned`;
  `markOwnCounterUnresolvable` / own-record now writes `burned`; add a test that a later
  hint does **not** reopen a `burned` row (terminal) but still reopens an `unresolvable`
  row (give-up).
- `test/features/sync/backfill/*`: the responder still *sends* `unresolvable=true`
  (own-host miss path unchanged) — confirm those assertions still pass; add/adjust a
  requester-side test that an incoming `unresolvable=true` is recorded as `burned`.
- `test/services/vector_clock_service_test.dart`: confirm burn logging unaffected; the
  status mapping is downstream of the VC service.
- Add a widget test (or extend the existing one) for `backfill_settings_page.dart`
  asserting the **Burned** row renders `totalBurned` and is not styled as an error.

**Coverage:** run `make coverage`; for each touched production file confirm every
changed/added line is hit. Add targeted tests for any gap. Target = 100% of the patch.

### Phase 9 — docs, CHANGELOG, flatpak
- `lib/features/sync/README.md` and `lib/features/sync/current_architecture.md`: document
  `burned` vs `unresolvable`; update the status table (it currently lists
  reserved/burn-pending/missing/requested/backfilled/deleted/unresolvable — add burned).
  Add/refresh a Mermaid `stateDiagram-v2` for the sequence-row lifecycle, e.g. reserved →
  burnPending → (broadcast) → **burned** (terminal) vs missing → requested →
  backfilled/deleted, and requested → (retry-exhausted / amnesty) → **unresolvable** →
  (re-ask) → missing. Only diagram states that actually exist in code.
- `CHANGELOG.md`: add a user-visible entry **under the existing top version** (read it from
  `pubspec.yaml`; do not add a new version header). Suggested:
  *"Backfill sync now distinguishes intentionally burned vector-clock counters (benign)
  from genuinely unresolvable entries, so the diagnostics no longer flag voided counters as
  data loss."*
- `flatpak/com.matthiasn.lotti.metainfo.xml`: mirror the CHANGELOG entry under the same
  existing release (these two files move together).

---

## 6. Verification command sequence (no dart-mcp; use fvm/make)

```bash
make build_runner          # MUST run after the @TableIndex.sql change (Phase 4)
make l10n                  # after Phase 7
make sort_arb_files
fvm dart format .
make analyze               # must be zero warnings/infos, whole project

# Targeted tests (fast feedback) — adjust paths as you go:
fvm flutter test \
  test/database/sync_db_test.dart \
  test/database/sync_db_migration_test.dart \
  test/features/sync/sequence/sync_sequence_log_service_test.dart \
  test/features/sync/backfill

make test_glados           # the new property tests (tagged 'glados')
make test                  # full suite before declaring done
make coverage              # confirm 100% patch coverage on changed lines
```

If `make build_runner` is slow or flaky, the underlying command is
`dart run build_runner build --delete-conflicting-outputs` under FVM (see `Makefile`).

---

## 7. What NOT to touch
- The frozen `if (from < 23)` migration block (and any earlier step).
- `SyncMessage` / `SyncBackfillResponse` wire shape.
- The retire sweeps (`retireExhaustedRequestedEntries`, `retireAgedOutRequestedEntries`) —
  they correctly keep writing `unresolvable`.
- The app version in `pubspec.yaml`; the CHANGELOG/flatpak release headers.
- Generated files by hand (`*.g.dart`, `*.freezed.dart`, `app_localizations_*.dart`) —
  regenerate them.

---

## 8. Rollback
The change is additive (new enum value + new index WHERE). To revert: drop the v24 step,
restore `schemaVersion = 23`, revert the five resolved-set sites and the write sites, and
re-run `make build_runner`. Existing `burned`(8) rows would then be treated as unresolved
by older code — so before a downgrade you would `UPDATE sync_sequence_log SET status = 5
WHERE status = 8`. (Not expected to be needed.)
