# Test-Quality & Refactoring Review — Master Index

This is a **repo-wide review** of test quality and file-shape/refactoring opportunities.
It does **not** change any code — every entry below points to a `TEST_REVIEW.md` report that
records actionable, checkable opportunities for a later improvement phase.

Each report evaluates its scope on **five axes**, and records **every action item as a GitHub
markdown checklist (`- [ ]`)** so the later improvement phase can track completion:

1. **File size / shape** — impl + test files that are too long (hard target: none ≥ 1000 lines; prefer < ~500), with concrete split seams.
2. **Test quality** — weak assertions, smoke tests, mock-heavy/assertion-light, copy-paste permutations, non-DRY setup, fake-time / `pumpAndSettle` violations, inline mocks vs. centralized.
3. **Generative (Glados) testing** — pure logic lacking property-based coverage (repo already has ~395 Glados tests across 228 files; only genuine gaps are flagged).
4. **Coverage / missing-behavior gaps** — untested error paths, edge cases, weakly-asserted branches, files with no test.
5. **Test execution speed** — opportunities to make the suite faster (the full run takes ~5 min even on an M4 Max): needless `pumpAndSettle`/over-pumping, real I/O or real `Timer`/delays, heavy per-test container/DB rebuilds that could be shared, redundant widget rebuilds, excessive Glados `numRuns`, integration-style tests that could be unit tests, and in-suite contamination forcing defensive re-setup.

Status legend: ⏳ pending · 🔄 in progress · ✅ done

**Coverage:** every `lib/features/*` feature and every top-level `lib/` + `test/` area was reviewed.
**171 `TEST_REVIEW.md` reports** were written (per-subdir reports for the large features + a feature
index for each giant/large feature + this master index), containing **3,397 checkable action items**
(`- [ ]` GitHub task-list items: ~999 **[HIGH]**, ~1,381 **[MED]**, ~1,017 **[LOW]**). Each report is
itself a markdown checklist so completion can be tracked as the improvement work happens.

---

## Improvement-phase progress (HIGH items)

Items are tracked in-place: each addressed HIGH item is flipped from `- [ ]` to `- [x]` in its
report once the change is **verified** (analyzer clean + targeted tests green). Live count:
`grep -rhcE '^\s*- \[x\].*\[HIGH\]' $(find test -name 'TEST_REVIEW*.md')`.

Order of attack: (1) **additive** items first (new Glados / missing-test for pure public functions —
cannot break existing tests); (2) **test-only refactors** (mock centralization, fake-time,
`pumpAndSettle`→`pump`, one-file-per-source merges — verified per file); (3) **`lib/` file-splits**
last — these touch production code and need full-suite/CI verification beyond this VM, so they are
flagged for CI/human-reviewed PRs rather than done blind here.

Method: write-only subagents author additive tests in parallel (no flutter — avoids concurrent-build
OOM); the main thread verifies centrally (`dart fix` + `flutter analyze` + `flutter test`) before any
checkbox is flipped. Agents are forbidden from running any `pub`/build command (one early agent ran
`pub add` and was reverted).

**Status:** 100 / 1003 HIGH addressed & verified, plus ~100 bonus MED/LOW Glados/round-trip tests
and ~6 files of MED mock-centralization. This session: 24 new test files; 46 redundant test files
merged-away (one-file-per-source consolidations — **no tests lost**, all moved); 77 existing files
extended — every change analyzer-clean + targeted tests green; pubspec protected (dependency-tampering
attempts by agents caught & reverted).

Two whole HIGH categories are now essentially complete: **additive Glados/missing-test** and
**one-file-per-source merges**. The remaining ~906 are:
- **`lib/` file-splits (~245):** production refactors — need full-suite/CI (OOMs here) → CI-PRs.
- **In-place test refactors (~250):** mock-centralization, getIt→setUpTestGetIt, fake-time,
  `pumpAndSettle`→`pump` — modify existing tests; must be verified one file at a time (re-run),
  not safely mass-parallelized; ~1–3 verified/turn.
- **Private-fn / DB-/widget-coupled (~remainder):** need extraction (=a split) or infra harnesses.

**Remaining ~933 HIGH, by category (require different handling):**
- **`lib/` file-splits (~245):** production-code refactors. The project requires `make analyze` +
  `make test` green before merge; the full suite OOMs on this 3-core VM, so these must be done as
  **CI-verified, human-reviewed PRs** — not blind in this loop. Each report lists concrete split seams.
- **Test-only refactors (~350+):** mock centralization → `test/mocks/mocks.dart`, fake-time fixes,
  `pumpAndSettle`→`pump`, one-file-per-source merges. These modify existing tests; doable here but
  must be verified one file at a time (re-run the file) — slow, not safely mass-parallelizable.
- **Private-function / DB-/widget-coupled items:** need extraction (=a split) or infra harnesses.

The 3,397 `- [ ]` checklist items across these reports are the ready-made, prioritized backlog for
that PR work.

---

## Cross-cutting findings (the patterns that repeat everywhere)

These are the themes that recurred across nearly every area. Tackling them as repo-wide sweeps will
usually be higher-leverage than file-by-file fixes.

- [ ] **[HIGH] Oversized files — mirror-split impl + test together.** Many impl files exceed the
  1000-line hard target (`database.dart` 3602, `sync_db.dart` 2799, `my_daily_widgetbook.dart` 2850,
  `inference_provider_edit_page.dart` 2362, `task_agent_workflow.dart` 2134, `outbox_service.dart` 1961,
  `sync_sequence_log_service.dart` 1823, `day_agent_plan_service.dart` 1879, `day_timeline.dart` 1832,
  `agent_repository.dart` 1768, `design_system_task_filter_sheet.dart` 1567, …) and the largest test
  files reach 8642 (`database_test`), 7766 (`sync_db_test`), 7743 (`outbox_service_test`), 7412
  (`agent_repository_test`), 7306 (`unified_ai_inference_repository_test`). Each report gives concrete
  split seams.
- [ ] **[HIGH] `pumpAndSettle` overuse is the #1 test-speed lever.** Thousands of calls flagged
  (e.g. 313 across one tasks/ui group, ~200+ in sync UI, 171 in daily_os widgets, 114 in one ai-settings
  file). Most are on static/stateless widgets and should become bounded `tester.pump()` — also removes
  the 10s-default-timeout hang risk on never-settling animations.
- [ ] **[HIGH] Per-test DB / container / GetIt rebuilds → `setUpAll`/shared fixtures.** Biggest
  non-pumpAndSettle speed win: `database_test` opens a fresh seeded DB before each of ~219 tests,
  `sync_db_test` ~27, `agent_repository_test` ~199; Glados properties re-open in-memory DBs per run.
- [ ] **[HIGH] One-test-file-per-source-file violations.** Sources with 2–6 test files each:
  `image_import.dart` (×6), `label_assignment_processor.dart` (×6), `prompt_builder_helper.dart` (×4),
  `journal_page_controller.dart` (×3), plus many ×2 (`thinking_parser`, `room`/`sync_room_manager`,
  `modern_create_entry_items`, `ai_config_repository`, …). Consolidate.
- [ ] **[MED] Inline mocks + inline GetIt boilerplate.** Pervasive inline `class Mock… extends Mock`
  duplicating `test/mocks/mocks.dart`, and hand-rolled `getIt.isRegistered/unregister/registerSingleton`
  instead of `setUpTestGetIt()`/`tearDownTestGetIt()`. Both a DRY and an in-suite-contamination concern.
- [ ] **[MED] Fake-time-policy violations.** Real `Future.delayed`/`sleep`/`Timer`/wall-clock
  `.timeout()` in tests (logging_service ~1s, sync actor ×14 `Future.delayed(Duration.zero)`, real
  poll-interval waits in day-agent tests, …). Convert to `fakeAsync` / the retry-fake-time helpers.
- [ ] **[MED] Glados generative gaps.** ~250+ genuine candidates: domain-entity JSON round-trips
  (`lib/classes/`), stream/SSE parsers & token accumulators (ai repos), comparator/sequence/coalescing
  invariants (sync, database), geohash/duration/format utils, lane-assignment & timeline math (daily_os),
  version comparison (whats_new). `VectorClock.merge`/`mergeUniqueClocks` are untested pure logic, and
  `vector_clock_glados_test.dart` is missing `tags: 'glados'` (running in the wrong CI shard).
- [ ] **[MED] Glados `numRuns` tuning.** Several properties run >200 (up to 300) on pure functions;
  trimming toward the README's ≤120–180 guidance recovers a meaningful slice of the ~3,280-run Glados
  budget with negligible coverage loss.
- [ ] **[LOW] Weak / smoke-only tests.** `findsOneWidget`-only, `isNotNull`, and constructor smoke
  tests concentrated in widget/design-system layers — upgrade to behavioral assertions.
- [ ] **[LOW] Completely untested production code.** e.g. `agent_list_toolbar.dart`,
  `checkbox_visibility_provider.dart`, `category_color.dart`, `get_it.dart` `registerSingletons`,
  several `design_system/components/lists/` widgets, `task_browse_row_interactions.dart`.

---

## Giant features (per-subdir reports + feature index)

### agents
| Unit | Scope | Report | Status |
|------|-------|--------|--------|
| U01 | agents/database | test/features/agents/database/TEST_REVIEW.md | ✅ |
| U02 | agents/service | test/features/agents/service/TEST_REVIEW.md | ✅ |
| U03 | agents/state + agents/sync | test/features/agents/state/ + sync/TEST_REVIEW.md | ✅ |
| U04 | agents/tools + agents/util | test/features/agents/tools/TEST_REVIEW.md | ✅ |
| U05 | agents/wake + agents/projection | test/features/agents/wake/ + projection/TEST_REVIEW.md | ✅ |
| U06 | agents/workflow (group A) | test/features/agents/workflow/TEST_REVIEW.md | ✅ |
| U07 | agents/workflow (group B) | test/features/agents/workflow/TEST_REVIEW.part2.md | ✅ |
| U08 | agents/genui + model + test_data | test/features/agents/genui/ + model/TEST_REVIEW.md | ✅ |
| U09 | agents/ui/evolution | test/features/agents/ui/evolution/TEST_REVIEW.md | ✅ |
| U10 | agents/ui (root files) | test/features/agents/ui/TEST_REVIEW.md | ✅ |
| U11 | agents/ui (small subdirs) | per-subdir TEST_REVIEW.md | ✅ |
| — | **agents feature index** | test/features/agents/TEST_REVIEW.md | ✅ |

### ai
| Unit | Scope | Report | Status |
|------|-------|--------|--------|
| U12 | ai/repository (group A: inference repos) | test/features/ai/repository/TEST_REVIEW.md | ✅ |
| U13 | ai/repository (group B: input/other) | test/features/ai/repository/TEST_REVIEW.part2.md | ✅ |
| U14 | ai/ui/settings (group A: pages) | test/features/ai/ui/settings/TEST_REVIEW.md | ✅ |
| U15 | ai/ui/settings (group B: provider/services/widgets) | test/features/ai/ui/settings/TEST_REVIEW.part2.md | ✅ |
| U16 | ai/ui (root + animation + image_generation + widgets) | test/features/ai/ui/TEST_REVIEW.md + per-subdir | ✅ |
| U17 | ai/state | test/features/ai/state/TEST_REVIEW.md | ✅ |
| U18 | ai/helpers + ai/functions | per-subdir TEST_REVIEW.md | ✅ |
| U19 | ai/services + ai/service | per-subdir TEST_REVIEW.md | ✅ |
| U20 | ai/util + ai/conversation | per-subdir TEST_REVIEW.md | ✅ |
| U21 | ai/database + model + {constants,providers,skills,utils,widgetbook} | per-subdir TEST_REVIEW.md | ✅ |
| — | **ai feature index** | test/features/ai/TEST_REVIEW.md | ✅ |

### sync
| Unit | Scope | Report | Status |
|------|-------|--------|--------|
| U22 | sync/matrix (group A: sender/service/processor) | test/features/sync/matrix/TEST_REVIEW.md | ✅ |
| U23 | sync/matrix (group B: loaders/discovery/rest) | test/features/sync/matrix/TEST_REVIEW.part2.md | ✅ |
| U24 | sync/matrix/pipeline + matrix/utils + db | test/features/sync/matrix/pipeline/TEST_REVIEW.md | ✅ |
| U25 | sync/outbox | test/features/sync/outbox/TEST_REVIEW.md | ✅ |
| U26 | sync/queue | test/features/sync/queue/TEST_REVIEW.md | ✅ |
| U27 | sync/ui (all) | test/features/sync/ui/TEST_REVIEW.md | ✅ |
| U28 | sync/backfill + sync/sequence | per-subdir TEST_REVIEW.md | ✅ |
| U29 | sync/actor + sync/state | per-subdir TEST_REVIEW.md | ✅ |
| U30 | sync/{gateway,model,models,repository,services} + root | per-subdir TEST_REVIEW.md | ✅ |
| — | **sync feature index** | test/features/sync/TEST_REVIEW.md | ✅ |

---

## Large features (per-subdir reports + feature index)

### tasks
| Unit | Scope | Report | Status |
|------|-------|--------|--------|
| U31 | tasks/ui {root,checklists,widgets} | per-subdir TEST_REVIEW.md | ✅ |
| U32 | tasks/ui {filtering,header,labels,linked_tasks,model,pages,saved_filters} | per-subdir TEST_REVIEW.md | ✅ |
| U33 | tasks/state | test/features/tasks/state/TEST_REVIEW.md | ✅ |
| U34 | tasks/{repository,services,util,widgetbook} + root | per-subdir TEST_REVIEW.md | ✅ |
| — | **tasks feature index** | test/features/tasks/TEST_REVIEW.md | ✅ |

### journal
| Unit | Scope | Report | Status |
|------|-------|--------|--------|
| U35 | journal/ui/widgets (group A: entry_details + root) | test/features/journal/ui/widgets/TEST_REVIEW.md | ✅ |
| U36 | journal/ui/widgets (group B: create,editor,list_cards) | per-subdir TEST_REVIEW.md | ✅ |
| U37 | journal/ui {pages,mixins} + root | test/features/journal/ui/TEST_REVIEW.md | ✅ |
| U38 | journal/state | test/features/journal/state/TEST_REVIEW.md | ✅ |
| U39 | journal/repository | test/features/journal/repository/TEST_REVIEW.md | ✅ |
| — | **journal feature index** | test/features/journal/TEST_REVIEW.md | ✅ |

### daily_os / daily_os_next
| Unit | Scope | Report | Status |
|------|-------|--------|--------|
| U40 | daily_os/ui/widgets | test/features/daily_os/ui/widgets/TEST_REVIEW.md | ✅ |
| U41 | daily_os/ui {pages} + util + repository + widgetbook | per-subdir TEST_REVIEW.md | ✅ |
| U42 | daily_os/state | test/features/daily_os/state/TEST_REVIEW.md | ✅ |
| U43 | daily_os_next/agents | per-subdir TEST_REVIEW.md (service/workflow/domain/state/tools) | ✅ |
| U44 | daily_os_next/ui | test/features/daily_os_next/ui/{,pages,widgets}/TEST_REVIEW.md | ✅ |
| U45 | daily_os_next/state + logic | per-subdir TEST_REVIEW.md | ✅ |
| — | **daily_os + daily_os_next feature indexes** | test/features/daily_os{,_next}/TEST_REVIEW.md | ✅ |

### design_system / projects / ai_chat
| Unit | Scope | Report | Status |
|------|-------|--------|--------|
| U46 | design_system/components (group A) | test/features/design_system/components/TEST_REVIEW.md | ✅ |
| U47 | design_system/components (group B) | test/features/design_system/components/TEST_REVIEW.part2.md | ✅ |
| U48 | design_system/{widgetbook,state,theme,utils} | per-subdir TEST_REVIEW.md | ✅ |
| U49 | projects/ui/widgets | test/features/projects/ui/widgets/TEST_REVIEW.md | ✅ |
| U50 | projects/ui {pages,model} + state + repository | per-subdir TEST_REVIEW.md | ✅ |
| U51 | ai_chat/ui {controllers,widgets,models,pages,providers} | per-subdir TEST_REVIEW.md | ✅ |
| U52 | ai_chat/{repository,services,database,models} | per-subdir TEST_REVIEW.md | ✅ |
| — | **design_system / projects / ai_chat feature indexes** | feature TEST_REVIEW.md | ✅ |

---

## Medium / small features (single feature report each)
| Unit | Scope | Report | Status |
|------|-------|--------|--------|
| U53 | speech | test/features/speech/TEST_REVIEW.md (+ per-subdir) | ✅ |
| U54 | categories + labels | test/features/{categories,labels}/TEST_REVIEW.md | ✅ |
| U55 | settings + settings_v2 | test/features/{settings,settings_v2}/TEST_REVIEW.md | ✅ |
| U56 | dashboards + habits | test/features/{dashboards,habits}/TEST_REVIEW.md | ✅ |
| U57 | ratings + notifications + whats_new | test/features/{ratings,notifications,whats_new}/TEST_REVIEW.md | ✅ |
| U58 | surveys + checklist + theming + user_activity | test/features/{...}/TEST_REVIEW.md | ✅ |

---

## Top-level areas
| Unit | Scope | Report | Status |
|------|-------|--------|--------|
| U59 | test/database (group A: database/maintenance/migrations) | test/database/TEST_REVIEW.md | ✅ |
| U60 | test/database (group B: sync_db + rest) | test/database/TEST_REVIEW.part2.md | ✅ |
| U61 | test/logic | test/logic/TEST_REVIEW.md | ✅ |
| U62 | test/services | test/services/TEST_REVIEW.md | ✅ |
| U63 | test/widgets (group A) | test/widgets/TEST_REVIEW.md | ✅ |
| U64 | test/widgets (group B) | test/widgets/TEST_REVIEW.part2.md | ✅ |
| U65 | test/utils | test/utils/TEST_REVIEW.md | ✅ |
| U66 | test/classes | test/classes/TEST_REVIEW.md | ✅ |
| U67 | test/beamer | test/beamer/TEST_REVIEW.md | ✅ |
| U68 | test/{themes,pages,map,providers,ui,widgetbook} + root test files | per-area TEST_REVIEW.md | ✅ |

---

_Generated by an automated, multi-agent test-quality review (static analysis only — no code changed)._
