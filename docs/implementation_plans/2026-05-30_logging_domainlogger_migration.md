# Logging migration: `LoggingService` → enum-based `DomainLogger`

**Status:** in progress (core infrastructure landed; call-site + test migration pending)
**Owner:** logging
**Created:** 2026-05-30

## Goal

Replace direct use of `LoggingService` with `DomainLogger` everywhere, with a
**curated, type-safe set of logging domains** that can each be **toggled
individually in Settings**, plus a **single daily error log file** for the whole
app (`error-YYYY-MM-DD.log`) so errors are easy to inspect in one place.
Under normal operation that error file should stay empty.

## Design decisions

- **`LogDomain` enum** (new `lib/services/logging_domains.dart`) is the single
  source of truth for domains. Each value carries:
  - `flagName` — the config flag controlling it (`log_<snake>`). Names for
    `sync` / `agentRuntime` / `agentWorkflow` deliberately match the historical
    `log_sync` / `log_agent_runtime` / `log_agent_workflow` flags so existing
    user preferences survive.
  - `label` — English fallback (UI shows a localized label; see l10n step).
  - `defaultEnabled` — only relevant when the global logging flag is on.
  - `wireName` (== `name`) — the string written into log files / used as the
    per-domain file stem.
  - `routesToSyncFile` — only `sync` routes to the shared `sync-*.log`.
- **`DomainLogger` is the only logging entry point for app code.**
  `LoggingService` stays as the **low-level file sink** that `DomainLogger`
  owns; no feature code references `LoggingService` directly after migration.
- **Error logging is always on.** `DomainLogger.error(...)` logs regardless of
  whether the domain is enabled, and `LoggingService` mirrors every exception /
  error-level event into the shared daily `error-*.log`.
- **`DomainLogger.error` is error-first:** `error(LogDomain d, Object error,
  {StackTrace? stackTrace, String? subDomain, String? message})`. This maps
  cleanly from the old `captureException(exc, domain:, subDomain:, stackTrace:)`.
- **Granularity:** ~23 curated domains (consolidating ~70 ad-hoc strings). The
  original fine-grained string is preserved in the `subDomain` argument where it
  added information.

## Curated `LogDomain` set

`sync`(`log_sync`,default **off**), `ai`, `chat`, `speech`, `persistence`,
`database`, `agentRuntime`, `agentWorkflow`, `tasks`, `labels`, `health`,
`habits`, `location`, `screenshots`, `calendar`, `navigation`, `theming`,
`notifications`, `whatsNew`, `settings`, `ratings`, `dailyOs`, `general`.
All default **on** except `sync`. Errors always log regardless.

### Legacy domain string → `LogDomain` mapping (classifier)

First keyword match wins (uppercased substring). Source of truth for the
one-off migration; not shipped.

| Keyword(s) in old domain string | LogDomain |
|---|---|
| OUTBOX, MATRIX, SYNC, BACKFILL, VECTOR_CLOCK, ROOM, BRIDGE, DESCRIPTOR, ATTACHMENT, KEY_VERIFICATION, BOOTSTRAP, INBOUND, PENDING_DECRYPTION, SESSION_MANAGER, PROVISIONING, AGENT_SYNC, READ_MARKER | `sync` |
| AGENT_RUNTIME, WAKE, AGENT (non-sync) | `agentRuntime` |
| AGENT_WORKFLOW, SOUL, IMPROVER, FEEDBACK_EXTRACTION | `agentWorkflow` |
| CHATRECORDER, CHATSESSION, CHATMESSAGE, CHAT | `chat` |
| RECORDER, AUDIO, WAVEFORM, TRANSCRIPT, SPEECH, PLAYER, MLX, VOXTRAL | `speech` |
| UNIFIEDAI, PROMPT, INFERENCE, IMAGE(_ANALYSIS), MISTRAL, AI, GEMINI, OLLAMA, WHISPER, MODEL | `ai` |
| PERSISTENCE, JOURNAL, ENTRY, ENTITIES_CACHE, EDITOR | `persistence` |
| LOGGING_DB, APPDATABASE, MAINTENANCE, DATABASE, _DB, MIGRATION, PURGE | `database` |
| HEALTH, WORKOUT, STEPS | `health` |
| HABIT | `habits` |
| CHECKLIST, TASK | `tasks` |
| LABEL | `labels` |
| CALENDAR, TIME, POMODORO | `calendar` |
| TREND, DASHBOARD, MEASUR, CHART, INSIGHT, DAILY_OS, DAY_AGENT | `dailyOs` |
| LINK, DEEP_LINK, APPROUTER, NAVIGATION, ROUTER, NAV | `navigation` |
| SCREENSHOT, PORTAL | `screenshots` |
| LOCATION, GEO | `location` |
| NOTIFICATION | `notifications` |
| THEM | `theming` |
| RATING | `ratings` |
| WHATS_NEW | `whatsNew` |
| SETTING, CONFIG, FLAG, SERVICE_REGISTRATION | `settings` |
| WINDOW, MAIN, APP, STARTUP, (fallback) | `general` |

Known non-literal domain symbols (resolved explicitly during migration):
`LogDomains.sync→sync`, `LogDomains.ai→ai`, `LogDomains.agentRuntime→agentRuntime`,
`LogDomains.agentWorkflow→agentWorkflow`,
`AudioRecorderConstants.domainName→speech`, `AudioImportConstants.loggingDomain→speech`,
`ImageImportConstants.loggingDomain→ai`, `PortalConstants.portalServiceDomain→screenshots`,
`vectorClockLogDomain→sync`, `syncLoggingDomain→sync`, `screenshotDomain→screenshots`.

## Verified scope (snapshot)

- **70** distinct literal domain strings; **594** `captureEvent`/`captureException`
  calls in `lib/`.
- Receiver split in `lib/`: **129** calls via `getIt<LoggingService>()` (42 files);
  **~465** via injected fields (`_loggingService` ×287, `_logging` ×93,
  `loggingService` ×38, `logging` ×22, misc) across **64 files**.
- **103** lib files reference `LoggingService`; **59** already use `DomainLogger`.
- Tests: **176** files reference `LoggingService`, **163** inline-register it.
  Central mocks in `test/mocks/mocks.dart`: `MockLoggingService` (:376) +
  `stubLoggingService` (:411), `MockDomainLogger` (:433).

## Work already completed (on disk)

1. ✅ `lib/services/logging_domains.dart` — new `LogDomain` enum.
2. ✅ `lib/services/domain_logging.dart` — rewritten to the enum API
   (`log(LogDomain, msg, …)`, error-first `error(LogDomain, Object, …)`),
   `Set<LogDomain> enabledDomains`, `setEnabledDomains`, `isEnabled`; re-exports
   `LogDomain`. Old `LogDomains` string-constant class **removed**.
3. ✅ `lib/services/logging_service.dart` — added the shared daily error log
   (`error` stem): every exception and every error-level event is mirrored to
   `error-YYYY-MM-DD.log`; `syncFileDomains` reduced to `{'sync'}`.
4. ✅ `lib/database/journal_db/config_flags.dart` — seeds one flag per
   `LogDomain` via a loop over `LogDomain.values` (keeps `log_slow_queries`).
5. ✅ `lib/features/agents/state/agent_providers.dart` — `domainLogger` provider
   now wires **all** `LogDomain.values` from their flags (was 3 hard-coded).
6. ✅ `lib/features/settings/ui/pages/advanced/logging_settings_page.dart` —
   master toggle + slow-query toggle + one switch per `LogDomain`
   (currently uses `domain.label`; see l10n step).

> ⚠️ The repo does **not compile** in this intermediate state: changing the
> `DomainLogger` API + removing `LogDomains` breaks all existing call sites until
> the migration below is complete. This is expected — finish the migration to
> restore green.

## Remaining steps (with verification gates)

> After **every** phase: `dart analyze` (zero new errors) and the targeted
> tests for the touched area. Run `fvm dart format .` before each commit.

### Phase A — finish infra wiring
- A1. Remove now-unused `import 'package:lotti/utils/consts.dart';` from
  `agent_providers.dart` (only `configFlagProvider` remains, from another import).
- A2. Confirm `domainLoggerProvider` is **watched at app startup** independent of
  the agents flag, so `enabledDomains` is populated even when agents are off
  (move the wiring out of agent-only init if necessary, e.g. a small
  `loggingInitProvider`, or watch it from the existing top-level init).
- A3. Decide LoggingService visibility: it stays registered in `get_it.dart` (the
  sink) and is still flushed on shutdown + `listenToConfigFlag()`. Only its
  *direct call sites* go away.
- **Gate:** `dart analyze lib/services lib/database lib/features/agents/state lib/features/settings`.

### Phase B — migrate `getIt<LoggingService>()` call sites (129 calls / 42 files)
Mechanical and low-risk. For each call:
- `getIt<LoggingService>().captureEvent(msg, domain: D, subDomain: S, level: L, type: _)`
  → `getIt<DomainLogger>().log(LogDomain.<x>, msg, subDomain: S, level: L)` (drop `type`).
- `getIt<LoggingService>().captureException(exc, domain: D, subDomain: S, stackTrace: T, level: _, type: _)`
  → `getIt<DomainLogger>().error(LogDomain.<x>, exc, stackTrace: T, subDomain: S)`.
- Map `D` via the classifier; preserve original string in `subDomain` when it
  adds info. Fix imports (drop `logging_service.dart`, add `logging_domains.dart`
  or rely on the `DomainLogger` export).
- Use the migration script (see Tooling) in `apply` mode restricted to
  getIt receivers; it leaves everything else untouched.
- **Gate:** analyze the changed files; run a representative subset of their tests.

### Phase C — migrate injected-field call sites (~465 calls / 64 files)
This is a dependency-injection refactor. Standardize on **injecting
`DomainLogger`** (consistent with existing agent code):
- Per class: change the field/param type `LoggingService` → `DomainLogger`
  (rename to `_domainLogger`/`logger` for clarity), update its constructor, and
  convert `<field>.captureEvent/Exception(...)` → `<field>.log/error(...)` with
  the domain mapping.
- Update every construction site (providers in `lib/.../state`, `get_it.dart`,
  factories) to pass a `DomainLogger` (`getIt<DomainLogger>()` /
  `ref.watch(domainLoggerProvider)`) instead of a `LoggingService`.
- Do this **feature-by-feature** (sync, ai, speech, chat, persistence, …) so each
  batch can be analyzed + tested in isolation. Sync is the largest (~231 calls).
- **Gate per feature:** `dart analyze lib/features/<feature>` + that feature's tests.

### Phase D — tests (176 files)
- Replace central `MockLoggingService`/`stubLoggingService` usage with
  `MockDomainLogger`/a new `stubDomainLogger` in `test/mocks/mocks.dart`.
- Ensure `setUpTestGetIt()` registers `MockDomainLogger` (and keeps a
  `MockLoggingService` only if the sink is still constructed in tests).
- Update tests that constructed classes with a `LoggingService` to pass a
  `DomainLogger`. Update `verify(() => mock.captureEvent(...))` assertions to
  `verify(() => mock.log(LogDomain.x, ...))` / `.error(...)`.
- **Gate:** full `flutter test` (or `very_good test`) green.

### Phase E — localize domain labels (l10n)
- Add one key per domain (e.g. `loggingDomainSync`, `loggingDomainAi`, …) to all
  ARB files (`app_en`, `app_cs`, `app_de`, `app_es`, `app_fr`, `app_ro`;
  `app_en_GB` only if spelling differs). Informal tone per `AGENTS.md`.
- Swap `domain.label` in the settings page for a localized lookup
  (`_domainLabel(context, domain)` switch → `context.messages.loggingDomain…`).
- Remove now-unused `settingsLoggingAgentRuntime/Workflow/Sync` keys.
- Run `make l10n` and `make sort_arb_files`.
- **Gate:** `dart analyze`; settings page test.

### Phase F — cleanup & docs
- Remove the obsolete flag-name consts `logAgentRuntimeFlag`,
  `logAgentWorkflowFlag`, `logSyncFlag` from `lib/utils/consts.dart` once no test
  references remain (now derived from `LogDomain.flagName`).
- Confirm **no** `LoggingService` references remain outside
  `logging_service.dart`, `domain_logging.dart`, `get_it.dart`, and the test
  sink registration: `grep -rl 'LoggingService' lib | grep -v ...`.
- Update feature READMEs that describe logging; update
  `lib/services/README.md` (or create) describing the domain model + error log.
- CHANGELOG entry under the current `pubspec.yaml` version (user-visible:
  per-domain logging toggles + daily error log) and mirror in
  `flatpak/com.matthiasn.lotti.metainfo.xml`.
- Delete this plan’s scratch tooling; do not commit `/tmp` scripts.

## Tooling

A migration script (kept in `/tmp/migrate_logging.py` during the work; not
committed) performs the call-shape rewrite using a balanced-paren scanner +
top-level comma splitter so multi-line calls are handled safely. It:
- resolves the `domain:` argument (string literal, known constant, or in-file
  `const X = '…'`) to a `LogDomain` via the classifier;
- rewrites `captureEvent`→`log` and `captureException`→`error`, dropping `type:`
  and (for errors) `level:`;
- in `analyze` mode only counts and reports skipped/ambiguous calls
  (`/tmp/mig_report.txt`); in `apply` mode rewrites files;
- **leaves any call it cannot confidently transform unchanged** and records it
  for manual handling.

## Environment caveat (important for whoever executes this)

During the initial session the harness’s **tool-output display was
intermittently corrupted**: `Read` occasionally fabricated/duplicated lines and
`Bash` stdout was truncated/blanked in streaks (verified: a 5-line canary file
read back wrong; `grep -c` proved fabricated lines were not on disk). **Files on
disk were always correct** (confirmed via `md5sum`). If this recurs:
- Trust `Edit`/`Write` success messages and exit codes (they came through).
- Verify via single-line outputs (`grep -c`, `wc -l`, summaries piped to a file
  then read in small windows); re-run suspicious reads.
- Prefer a Python migration that edits files directly (immune to display
  corruption) and writes a report file.
- If output goes fully dark, **restart the Claude Code session** (a “fresh
  environment”) — it clears the display glitch. This plan + the project memory
  entry let work resume from exactly here.

## Rollback

All changes are additive/mechanical. To revert to the pre-migration state,
`git restore` the six files in “Work already completed”. The error-log addition
in `LoggingService` is independent and safe to keep on its own.
