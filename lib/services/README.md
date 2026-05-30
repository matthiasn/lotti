# Logging

This directory hosts the app's structured-logging stack. There are three layers:

- **`LogDomain`** (`logging_domains.dart`) — the single source of truth for the
  curated set of logging domains.
- **`DomainLogger`** (`domain_logging.dart`) — the domain-aware logging entry
  point for app code.
- **`LoggingService`** (`logging_service.dart`) — the low-level, buffered file
  sink that `DomainLogger` owns.

## `LogDomain`

`LogDomain` is an enum with ~23 curated domains (consolidating the ~70 ad-hoc
domain strings used historically). Each value carries:

| Field | Meaning |
|---|---|
| `flagName` | The config flag controlling it (`log_<snake>`). `sync` / `agentRuntime` / `agentWorkflow` reuse the historical `log_sync` / `log_agent_runtime` / `log_agent_workflow` flags so existing user preferences survive. |
| `label` | English fallback label. The Settings UI shows a localized label (`loggingDomain*` ARB keys). |
| `defaultEnabled` | Whether the domain logs by default while the global logging flag is on. All default **on** except `sync`. |
| `routesToSyncFile` | Whether events route to the shared `sync-*.log`. Only `sync` does. |
| `wireName` (== `name`) | The string written into log files / used as the per-domain file stem. |

`initConfigFlags` (`database/journal_db/config_flags.dart`) seeds one config
flag per `LogDomain.values`. Settings → Advanced → Logging renders one toggle
per domain (plus the master logging switch and the slow-query switch).

## `DomainLogger`

`DomainLogger` is the only logging entry point for app code. It:

- gates info-level `log(LogDomain, msg, …)` calls on a per-domain enabled set
  (`enabledDomains`), populated from config flags by `domainLoggerProvider`;
- always logs `error(LogDomain, Object, {message, stackTrace, subDomain})` —
  errors are never silently swallowed;
- delegates to `LoggingService` for the general + per-domain files;
- writes a per-domain file at `{documentsDir}/logs/{domain}-YYYY-MM-DD.log`
  (`sync` routes to the shared `sync-*.log` instead).

`domainLoggerProvider` (in `features/agents/state/agent_providers.dart`) wires
each `LogDomain`'s config flag into `enabledDomains` via `ref.listen`, so toggling
a domain mutates the set in place without rebuilding dependents. It is watched at
app startup from `beamer_app.dart`, independent of the agents feature flag.

Callers must treat `log` messages as **telemetry, not content** — never include
task titles, notes, prompt text, model output, or other user-authored content.

## Error logs

Errors are mirrored into **two** daily files so they can be inspected in one
place (and shared safely):

- **`error-YYYY-MM-DD.log`** — owned by `LoggingService`. Every exception and
  every error-level event is mirrored here in **full** (raw message + stack).
- **`error-safe-YYYY-MM-DD.log`** — owned by `DomainLogger.error`. Records the
  error's **runtime type only** (never the raw exception string), so it is safe
  to share without leaking user-authored content.

Under normal operation both stay empty.

```mermaid
flowchart TD
  App["App code"] -->|"log(LogDomain, msg)"| DL[DomainLogger]
  App -->|"error(LogDomain, err)"| DL
  DL -->|"enabled?"| Gate{"domain in\nenabledDomains?"}
  Gate -- no --> Drop["(dropped: info only)"]
  Gate -- yes --> LS[LoggingService.captureEvent]
  DL -->|"always"| LSE[LoggingService.captureException]
  DL -->|"per-domain / sync file"| PD["{domain}-*.log / sync-*.log"]
  DL -->|"type-only"| SAFE["error-safe-*.log"]
  LS --> GEN["lotti-*.log (+ sync-*.log for sync)"]
  LS -->|"error level"| ERR["error-*.log (full)"]
  LSE --> GEN
  LSE --> ERR
```

## Migration status

`DomainLogger` is the standard going forward; all agent/sync/persistence code
that previously used the string-based `LogDomains` constants now uses the
`LogDomain` enum. A backlog of direct `LoggingService.captureEvent/Exception`
call sites in older feature code is being migrated to `DomainLogger`
incrementally — `LoggingService` remains a valid sink in the meantime. See
`docs/implementation_plans/2026-05-30_logging_domainlogger_migration.md`.
