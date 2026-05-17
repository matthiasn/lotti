# Auto-trigger local ASR + LLM on a capable desktop when mobile syncs audio

## Context

Today mobile devices create `JournalAudio` entries but cannot run the local MLX ASR or Ollama Qwen 3.6 35B (A3B) models without crashing. When the user returns to a capable macOS desktop, they must manually transcribe the audio and nudge the agent. We want this to happen automatically: when a mobile-synced `JournalAudio` arrives on a capable desktop and the responsible profile is pinned to that desktop, the desktop runs the existing local transcription skill and nudges the wake cycle — without any user action, and without ever routing the audio through cloud providers.

A parallel task ("Implement synchronized notification system for AI inference results") owns surfacing results in the UI; this plan ends at "task state updated, wake nudged".

## Decisions (confirmed with user)

1. **Local-only is derived, not flagged.** A profile is local iff every *referenced* model id (`thinkingModelId`, `transcriptionModelId`, etc.) resolves to a provider in `{ollama, voxtral, whisper, mlxAudio}`. **Operates on the raw `AiConfigInferenceProfile` plus `AiConfigRepository`** — NOT on `ResolvedProfile`, which silently drops unresolved optional slots and would mask a referenced-but-currently-broken cloud slot as "local". A referenced model whose provider config is missing counts as **not local** (fail closed).
2. **Node directory is broadcast over Matrix** as a new `SyncMessage.syncNodeProfile(...)` variant. Each node publishes its name, platform, and capabilities; peers maintain a local directory. Durability: the broadcaster always re-publishes on every app startup (not diff-only), so late-joining peers and peers that wiped settings always converge on the current snapshot within one session.
3. **Pinned-or-skip — no fallback.** If the pinned host is offline, the entry stays untranscribed until it comes online. Avoids duplicate-inference races between multiple capable desktops; the user can re-pin manually.
4. **MLX has landed** as `InferenceProviderType.mlxAudio` (commit 5c84a455a, PR #3173). The existing `isLocalOnlyProviderType` in `prompt_capability_filter.dart` currently lists `{whisper, ollama, voxtral}` and must be extended to include `mlxAudio`. Provider channel lives at `lib/features/ai/util/mlx_audio_channel.dart`.
5. **No reuse of `AutomaticPromptTrigger` for synced audio.** Its `ProfileAutomationService.tryTranscribe` (a) treats `enableSpeechRecognition: false` as an opt-out and returns `notHandled` immediately, and (b) falls back via `_tryDirectTranscriptionFallback` to **any** audio-to-text model — cloud models included — when the profile path doesn't handle the request. Both behaviors silently break the local-only guarantee for synced audio. The dispatcher therefore owns the inference flow end-to-end: it loads the profile, finds the automated transcription `SkillAssignment` on that profile (no fallback to other profiles or to direct models), invokes `SkillInferenceRunner.runTranscription` with that explicit `AutomationResult`, and then nudges `WakeOrchestrator.enqueueManualWake`.
6. **Sync-only event source.** `UpdateNotifications.updateStream` emits local, sync, *and* UI-only notifications, so subscribing to it would fire the dispatcher on user typing and on agent UI refresh. Add a new `syncUpdateStream` that emits only the `fromSync: true` batch. The dispatcher listener subscribes to that.

## Architecture overview

```
Matrix room
   │
   ▼
SyncEventProcessor._persistJournalEntity()
   │  writes JournalAudio + calls _updateNotifications.notify({...}, fromSync: true)
   ▼
UpdateNotifications.syncUpdateStream   ◄── sync-only, batched 1s window
   │
   ▼
SyncedAudioInferenceListener  (NEW — Riverpod KeepAlive)
   │  filters ids → loads entities → routes to dispatcher
   ▼
SyncedAudioInferenceDispatcher (NEW)
   │  eligibility (§4) → resolve profile via task/agent chain
   │                  → profileIsLocal + pinnedHostId guards
   │                  → verify profile has a transcription slot + automated skill
   ▼
SkillInferenceRunner.runTranscription(...)  ─► MLX transcription provider
   │
   │  reread audio entry; only proceed if transcripts grew
   ▼
WakeOrchestrator.enqueueManualWake(reason: transcriptionComplete)
   │
   ▼
Ollama Qwen 3.6 35B (A3B)
```

The listener subscribes to a new `UpdateNotifications.syncUpdateStream` (sync-only, no local/UI emissions) — never the general `updateStream`. This gives the dispatcher a clean event source and is unit-testable with `fakeAsync`.

The dispatcher does **not** call `AutomaticPromptTrigger` at any point. It would re-enter `ProfileAutomationService.tryTranscribe` and risk falling back to cloud transcription models — see decision §5. The dispatcher owns the inference flow directly, including the post-transcription verification that a transcript was actually persisted before nudging the wake.

## 1. Data model changes

### 1a. `AiConfigInferenceProfile` — add pinning
`lib/features/ai/model/ai_config.dart`
- Add `String? pinnedHostId` (single host id, the VC host UUID — not the Matrix device id). Recommend single rather than `List<String>` to avoid tie-break complexity for v1.
- Regenerate `ai_config.freezed.dart` / `ai_config.g.dart` via `make build_runner`.
- No DB migration: configs are stored as JSON blobs in `ai_configs` (`lib/features/ai/database/ai_config_db.dart`); `json_serializable` ignores unknown keys, so older clients still deserialize new profiles, and newer clients default the field to null.

### 1b. `profileIsLocal(AiConfigInferenceProfile, AiConfigRepository)` — derived check on the raw config
`lib/features/ai/helpers/profile_locality.dart` (new file)
- A free function `Future<bool> profileIsLocal(AiConfigInferenceProfile profile, AiConfigRepository repo)`. For every non-null model id on the profile (`thinkingModelId`, `thinkingHighEndModelId`, `imageRecognitionModelId`, `transcriptionModelId`, `imageGenerationModelId`), look up the `AiConfigModel`, then its `AiConfigInferenceProvider`. The profile is local iff every lookup succeeds AND every provider's `inferenceProviderType` satisfies `PromptCapabilityFilter.isLocalOnlyProviderType`.
- **Fail closed:** a referenced model id whose model or provider config is missing counts as **not local**. This avoids the bug where the resolver silently drops an unresolved cloud-referencing slot and the profile would otherwise look local. Add a test for exactly this case.
- Reuse the existing `PromptCapabilityFilter.isLocalOnlyProviderType` static helper (`lib/features/ai/helpers/prompt_capability_filter.dart:52`). Add `InferenceProviderType.mlxAudio` to its returned set (currently `{whisper, ollama, voxtral}`).
- **Not on `ResolvedProfile`.** `ResolvedProfile` is built by `ProfileResolver`, which sets unresolved optional slots to null, so a slot that *references* a non-local provider but whose provider config has been deleted/renamed would disappear from `ResolvedProfile` and a getter there would report `isLocal: true` incorrectly.

### 1c. `SyncNodeProfile` — new freezed model
`lib/features/sync/model/sync_node_profile.dart` (new)
- Fields: `String hostId`, `String displayName`, `String platform` (`macos`/`linux`/`windows`/`ios`/`android`), `String? cpuModel`, `int? ramMb`, `String? gpuModel`, `List<NodeCapability> capabilities`, `DateTime updatedAt`.
- `enum NodeCapability { mlxAudio, ollamaLlm, voxtral, whisper }` plus an **explicit** `NodeCapability.providerType` getter and a top-level `nodeCapabilityFromProviderType(InferenceProviderType)` function. Mapping is **not** by string match — `ollamaLlm` ↔ `InferenceProviderType.ollama` deliberately don't share a name (keeps the capability name semantic-future-proof should Ollama embeddings ever need a separate token). Cloud provider types map to null.

### 1d. New `SyncMessage` variant
`lib/features/sync/model/sync_message.dart` — add `SyncMessage.syncNodeProfile(SyncNodeProfile profile)`. Regenerate freezed/json.

## 2. New files

| Path | Responsibility |
|---|---|
| `lib/features/sync/model/sync_node_profile.dart` | Freezed model + `NodeCapability` enum. |
| `lib/features/sync/repository/sync_node_profile_repository.dart` | Read/write local node profile (`sync_node_profile_self` key) and directory (`sync_node_profile_directory` map) in `SettingsDb`. |
| `lib/features/sync/services/sync_node_profile_broadcaster.dart` | Two entry points: `broadcast()` (unconditional, called on every startup so late-joining peers always converge) and `broadcastIfChanged()` (diff-only, called from the rename UI to suppress no-op renames). |
| `lib/features/sync/services/sync_node_capability_probe.dart` | The actual capability detector. `makeDefaultSyncNodeCapabilityProbe({ollamaProbe})` returns a probe that claims `mlxAudio` on macOS (the MLX channel is macOS-only) and `ollamaLlm` when a short HTTP request to `127.0.0.1:11434/api/version` succeeds inside a 300ms timeout. Voxtral and Whisper require local binaries the app does not manage — explicitly **not** auto-claimed; the user opts in via the sync-node settings UI (PR4) so a false-positive doesn't surface broken pin choices. `ollamaProbe` is injected so tests stub the HTTP probe without spinning up a real server. |
| `lib/features/sync/services/synced_audio_inference_listener.dart` | KeepAlive Riverpod provider that subscribes to the new `UpdateNotifications.syncUpdateStream` and routes candidate ids to the dispatcher. Crucially **not** `updateStream` — that one carries local + UI-only emissions too. |
| `lib/features/sync/services/synced_audio_inference_dispatcher.dart` | Eligibility check + profile-only transcription + manual wake nudge. Owns the inference flow end-to-end so synced audio can never escape to a cloud provider via fallback. |
| `lib/features/ai/helpers/profile_locality.dart` | `profileIsLocal(AiConfigInferenceProfile, AiConfigRepository)` — the fail-closed locality check used by the dispatcher. |
| `lib/features/sync/ui/sync_node_profile_page.dart` | Settings page: edit local display name, view capabilities, list known nodes. |
| `lib/features/ai/ui/widgets/profile_pinning_selector.dart` | Dropdown over the node directory for the `pinnedHostId` field on the inference-profile edit screen. |

## 3. Modifications to existing files

- `lib/features/ai/model/ai_config.dart` — add `pinnedHostId` to `AiConfigInferenceProfile`. Regenerate.
- `lib/features/sync/model/sync_message.dart` — add `syncNodeProfile` variant.
- `lib/features/ai/helpers/profile_automation_resolver.dart` — add a `Future<String?> resolveProfileIdForTask(String taskId)` method that runs the *exact same* resolution chain as `resolveForTask` (agent → `version.profileId` → `template.profileId` → `task.data.profileId`) but returns the raw profile id string instead of a `ResolvedProfile`. The dispatcher uses this so it can load the raw `AiConfigInferenceProfile` (for `pinnedHostId` and `profileIsLocal`) and skip the silent-drop bug that `ResolvedProfile` has for unresolved slots. The new method MUST honor the existing precedence — agent-level overrides win over the task-level fallback win over the category default — so a category edit after task creation cannot retroactively change which device claims an entry.
- `lib/features/sync/matrix/sync_event_processor.dart` (+ part files in `sync_event_processor_*.dart`) — add a new handler that upserts the directory via `SyncNodeProfileRepository`. Surface in the `apply()` switch. No journal write, no `UpdateNotifications.notify` (directory changes are not journal mutations; the repository's own stream is the reactivity source).
- `lib/features/sync/outbox/outbox_service.dart` — add a `_enqueueSyncNodeProfile` arm so the broadcaster can route through the existing `enqueueMessage` path.
- `lib/features/sync/queue/queue_apply_adapter.dart`, `lib/features/sync/ui/view_models/outbox_list_item_view_model.dart`, `lib/features/sync/matrix/matrix_service.dart` — fill in the new variant in every exhaustive switch.
- `lib/services/db_notification.dart` — add a new `Stream<Set<String>> get syncUpdateStream` field/getter that emits only the `fromSync: true` batch. Existing `updateStream` semantics unchanged so UI listeners are unaffected.
- `lib/features/ai/helpers/prompt_capability_filter.dart` — extend the existing `isLocalOnlyProviderType` (line 52) to include `InferenceProviderType.mlxAudio`. Reuse this helper from `profile_locality.dart`.
- `lib/features/ai/ui/inference_profile_form.dart` — **already passes `pinnedHostId` through on save** (no UI selector yet — preserves whatever was stored so unrelated edits don't silently break the auto-trigger). PR4 adds the `ProfilePinningSelector` widget that lets the user pick a host from the directory, filtered to nodes whose `capabilities` map back (via `nodeCapabilityFromProviderType`) to every `InferenceProviderType` the profile references.
- `lib/features/sync/repository/sync_node_profile_repository.dart` — `syncNodeProfileRepositoryProvider` returns `getIt<SyncNodeProfileRepository>()` (NOT a fresh instance). The production sync apply path writes through the get_it singleton; a Riverpod-owned instance would have its own stream controller and any UI watching the provider would miss every directory update that arrives over Matrix.
- `lib/get_it.dart` — register `SyncNodeProfileRepository`, `SyncNodeProfileBroadcaster`, and the listener at startup. Listener subscribes to `syncUpdateStream` and never autodisposes. The broadcaster calls `broadcast()` (unconditional) on startup, not `broadcastIfChanged()`.

**No reuse of** `AutomaticPromptTrigger`, `ProfileAutomationService.tryTranscribe`, or `_tryDirectTranscriptionFallback` from the dispatcher path — see decision §5.

`SkillInferenceRunner.runTranscription` and `WakeOrchestrator.enqueueManualWake` are still reused unchanged, but invoked **directly** by the dispatcher with an explicit `AutomationResult` it builds from the profile's transcription skill assignment.

## 4. Dispatcher eligibility logic

The dispatcher subscribes to `UpdateNotifications.syncUpdateStream` (sync-only — never receives local or UI-only emissions). For each id in each batch:

1. Skip sentinels (`labelUsageNotification`, `categoriesNotification`, and other non-entity tokens).
2. Load `JournalEntity` via `journalDb.journalEntityById(id)`. Skip if not `JournalAudio`. Capture `priorTranscriptCount = audio.data.transcripts?.length ?? 0` for the post-transcription verification at step 17.
3. Skip if `priorTranscriptCount > 0` (already transcribed somewhere — even a self-echo path covers this once the recording device wrote a transcript).
4. **Self-echo guard.** Skip if `audio.meta.vectorClock?.vclock` has **exactly one entry** that is the local host id (`{localHostId: n}` and nothing else). A merged remote update can legitimately include the local host's counter alongside other hosts — `containsKey(localHostId)` alone is too broad. A follow-up may propagate `SyncMessage.originatingHostId` through the sync-only notification path for an exact check, but the "single-key local-host" fallback is correct in the current shape: a peer's edit always pulls another host id into the clock.
5. Find the linked task via `journalDb.linksToEntity(id)` (or equivalent). Skip if none — transcription-without-task is out of scope for the auto-trigger.
6. **Resolve the task's profile id via the existing chain.** Call `profileAutomationResolver.resolveProfileIdForTask(taskId)` (new method — see §3). This returns the same profile that the manual on-device trigger would use: agent's `agentConfig.profileId` first, then `version.profileId`, then `template.profileId`, then `task.data.profileId` (the inherited value stored at task creation). Skip if it returns null. **Do not read `category.defaultProfileId` directly** — that would skip agent overrides and would silently re-route work after a category edit, away from the device the user pinned.
7. **Load the raw `AiConfigInferenceProfile`** via `aiConfigRepository.getConfigById(profileId)`. Skip if not found or wrong type. (We need the raw config — not a `ResolvedProfile` — so `pinnedHostId` is accessible and `profileIsLocal` can see referenced-but-unresolved slots.)
8. Skip if `profile.pinnedHostId == null` (no pin = no auto-claim — explicit, conservative default).
9. Skip if `profile.pinnedHostId != localHostId` (`VectorClockService.getHost()`).
10. **Locality guard.** Skip with an error log if `!await profileIsLocal(profile, aiConfigRepository)` — fail closed: an unresolved model id counts as non-local. This prevents accidental cloud routing if the pinning UI ever lets a mixed profile through, or if a referenced provider config has been deleted/renamed since pinning.
11. **Transcription-slot guard.** Skip if `profile.transcriptionModelId == null`. `SkillInferenceRunner.runTranscription` early-returns when the resolved profile has no transcription provider/model and does not raise — without this check the dispatcher would proceed to step 13 thinking work happened and then nudge a wake against an unchanged entry.
12. Find the automated transcription `SkillAssignment` on the profile: scan `profile.skillAssignments` for an assignment where `automate == true` AND the looked-up `AiConfigSkill.skillType == SkillType.transcription`. If none, skip with a log — **no fallback to other transcription paths**. Synced audio is never auto-routed through `_tryDirectTranscriptionFallback`'s rank-ordered audio-to-text model search.
13. Build a `ResolvedProfile` for the profile (use the existing `ProfileResolver.resolveByProfileId` path), and an `AutomationResult(handled: true, resolvedProfile: ..., skill: ..., skillAssignment: ...)`.
14. Call `skillInferenceRunner.runTranscription(audioEntryId: id, automationResult: ..., linkedTaskId: taskId)` directly. Wrap in a `try` so an unexpected throw is logged and surfaces at step 15 as "no transcript persisted".
15. **Reload** the audio entity: `final after = await journalDb.journalEntityById(id);`. Let `postCount = after?.data.transcripts?.length ?? 0`.
16. Skip the wake (with a log) if `postCount <= priorTranscriptCount`. Silent transcription failure (return-early, swallowed error inside `runTranscription`'s status tracking, etc.) must not produce a misleading wake — the agent would burn a cycle on an unchanged task. The next sync arrival or a manual transcribe re-triggers the work.
17. On confirmed new transcript: look up the task's agent via `taskAgentService.getTaskAgentForTask(linkedTaskId)`. If non-null, call `wakeOrchestrator.enqueueManualWake(agentId: agent.agentId, reason: WakeReason.transcriptionComplete.name, triggerTokens: {linkedTaskId, id})` directly (mirroring `AutomaticPromptTrigger._nudgeTaskAgent`).
18. Every step that "skips" must log enough context (id, decision, reason) to debug a missing auto-trigger from log triage alone.

## 5. Sequencing (independently mergeable PRs)

1. **PR1 — data model + codegen.** `pinnedHostId`, `SyncNodeProfile`, `NodeCapability`, `syncNodeProfile` SyncMessage variant. Tests for JSON round-trip and forward-compat (older clients ignore the new field). ✅ landed.
2. **PR2 — node directory + sync-only stream.** Repository, broadcaster (with `broadcast()` and `broadcastIfChanged()`), sync handler, and `UpdateNotifications.syncUpdateStream`. Tests in §6. ✅ landed.
3. **PR3 — locality helper.** `profile_locality.dart` (`profileIsLocal`), and extending `isLocalOnlyProviderType` with `mlxAudio`. Pure logic, fully unit-testable. No UI impact yet. No `isLocal` getter on `ResolvedProfile`. ✅ landed.
4. **PR4 — pinning UI** on the inference-profile edit page + sync-node settings page. Widget tests. UI copy: "Not pinned (no auto-trigger)" — never "Any capable device".
5. **PR5 — sync-arrival listener + dispatcher.** Includes `ProfileAutomationResolver.resolveProfileIdForTask` (raw-id variant of the existing chain), the dispatcher logic in §4, the listener subscribed to `syncUpdateStream`, and the integration test. Big test surface lives here.

PRs 1–4 are non-load-bearing on their own (no behavior change for users until PR5 lands), so they can land in any order behind PR5 and keep the diff per PR small enough to review carefully.

## 6. Test strategy

Mirror source paths under `test/`. Per AGENTS.md: meaningful assertions, no `findsOneWidget`-only smoke tests, no `Future.delayed` / `sleep` in tests, deterministic dates, use `test/mocks/mocks.dart` and `test/widget_test_utils.dart`.

- `test/features/ai/model/ai_config_test.dart` — `pinnedHostId` round-trips; deserializing legacy JSON (without the field) yields null.
- `test/features/sync/model/sync_node_profile_test.dart` — serialization round-trip; `capabilities` list order is stable across JSON round-trip; equality.
- `test/features/sync/repository/sync_node_profile_repository_test.dart` — self read/write; directory upsert is keyed by `hostId`; an upsert with an older `updatedAt` is ignored.
- `test/features/sync/services/sync_node_profile_broadcaster_test.dart` — `broadcast()` always enqueues a message; `broadcastIfChanged()` enqueues on first run and on any field diff, skips on identical re-probe; `displayNameOverride` beats probe defaults; skips when VC host is missing.
- `test/features/sync/services/sync_node_capability_probe_test.dart` — probe claims `ollamaLlm` iff the injected `ollamaProbe` returns true; claims `mlxAudio` iff `Platform.isMacOS`; never claims `voxtral`/`whisper` from auto-detection; deterministic output across repeated probes; preserves user-supplied displayName.
- `test/features/sync/model/node_capability_mapping_test.dart` — `NodeCapability.providerType` is exhaustive and correct for every value; `nodeCapabilityFromProviderType` round-trips, returns null for every cloud provider, exercised over every `InferenceProviderType` enum value (catches new enum additions that would silently fall through).
- `test/features/ai/ui/inference_profile_form_test.dart` — regression guard: editing a profile with `pinnedHostId` set and saving without changes preserves the pin (the form has no selector yet but must passthrough).
- `test/features/sync/matrix/sync_event_processor_node_profile_test.dart` — receiving the new variant upserts the directory and emits **no** journal mutations.
- `test/services/db_notification_test.dart` — `notify(..., fromSync: true)` emits on **both** `updateStream` and `syncUpdateStream`; `notify(..., fromSync: false)` emits on `updateStream` and `localUpdateStream` but **not** on `syncUpdateStream`; `notifyUiOnly` emits on `updateStream` only.
- `test/features/ai/helpers/profile_locality_test.dart` — `profileIsLocal` returns true when every populated model resolves to `{ollama, voxtral, whisper, mlxAudio}`; false the moment any slot's provider type is cloud; **false when a populated model id can't be resolved** (model deleted) — fail-closed; vacuous true for a profile with only the thinking slot referencing a local model.
- `test/features/ai/helpers/prompt_capability_filter_test.dart` — parameterized: `isLocalOnlyProviderType(mlxAudio) == true` plus the existing whisper/ollama/voxtral; all other enum values false.
- `test/features/ai/helpers/profile_automation_resolver_test.dart` — extend the existing test file with `resolveProfileIdForTask`: returns the agent's `agentConfig.profileId` when set; falls back to `version.profileId`, then `template.profileId`, then `task.data.profileId`; **does not** consult `category.defaultProfileId` (proves agent/task chain wins). Verifies the new method shares the chain with `resolveForTask` so the two cannot drift.
- `test/features/sync/services/synced_audio_inference_dispatcher_test.dart` — **table-driven negative branches**, each asserting `SkillInferenceRunner.runTranscription` was **not** called: not a `JournalAudio`; transcripts non-empty; self-originated (VC has only the local host id); no linked task; `resolveProfileIdForTask` returns null; profile not found; `pinnedHostId` null; `pinnedHostId` mismatch; `profileIsLocal == false`; `profile.transcriptionModelId == null` (slot guard); profile has no automated transcription `SkillAssignment` (proves no fallback). Plus a "ran but produced no transcript" case: `runTranscription` is called, dispatcher reloads the entity, transcripts unchanged → `wakeOrchestrator.enqueueManualWake` is **not** called. Positive branch asserts (a) `runTranscription` is called with the expected `audioEntryId`/`linkedTaskId`/skill, (b) the dispatcher reloads the audio entity afterwards, (c) `wakeOrchestrator.enqueueManualWake` is called with `WakeReason.transcriptionComplete.name` exactly once, (d) `AutomaticPromptTrigger.triggerAutomaticPrompts` is **never** called.
- `test/features/sync/services/synced_audio_inference_listener_test.dart` — `fakeAsync`. Push `fromSync: true` notifications → listener fires. Push `fromSync: false` (local) notifications **and** `notifyUiOnly` notifications → listener does **not** fire.
- Self-echo coverage in the dispatcher test: assert skip when VC is `{localHostId: n}` only; assert **proceed** when VC has the local host AND any other host (covers the reviewer's "merged VC is not self-echo" point).
- Stale-category-default coverage: dispatcher invoked with a task whose `task.data.profileId` is local-and-pinned-here, but `category.defaultProfileId` was edited to a *different* profile after task creation. Dispatcher proceeds because it follows the task chain — proves the reviewer's High finding #1 fix.
- `integration_test/synced_audio_inference_test.dart` — fake Matrix layer. Enqueue a synthetic `SyncJournalEntity` for a `JournalAudio` linked to a `Task` whose inherited `profileId` resolves to a pinned local profile on the local host. Run `SyncEventProcessor.apply()`. Assert: entity persists, `syncUpdateStream` emits, dispatcher invokes a recorded fake `SkillInferenceRunner.runTranscription`, the audio entity's `transcripts` list grew, and `WakeOrchestrator.enqueueManualWake` fires exactly once with reason `transcriptionComplete`. Negative integrations: same but with (a) `pinnedHostId` mismatched, (b) profile pointing to a cloud transcription model, (c) profile with no automated transcription skill, (d) `runTranscription` returns without writing a transcript — each asserts the wake is **not** enqueued.

## 7. Localization (ARB)

Add to `lib/l10n/app_en.arb`, then run `make l10n` and `make sort_arb_files`. Translate to `app_cs/de/es/fr/ro` (informal tone; Romanian formal); only update `app_en_GB` if spelling differs.

- `settingsSyncNodeProfileTitle` — "This device"
- `settingsSyncNodeProfileDisplayNameLabel` — "Display name"
- `settingsSyncNodeProfileCapabilitiesLabel` — "Detected capabilities"
- `settingsSyncNodeProfileKnownNodesTitle` — "Known sync nodes"
- `aiProfilePinnedHostLabel` — "Pinned device"
- `aiProfilePinnedHostHelper` — "When set, only this device auto-runs inference for synced audio entries that use this profile."
- `aiProfilePinnedHostNone` — "Not pinned (no auto-trigger)"
- `aiProfilePinnedHostNoneHelper` — "Synced audio entries are not auto-transcribed when no device is pinned."
- `nodeCapabilityMlxAudio` — "MLX Audio (local)"
- `nodeCapabilityOllamaLlm` — "Ollama LLM"
- `nodeCapabilityVoxtral` — "Voxtral (local)"
- `nodeCapabilityWhisper` — "Whisper (local)"

## 8. README updates

- `lib/features/sync/README.md` — describe the `SyncNodeProfile` broadcast, the directory storage in `SettingsDb`, the new `syncUpdateStream`, and the auto-trigger listener/dispatcher path (`syncUpdateStream` → dispatcher → `SkillInferenceRunner.runTranscription` → `WakeOrchestrator.enqueueManualWake`). Include a Mermaid sequence diagram for the mobile → desktop auto-trigger flow.
- `lib/features/ai/README.md` — document profile pinning (`pinnedHostId`), the `profileIsLocal` helper (fail closed on unresolved slots), the local-providers set including `mlxAudio`, the new `resolveProfileIdForTask` chain, and that **`AutomaticPromptTrigger` is deliberately not on the synced-audio path** (cloud-fallback risk). Include the architecture diagram from §0.

## 9. CHANGELOG & metainfo

Add an entry under the current `pubspec.yaml` version (do **not** bump the version, do **not** add an `[Unreleased]` section) and update `flatpak/com.matthiasn.lotti.metainfo.xml` to match. Don't list intermediate bug fixes for bugs introduced and fixed within the work.

## 10. Critical files

- `lib/features/ai/model/ai_config.dart` — `pinnedHostId` on `AiConfigInferenceProfile`
- `lib/features/ai/helpers/profile_locality.dart` (new) — `profileIsLocal(AiConfigInferenceProfile, AiConfigRepository)`, fail-closed
- `lib/features/ai/helpers/prompt_capability_filter.dart` — extend `isLocalOnlyProviderType` to include `mlxAudio`
- `lib/features/ai/services/skill_inference_runner.dart` — **invoked directly by the dispatcher** (not via `AutomaticPromptTrigger`)
- `lib/features/agents/wake/wake_orchestrator.dart` — **invoked directly by the dispatcher** for the post-transcription nudge
- `lib/services/db_notification.dart` — add `syncUpdateStream`
- `lib/services/vector_clock_service.dart` — `getHost()` returns the local host id used for self-echo and pin matching
- `lib/features/sync/matrix/sync_event_processor.dart` and part files — entry point for receiving sync messages; handler for the new variant
- `lib/features/sync/model/sync_message.dart` — `syncNodeProfile` variant
- `lib/features/ai/util/profile_resolver.dart` — used by the dispatcher (`resolveByProfileId`) to build the `ResolvedProfile` passed to `runTranscription`; **no `isLocal` getter here**

`AutomaticPromptTrigger` and `ProfileAutomationService` are deliberately **not** on the synced-audio path — they remain the right abstraction for on-device-recorded audio where falling back to any configured transcription model is the correct behavior.

## 11. Verification

**Automated (CI):**
- All new unit tests (§6) plus the integration test must pass under `make test` / `very_good test`.
- `make analyze` must report zero warnings/infos (per AGENTS.md zero-warning policy).
- `fvm dart format .` clean.

**Manual (two-machine):**
1. Pair a mobile device and a capable macOS desktop in the same Matrix room.
2. On the desktop (macOS with Ollama running on `127.0.0.1:11434`): open settings → "Sync nodes", set the display name to e.g. "Studio Mac". Verify the auto-detected capabilities list shows `mlxAudio, ollamaLlm` (the default probe — see `sync_node_capability_probe.dart` — checks `Platform.isMacOS` and pings `/api/version`). If Ollama is not running, `ollamaLlm` will be absent and the auto-trigger will not yet be wireable to this device.
3. On the mobile: open settings → "Sync nodes" → "Known nodes". Confirm "Studio Mac" appears (proves the broadcast + directory work).
4. On either device, edit an inference profile that references only local providers (e.g. MLX transcription + Ollama Qwen thinking) and has an automated transcription skill assignment. Set its **Pinned device** to "Studio Mac". Confirm the profile syncs.
5. Create or edit a category whose `defaultProfileId` is this profile, then create a task in that category (which copies the profile id into `task.data.profileId` at creation time — this is what the dispatcher's `resolveProfileIdForTask` will pick up).
6. On mobile: record a `JournalAudio` linked to that task.
7. Watch desktop logs for the sequence: `synced_audio_inference_dispatcher` (eligibility passed) → `skill_inference_runner.runTranscription` (MLX exit) → dispatcher's `postCount > priorCount` verification → `wakeOrchestrator.enqueueManualWake(reason: transcriptionComplete)` → Ollama Qwen run. **`automatic_prompt_trigger` MUST NOT appear in the logs for this entry** — its absence is part of the test (cloud-fallback prevention).
8. Verify the entry now has a non-empty `transcripts` list with `library: mlxAudio` (or whatever the MLX provider sets) and the linked task has an updated agent state.
9. Negative cases:
   - Clear the pin on the profile → mobile records another audio → desktop logs "pinnedHostId null, skipping". No transcription happens.
   - Re-pin to a different (offline) host id → mobile records → desktop logs "pinnedHostId mismatch, skipping". No transcription happens.
   - Edit the profile to swap in a Gemini model → `profileIsLocal` becomes false → desktop logs "profile not local, refusing auto-trigger" (§4 step 10 guard fires).
   - Remove the automated transcription `SkillAssignment` from the profile → desktop logs "no automated transcription skill, skipping" (§4 step 12 guard fires) — and crucially does **not** fall back to `_tryDirectTranscriptionFallback`.
   - Edit the *category* default profile after task creation: the task keeps using its originally-inherited profile (§4 step 6), so changing the category's default does not retroactively re-route which device claims the entry.
