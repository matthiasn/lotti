# ADR 0025: Insights Time-Analysis Data Layer

## Status

Accepted (2026-06-07)

## Context

The Daily OS tab gains a desktop-only Time Analysis dashboard
(`lib/features/insights/`, route `/calendar/time`) that must aggregate
10k+ time entries per category per day and switch between date ranges
(1d/7d/30d/MTD/YTD/last month/custom) in under 200ms. The codebase already
contains three divergent "time spent" computations (calendar query,
Daily OS time history, task progress union-merge), several latent traps
(`julianday()` on integer-epoch columns, `linked_entries` join fan-out),
and a hard product rule that background refreshes must never flash
established UI.

An adversarial design review of the initial plan surfaced two
would-be-shipping bugs — a `julianday()` duration filter that returns zero
rows against Drift's integer-seconds DateTime storage, and a LEFT JOIN on
`linked_entries` that double-counts any entry with multiple incoming
links — plus an inverted category-precedence rule and naive summing that
double-counts overlapping entries. This ADR records the corrected,
adopted design.

## Decision

1. **Slim SQL projection, aggregation in Dart.** One query
   (`JournalDb.insightsTimeRows`, mixin `_JournalDbInsightsQueries`)
   returns only `(date_from, date_to, resolved category)` for non-deleted
   `JournalEntry` rows overlapping the window — never the `serialized`
   JSON blob. Deserializing 10k `JournalEntity` payloads is what would
   blow the latency budget, not SQLite. All bucketing/aggregation lives in
   pure Dart (`logic/time_bucketing.dart`) where it is Glados
   property-tested.
2. **Integer-seconds arithmetic only.** `date_from`/`date_to` are Unix
   seconds (Drift default); `julianday()` on them returns NULL. Duration
   guards use plain column comparison (`date_to > date_from`).
3. **Fan-out-free category resolution, task-first precedence.** A
   correlated subquery picks at most one linked task per entry
   (`ORDER BY t.date_from DESC, t.id LIMIT 1`); the task's category wins
   over the entry's own, matching `actualTimeBlocksForEntries` and the
   unified Daily OS aggregation.
4. **What counts as time:** `JournalEntry` only; `JournalAudio` is
   excluded (recordings during a running timer double-count — the shipped
   Daily OS time-history rule). No 15-second floor: that legacy floor is a
   noise heuristic in `workEntriesInDateRange`, not a totals semantic.
5. **Union-merge per (day, category) cell** after DST-safe midnight
   splitting (calendar-constructor arithmetic, epoch-day int keys via UTC
   anchor). Property tests assert duration conservation and merge
   idempotence.
6. **Year-keyed window cache.** Buckets are served by a
   `StreamProvider.family` keyed on a `({startDay, endYear})` record —
   January 1st of the range-start year through the range-end year (the
   fetch end is capped at January 1st after `endYear`, so past-year
   custom ranges never load every year through today). Every preset
   within a year shares one in-memory cache, so range switching is a
   pure memory slice (measured:
   all six presets ~5ms on a 10k-entry year; cold fetch+bucketize ~35ms).
   A different year is a different provider instance — no mutable shared
   window, no stale-write races. Refetches ride
   `notificationDrivenItemStream` (serialized, coalesced) on the
   `TEXT_ENTRY`/`TASK`/`LINK_CHANGED`/`PRIVATE_FLAG_TOGGLED` tokens, with
   `cacheFor` keeping recent windows alive across tab switches.
7. **Deep value equality as the no-flash mechanism.** Models are
   hand-rolled immutables with deep equality (no codegen); an unchanged
   refetch produces an equal `InsightsDayBuckets`, Riverpod never
   re-notifies, the UI never rebuilds.
8. **URL as the single selection writer, full-screen surface.** The
   dashboard lives at `/calendar/time` under the Daily OS tab, pushed as
   a full-screen page by `CalendarLocation` (the set-time-blocks
   pattern) — deliberately not a split pane. `CalendarLocation` is the
   sole writer of `desktopShowTimeAnalysis`; the sidebar sub-entry
   beneath the Daily OS month calendar only reads it. (Originally
   embedded in the Insights/dashboards detail pane; moved per product
   feedback — the analytics surface gets the entire content area.)
9. **Visualization contract** (Stephen Few): stacked bars / pre-stacked
   cumulative area via fl_chart; hourly buckets for 1-day ranges, weekly
   above 120 days; max 6 series + slate "Other (+N)" distinct from the
   neutral-gray Uncategorized; chart fills are muted derivations of
   user-picked category colors (saturated originals only in swatches);
   no pies or donuts.

10. **Private visibility.** The query gates both the entry and the
    linked-task subquery on the global `private` config flag using the
    `COALESCE(private, FALSE) IN (FALSE, (SELECT status FROM config_flags
    WHERE name = 'private'))` idiom from `workEntriesInDateRange`; the
    buckets provider additionally subscribes to
    `privateToggleNotification`. (Found by post-release adversarial
    review: the first cut leaked private durations.)
11. **v43 category backfill.** The v21 migration added the denormalized
    `journal.category` column without backfilling, so pre-2024-07 rows
    could carry `''` while their JSON `meta.categoryId` held the real id —
    silently bucketed as "Uncategorized" by column readers. v43 backfills
    the column once from `json_extract(serialized, '$.meta.categoryId')`,
    which also corrects the Daily OS time-history header.
12. **Refetch throttling.** Notification-driven window refetches are
    throttled (5s trailing edge via `notificationDrivenItemStream`'s
    `refetchThrottle`, mirroring the time-history throttle): typing fires
    a batch every ~100ms, and each refetch costs a full window query
    (~35-130ms measured at 10k-50k entries).
13. **Link mutations notify.** Standalone link create/update/remove (and
    the sync apply path) now emit `linkNotification` alongside the
    affected ids; the buckets provider subscribes, so linking a time
    entry to a task refreshes attribution immediately. Previously only
    UUID tokens fired and the dashboard stayed stale until the next
    entity edit.
14. **Covering index.** `idx_journal_insights_time` (partial, on
    `type = 'JournalEntry' AND deleted = FALSE`, covering `date_from,
    date_to, category, private, id`) turns the inherently residual
    overlap scan into an index-only scan, keeping cold-fetch cost flat as
    lifetime history grows.

## Measured performance (50k entries / 36 months / 40 categories)

YTD cold fetch 56ms + bucketize 37ms; full 36-month custom range 131ms +
111ms (the only path over the 200ms budget, one-time per window); preset
switches ~10ms; page-build derivations 2.7ms (shared
`dailyTotals`/`rankedCategoryTotals` pass); deep equality ~16ms per
refetch emission (cheaper than the rebuild it prevents); retained window
≈6-10MB. Scaling note: only `date_from < end` can be index-bounded —
`date_to > start` is a residual filter, so the scan length grows with
lifetime entry count (~110ms extrapolated at 100k before the covering
index; decision 14 removes the per-row table fetches from that walk).

## Consequences

- The dashboard's totals can differ slightly from the Daily OS time
  history header, which attributes a midnight-crossing entry wholly to its
  start day and does not union-merge; this feature splits and merges. The
  divergence is deliberate and documented in the feature README.
- Focus-category preferences live in SettingsDb as JSON and are
  **local-only** (SettingsDb keys do not sync unless explicitly coded);
  syncing them would require a new `SyncMessage` variant.
- The eager year-wide fetch trades a single ~35ms query for zero-DB preset
  switching; custom ranges in earlier years cost one additional fetch and
  are cached for five minutes.
- `workEntriesInDateRange`'s broken `julianday()` filter is a separate
  pre-existing bug, deliberately not fixed here (different call sites,
  different semantics) — tracked for its own change.
