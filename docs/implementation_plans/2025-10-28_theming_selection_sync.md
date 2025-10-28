# Theming Selection Sync — Light/Dark Scheme Pair + ThemeMode

## Summary

- Add a new sync message type that conveys the currently selected light and dark FlexColor scheme names and the selected `ThemeMode` (system/dark/light) as a single atomic payload.
- Emit this message whenever the user changes either light or dark theme or the ThemeMode in Settings → Theming.
- On receipt, persist both scheme names and the ThemeMode to `SettingsDb` using the same keys/settings path as local selection, so the remote device mirrors the choice immediately.
- Keep behavior idempotent and safe: receiving the message should not re‑emit another message (no
  ping‑pong), and unknown themes should fall back to a default scheme locally without failing the
  pipeline.

## Current Behavior (grounded)

- Theme preferences are selected in the Theming page and stored in `SettingsDb` via ThemingCubit:
  - Keys: `lightSchemeNameKey`, `darkSchemeNameKey`, and `themeModeKey` are defined in
    `lib/blocs/theming/theming_cubit.dart:17`–`lib/blocs/theming/theming_cubit.dart:19`.
  - Load/apply and persist on selection: `lib/blocs/theming/theming_cubit.dart:40`–
    `lib/blocs/theming/theming_cubit.dart:54`, `lib/blocs/theming/theming_cubit.dart:97`–
    `lib/blocs/theming/theming_cubit.dart:120`, `lib/blocs/theming/theming_cubit.dart:122`–
    `lib/blocs/theming/theming_cubit.dart:150`.
  - Theming UI: `lib/features/settings/ui/pages/theming_page.dart:50`–
    `lib/features/settings/ui/pages/theming_page.dart:107` (segmented ThemeMode, light/dark
    pickers).
- Sync message envelope and processing:
  - Freezed union for message types: `lib/features/sync/model/sync_message.dart:12`–
    `lib/features/sync/model/sync_message.dart:46`.
  - Outbox enqueues messages and subjects per variant:
    `lib/features/sync/outbox/outbox_service.dart:86`–
    `lib/features/sync/outbox/outbox_service.dart:259`.
  - Matrix sender encodes payloads as base64 JSON under msgtype `com.lotti.sync.message`:
    `lib/features/sync/matrix/matrix_message_sender.dart:104`–
    `lib/features/sync/matrix/matrix_message_sender.dart:133`.
  - Receiver decodes and applies payloads in `SyncEventProcessor.process()` and
    `_handleMessage(...)`: `lib/features/sync/matrix/sync_event_processor.dart:503`–
    `lib/features/sync/matrix/sync_event_processor.dart:548` and
    `lib/features/sync/matrix/sync_event_processor.dart:567`–
    `lib/features/sync/matrix/sync_event_processor.dart:705`.

## Problem

- Theme selections for light/dark schemes are local‑only. Users expect their preferred light and
  dark color schemes to stay in sync across devices. There is no message variant to propagate this
  preference.

## Goals

- Add a dedicated, atomic theming selection message that carries both light and dark scheme names and the ThemeMode.
- Emit on local selection change, ingest on remote, persist to `SettingsDb` using the exact same keys (including ThemeMode).
- Keep the change modular, small, and testable (unit + widget + processor tests).

## Non‑Goals

- Reworking theming UI/UX or color system.

## Design Overview

- New message variant: `SyncMessage.themingSelection(lightThemeName, darkThemeName, themeMode, updatedAt, status)`.
  - Send with `status = update` to indicate preference updates.
  - Treat the payload as last‑write‑wins; no vector clock.
- Add `updatedAt` (milliseconds since epoch, UTC) for deterministic tie‑breaking when multiple devices update around the same time.
- Emit on `setLightTheme(...)`, `setDarkTheme(...)`, and `onThemeSelectionChanged(...)` so each change publishes the full triple to avoid partial divergence.
- Receive in `SyncEventProcessor` and persist via `SettingsDb.saveSettingsItem(...)` using the same keys as ThemingCubit to ensure UI rebuilds reflect the new choices after state reloads.
- Keys will live in `lib/features/settings/constants/theming_settings_keys.dart` to avoid cross‑importing UI code into sync paths and to match existing `features/*/constants` patterns.

## Changes by Component

- Sync models
  - Add union variant to `lib/features/sync/model/sync_message.dart`:
    - `const factory SyncMessage.themingSelection({ required String lightThemeName, required String darkThemeName, required String themeMode, required int updatedAt, required SyncEntryStatus status, }) = SyncThemingSelection;`
    - Run codegen to update `*.g.dart` and `*.freezed.dart`.

- Shared theming keys
  - Extract keys to a constants file for reuse across ThemingCubit and the sync processor:
    - New: `lib/features/settings/constants/theming_settings_keys.dart` with:
      - `const lightSchemeNameKey = 'LIGHT_SCHEME';`
      - `const darkSchemeNameKey = 'DARK_SCHEMA';` (keep existing spelling)
      - `const darkSchemeNameKeyAlias = 'DARK_SCHEME';` (read‑compat alias only)
      - `const themeModeKey = 'THEME_MODE';`
      - `const themePrefsUpdatedAtKey = 'THEME_PREFS_UPDATED_AT';`
    - Update `lib/blocs/theming/theming_cubit.dart` to import these instead of duplicating.

- Outbox emission
  - In `lib/blocs/theming/theming_cubit.dart`, after saving locally in `setLightTheme(...)`,
    `setDarkTheme(...)`, and `onThemeSelectionChanged(...)`, enqueue the new message via Outbox:
    - Build the triple `{ lightThemeName: _lightThemeName!, darkThemeName: _darkThemeName!, themeMode: _themeMode.name }` with `updatedAt = DateTime.now().millisecondsSinceEpoch` (using the updated in‑memory values).
    - `await getIt<OutboxService>().enqueueMessage(SyncMessage.themingSelection(lightThemeName: ..., darkThemeName: ..., themeMode: ..., updatedAt: ..., status: SyncEntryStatus.update));`
    - Keep this best‑effort (do not crash UI on failure).
    - Error handling: wrap enqueue in try/catch, log via `LoggingService.captureException(..., domain: 'THEMING_SYNC', subDomain: 'enqueue')`.
    - Debounce/coalesce (optional but recommended): use `easy_debounce` (already used in the repo) to gate sends behind a 200–300ms timer to avoid flooding when users experiment; only last value is sent.
    - Debounce key uniqueness: use an instance‑specific key to avoid collisions if multiple ThemingCubit instances exist, e.g. `final _debounceKey = 'theming.sync.${identityHashCode(this)}';` then `EasyDebounce.debounce(_debounceKey, const Duration(milliseconds: 250), () async { /* enqueue */ });`.
    - Imports to add in ThemingCubit:
      - `import 'package:lotti/features/sync/outbox/outbox_service.dart';`
      - `import 'package:easy_debounce/easy_debounce.dart';`
    - Availability guard: ensure `OutboxService` is registered before use (e.g., `if (getIt.isRegistered<OutboxService>()) { /* enqueue */ }`), and log a warning if not yet available.

- Outbox service
  - Extend `OutboxService.enqueueMessage(...)` to route `SyncThemingSelection` and set a descriptive
    subject, e.g. `'themingSelection'`:
    - Touch: `lib/features/sync/outbox/outbox_service.dart` near other `if (syncMessage is ...)`
      arms.

- Receiver/apply
  - Extend `SyncEventProcessor._handleMessage(...)` to handle `SyncThemingSelection` by persisting
    all three keys to `SettingsDb`:
    - Add a `SettingsDb` dependency to `SyncEventProcessor` constructor and store a private ref, or
      route via a tiny `ThemingSyncRepository.applyFromSync(...)` injected into the processor.
    - Sequential writes (SettingsDb has no explicit transaction helper): call `saveSettingsItem(lightSchemeNameKey, ...)`, `saveSettingsItem(darkSchemeNameKey, ...)`, `saveSettingsItem(themeModeKey, ...)`, and write `themePrefsUpdatedAtKey` last to mark completeness.
    - Idempotency and ordering: before applying, fetch local `themePrefsUpdatedAtKey`; if `incoming.updatedAt < localUpdatedAt`, skip apply and log `captureEvent('themingSync.ignored.stale ...', domain: 'THEMING_SYNC')`.
    - Do not emit an Outbox message on apply (no loops). This pathway only writes settings.

- Optional: Maintenance step
  - If desired to align with “Sync Entities,” add a selectable step to push current theming selections on demand:
    - Extend `SyncStep` and `SyncMaintenanceRepository` to include a one‑shot enqueue of `SyncMessage.themingSelection(...)` with the locally stored triple (light, dark, mode).
    - Keep disabled by default if scope is a concern; the auto‑emit on local change already covers primary behavior.

## Data Flow After Change

- Local change → ThemingCubit persists to `SettingsDb` → enqueues `SyncMessage.themingSelection(...)` → Matrix send.
- Remote device receives → `SyncEventProcessor` decodes; if `updatedAt` is newer than `themePrefsUpdatedAtKey`, saves all three keys and the new `themePrefsUpdatedAtKey` to `SettingsDb` → next ThemingCubit load/emit reflects the persisted selections.

## Risks & Mitigations

- Missing or unknown theme names on receiver:
  - Mitigation: ThemingCubit already defaults to `FlexScheme.greyLaw` when a key is null or
    unrecognized; no crash.
- Unknown or invalid ThemeMode value on receiver:
  - Mitigation: Normalize to `ThemeMode.system` when not one of `system|light|dark`.
- Partial updates if only one side is sent:
  - Mitigation: Always send the full triple (light, dark, mode) in one message; receiver writes all.
- Conflicting updates from multiple devices (no vector clock):
  - Mitigation: Use `updatedAt` last‑write‑wins semantics; only apply when newer than local `themePrefsUpdatedAtKey`.
- Ping‑pong loops:
  - Mitigation: Receiver writes settings only (no emit). Emission happens only from local UI
    actions.

## Files to Modify / Add

- Modify
  - `lib/features/sync/model/sync_message.dart` — add `SyncThemingSelection` variant.
  - `lib/features/sync/outbox/outbox_service.dart` — handle theming selection in `enqueueMessage`
    and set subject.
  - `lib/features/sync/matrix/sync_event_processor.dart` — add apply case for theming; persist to
    `SettingsDb`.
  - `lib/blocs/theming/theming_cubit.dart` — import shared keys; enqueue theming selection message
    in `setLightTheme`, `setDarkTheme`, and `onThemeSelectionChanged`.
  - `lib/get_it.dart` — wire `SettingsDb` into `SyncEventProcessor` (new optional ctor param), or register and inject a new `ThemingSyncService` used by the processor for apply.
  - `lib/features/sync/matrix/sync_event_processor.dart` — update exhaustive `switch` to include the new `SyncThemingSelection` case.
- Add
  - `lib/features/settings/constants/theming_settings_keys.dart` — shared constants for keys and timestamp.
  - Tests under `test/` (see Test Strategy).

## Test Strategy

- Unit — model/serialization
  - New: `test/features/sync/model/sync_message_theming_test.dart`
    - Encode/decode `SyncMessage.themingSelection(...)` round‑trip for names, `themeMode`, and `updatedAt`.
    - Backward/forward compatibility: unknown extra fields in JSON ignored.

- Unit — Outbox emission from ThemingCubit
  - New: `test/blocs/theming/theming_cubit_sync_test.dart`
    - Register a `MockOutboxService` in `getIt` (pattern exists in `test/mocks/mocks.dart:194`), and unregister in tearDown to avoid leakage.
    - Call `setLightTheme('Indigo')`, `setDarkTheme('Shark')`, and change ThemeMode via
      `onThemeSelectionChanged({ThemeMode.dark})`.
    - Assert `enqueueMessage` called with `SyncMessage.themingSelection` containing the expected light/dark/mode triple and a non‑decreasing `updatedAt` (verify last call triple matches the most recent change).
    - Assert keys persisted locally by `SettingsDb` if using an in‑memory instance (optional since
      existing behavior is covered elsewhere).
    - If debounce is implemented, use `pump(const Duration(milliseconds: 300))` to flush timers and assert only one call per rapid change burst.

- Unit — Receiver apply in SyncEventProcessor
  - Extend `test/features/sync/matrix/sync_event_processor_test.dart` with a new test:
    - Construct processor with a `SettingsDb` (in‑memory) or a small `ThemingSyncRepository` mock.
    - Feed an Event carrying a base64‑encoded
      `SyncMessage.themingSelection(light: 'Indigo', dark: 'Shark', themeMode: 'dark', updatedAt: 1234567890)`.
    - Assert `SettingsDb.itemByKey(lightSchemeNameKey)`, `itemByKey(darkSchemeNameKey)`, and
      `itemByKey(themeModeKey)` match.
    - Add a second event with an older `updatedAt` and assert values are unchanged.

- Widget — ThemingPage smoke (no behavioral changes required)
  - Optional: verify selecting a theme triggers one Outbox enqueue using the mock pattern +
    `pumpWidget` on `ThemingPage`.
    - If debounce is enabled, assert that rapid changes are coalesced to one enqueue.

- Analyzer rules
  - Ensure zero warnings; if test arguments look redundant, use targeted `// ignore` in tests only.

## Implementation Steps

1) Models

- Add `SyncThemingSelection` to `sync_message.dart` (fields: lightThemeName, darkThemeName, themeMode, updatedAt, status); run codegen.

2) Shared keys

- Create `lib/shared/constants/theming_settings_keys.dart` and update ThemingCubit imports.

3) Emission

- Modify `ThemingCubit.setLightTheme`, `.setDarkTheme`, and `.onThemeSelectionChanged` to enqueue
  `SyncMessage.themingSelection(...)` with the currently active triple.

4) Outbox

- Add a handler for `SyncThemingSelection` with subject `'themingSelection'` in `OutboxService.enqueueMessage` and consistent logging (`domain: 'OUTBOX', subDomain: 'enqueueMessage'`).

5) Receiver

- Inject `SettingsDb` (or `ThemingSyncRepository`) into `SyncEventProcessor` and handle the new variant by saving all three keys and timestamp atomically; update the exhaustive switch to include the new case.

6) Tests

- Add unit tests for model round‑trip, emission, and receiver apply.

7) Docs/CHANGELOG

- Add a CHANGELOG entry and this plan reference.
- Update the docs when done to reflect the latest implementation.
 - Mention the preserved dark key typo and the alias in a short migration note.

## Rollout & Validation

- Local validation
  - make build_runner
  - make analyze
  - make test
  - Verify UI on two devices/simulators by changing light/dark schemes and ThemeMode and observing mirrored changes.
  - Simulate conflict: change themes on device A, then on device B without network; reconnect both and verify LWW by `updatedAt` (device with later timestamp wins).

- Metrics/observability
  - No special counters added; standard Outbox/Sync Stats will show the text event traffic.

## Open Questions

- Backward compatibility: older clients that don’t understand `themingSelection` will ignore the
  message. No migration needed.
 - Where to place shared constants: this plan opts for `lib/features/settings/constants/...` to align with existing patterns and avoid introducing a new top‑level directory.

## Acceptance Checklist

- New `SyncMessage.themingSelection` exists and serializes correctly.
- Theming changes locally enqueue a theming selection message with both scheme names and ThemeMode.
- Receiver applies all three keys to `SettingsDb` without emitting another message.
- `updatedAt` tie‑breaker implemented; older updates are ignored and logged.
- ThemingCubit enqueue path includes error handling and optional debounce.
- Switch statement in `SyncEventProcessor` updated with the new case.
- get_it wiring updated to inject `SettingsDb` into `SyncEventProcessor` (or a dedicated service).
- Analyzer shows zero warnings; tests pass; code formatted.
- CHANGELOG updated.

## Implementation Discipline

- Prefer MCP tools for analysis/tests/formatting:
  - Analyze: dart-mcp.analyze_files
  - Tests: dart-mcp.run_tests (start focused, then full suite)
  - Format: dart-mcp.dart_format
- Do not modify generated files by hand; regenerate via `make build_runner`.
- Keep changes minimal, modular, and covered by tests.
