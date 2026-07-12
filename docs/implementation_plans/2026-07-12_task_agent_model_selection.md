# Task-agent model identity, persistent setup, and report provenance

**Date:** 2026-07-12 · **Branch:** `feat/task_agent_model_selection` · **Status:** implemented and verified; affected tests, analyzer, patch coverage, and visual review gates pass.

**Process:** An interaction/UX reviewer, information-architecture reviewer, and AI systems/data-model reviewer independently inspected the current task-agent, profile, model, provider, category-default, report, and header implementations. The previous version of this plan scored 6.5/10, 6.7/10, and 6.8/10 because it could misattribute edited reports, hid provider identity, and did not make an explicit no-setup state real. The corrected plan below scored **9.5/10 UX, 9.6/10 IA, and 9.4/10 architecture**.

**Delivered verification:** The implemented UI was reviewed again from five deterministic screenshots after addressing the panel’s first-pass findings. The final scores were **9.4/10 UX, 9.5/10 IA, and 9.4/10 systems/UI truth**, with no remaining blockers. The affected test run passed **859 tests** in one process, `flutter analyze` reported zero findings, and executable changed-line coverage measured **345/345 (100%)** excluding generated localization/Freezed/JSON code.

## Outcome

The AI summary header must answer two questions without opening Agent Internals:

1. **Who produced the report currently on screen?**
2. **What persistent setup will this task agent use from now on?**

Most of the time both answers are identical. In that steady state, the card shows one compact, clickable identity line such as:

> Qwen 3.5 122B · Alibaba · via Melious.ai ⌄

When the current report and live setup differ, the card temporarily (or, for a genuine multi-model pipeline, persistently) shows two explicitly labeled lines:

> Current setup — Gemini 3 Pro · Google · via Gemini ⌄
>
> This report — Qwen 3.5 122B · Alibaba · via Melious.ai

Changing the setup is **persistent until changed again**. It is never a one-off or next-run-only override. The optional **Run now** action merely lets the user request an immediate wake after changing the persistent setup; changing the setup itself never spends tokens.

Profiles remain the friendly multi-capability bundle. The header leads with the effective thinking model, model publisher when known, and serving provider because that is the useful answer to “who am I dealing with?” A user may keep the profile default or persistently choose a specific thinking model for this task agent.

## Verified current architecture

- `AgentConfig.profileId` is already a persistent agent-level profile selection.
- `ProfileResolver` currently resolves `agent config profile → template-version profile → template profile → legacy template model`.
- Category defaults are copied into `TaskData.profileId` and the task agent at creation; they are not live inheritance.
- `TaskAgentService.updateAgentProfile()` already persists profile changes, but there is no dedicated configured-model override.
- `AgentReportEntity` has an existing synced `provenance` map, but task-agent report writes do not populate it.
- Wake runs and token records preserve parts of the historical model route, but not enough immutable provider/profile identity to attribute a report safely after configuration changes or deletion.
- A task-agent report may be drafted by the configured executor and replaced by an accepted Qwen report-editor revision. The final visible author can therefore differ from the configured thinking model.
- `AiConfigModel.id`, `providerModelId`, and `AiConfigInferenceProvider.id` are distinct identifier spaces and must never be interchanged.

## Non-negotiable behavior

1. The collapsed card makes model and serving-provider identity readable without a tooltip, color legend, or Agent Internals.
2. The identity line opens the persistent task-agent setup directly from the header.
3. Changing setup applies to every future wake until changed again.
4. Changing setup never relabels an older report.
5. Model publisher/family and serving provider are separate concepts: e.g. `Llama · Meta · via OpenRouter` or `Qwen · Alibaba · via Melious.ai`.
6. “No setup” is an explicit persisted state that stops inference; it must not fall through to a template or legacy model.
7. Missing, deleted, legacy, and partially known data are labeled honestly and never reconstructed from mutable live configuration.
8. Runtime and UI consume the same detailed resolution result.

## Header identity design

### Placement and responsive behavior

Add a dedicated full-width identity region below the existing title/control `Wrap` in `TldrHeader`. It remains outside the run negotiation so adding identity never changes whether playback, refresh, countdown, cancel, and Read more share or wrap their current control row.

The interactive row has a minimum **44 px** hit height. Its visual pill may retain the established 26 px in-card pill chrome, but the enclosing target must meet the 44 px accessibility convention. At large text scales, the text wraps rather than truncating the model or provider into ambiguity.

The agent-name link and model/setup control remain separate targets:

- `Task Laura` opens Agent Internals.
- The identity/setup row opens the focused setup sheet.
- A separate `This report` line, when present, is read-only and may expose provenance details.

### Adaptive states

The view model compares the live effective thinking route with the final-author route stamped on the visible report.

- **Equivalent:** render one clickable identity line. Its accessibility label states both roles: “This report and current setup use {identity}; activate to change setup.”
- **Different:** render labeled `Current setup` and read-only `This report` lines.
- **No report yet:** render only `Current setup`.
- **Legacy/unstamped report:** render `Current setup` plus `This report — attribution unavailable`. Never assume the live setup authored it.
- **Explicitly disabled:** render `No AI setup · agent paused` as a prominent clickable fix-it state.
- **Broken configured route:** render the actual fallback only when the selected setup mode permits fallback, plus a visible warning marker and text. The problem must not be disclosed only inside the sheet.
- **Background refresh:** preserve the last rendered identity with stale-while-revalidate behavior; do not flash empty or loading chrome.

Equivalence is structural, never based on names. Compare an immutable route fingerprint containing, at minimum:

- model config ID when available;
- provider-native model ID;
- serving-provider config ID when available;
- serving-provider type;
- runtime-relevant model settings that can change behavior under the same IDs.

The source profile or origin is shown in the setup sheet. It only forces a split header when it changes the effective report-producing route. Same display names through different providers are never equivalent.

### Identity copy

Provider identity is always readable text. Icons and provider accents may supplement it but never carry meaning alone.

- First-party: `Gemini 3 Pro · Google · via Gemini`
- Third-party serving layer: `Qwen 3.5 · Alibaba · via Melious.ai`
- Local: `Llama 3.3 · Meta · via Ollama (local)`
- Unknown publisher: omit the publisher rather than guessing, e.g. `Custom Model · via OpenRouter`

Do not suppress the serving provider merely because it is first-party; concise visual treatment is acceptable, but the accessible label always names it.

## Persistent setup sheet

Tapping the identity row opens `AgentModelSheet` using the app’s adaptive modal grammar. The sheet is the single switching surface used from both the summary card and Agent Internals.

The sheet contains:

1. **Current setup identity**
   - Effective thinking model, publisher when known, and serving provider.
   - Selected profile when present.
   - Visible origin: `You chose this for this agent`, `Copied from the category default when this agent was created`, `Copied from the template version`, `Legacy setup`, or `Disabled`.
   - Broken/unavailable details and a direct provider-settings fix path when appropriate.

2. **Use category default**
   - Re-reads the task’s current category and deliberately copies its current default into this agent’s setup.
   - This is not live inheritance.
   - When the category currently has no default, the result is explicit `disabled/no setup` with category origin; it must not reopen template or legacy fallback.

3. **Choose a saved setup (profile)**
   - Reuse and expose the existing profile picker content.
   - Each profile row shows its resolved thinking-model display name, publisher when known, and provider instead of a raw model ID.
   - Choosing a profile clears the direct thinking-model override because “use this bundle” must not leave a hidden override defeating it.
   - With no usable profiles, show `No profiles available on this device` and a Settings → AI action.

4. **Choose a thinking model directly**
   - Reuse `InferenceProviderModelPickerModal` and its provider-first grouping.
   - A provider is navigation/filtering, not an executable selection; the persisted choice is an `AiConfigModel.id`.
   - Filter to models capable of task-agent text/tool execution using the same capability predicate as runtime/profile configuration.
   - The profile remains the base for other capability slots; only task-agent thinking is overridden.
   - With no usable models, disable the row with an explanation instead of allowing a silent no-op.

5. **Use profile default**
   - Visible only while a direct thinking override is active.
   - Clears the override without changing the base profile or its origin.

6. **No AI setup**
   - Explicitly disables future task-agent wakes until another setup is chosen.
   - Requires clear confirmation copy.
   - The existing report remains visible and keeps its immutable attribution.

After a successful change, the header updates immediately and a toast says:

> Using {model} for every future agent update until you change it.

The toast may offer **Run now** while no wake is running. Do not automatically trigger inference. An active wake continues with the immutable route snapshot it captured when it started.

### Automatic updates

The setup sheet also contains an independent persistent **Automatic updates**
checkbox:

- checked: task changes may start the existing two-minute coalescing countdown;
- unchecked: no task-change countdown or automation-origin wake is allowed, but
  the header keeps the manual **Run now** refresh action;
- switching off clears the current countdown and removes only queued
  automation-origin jobs; a queued user Run now job is preserved;
- a wake already running finishes with its immutable route snapshot;
- switching on restores subscriptions without replaying changes received while
  off and without restoring a stale countdown.

Automation preference is independent from inference setup and lifecycle. A
typed `WakeInitiator` (`user | automation`) controls the queue policy; reason
strings are not used as authorization. The final drain path re-reads the
persisted agent policy before execution so a queued automatic wake cannot race
past the switch. When no profile/model is selected, both automatic and manual
wakes are blocked and the header shows the visible `No profile selected` error.

## Configuration model

### New typed setup

Add a nullable typed setup to `AgentConfig` rather than continuing to overload `profileId == null`:

```text
AgentInferenceSetup? inferenceSetup

null
  Legacy agent. Preserve the existing resolver unchanged until the setup is
  explicitly edited or migrated.

configured
  baseProfileId?
  thinkingModelOverrideId?   // AiConfigModel.id, never providerModelId
  origin                     // user | categorySnapshot | templateSnapshot
  originEntityId?

disabled
  origin                     // user | categorySnapshot
  originEntityId?
```

New task-agent creation resolves and snapshots an initial setup explicitly:

1. profile/model selected in the creation flow;
2. copied category default;
3. copied active template-version/template profile when deliberately configured there;
4. otherwise `disabled`.

For a new typed setup, resolution is:

1. explicit `disabled` → no inference and no fallback;
2. resolvable direct thinking-model override;
3. thinking slot from `baseProfileId`;
4. unresolved/broken setup → visible error, not an unrelated template/legacy model.

Legacy `AgentConfig` values retain the existing profile/template/model fallback until the user edits them. The edit flow shows the resolved legacy source before converting it to the typed setup.

### Origin axes remain separate

Do not mutate profile/setup origin when setting or clearing a thinking-model override. If audit needs the override’s origin, store it separately. In particular, pinning a model must not erase the truth that the base profile was copied from a category.

### Mixed-version sync safety

An older client may deserialize and rewrite `AgentConfig` without the new typed field. Explicit disabled mode must not silently become the legacy fallback chain.

Use a compatibility-safe invariant:

- entering explicit `disabled` atomically stores the setup and moves the agent to the existing `AgentLifecycle.dormant`, which older clients already honor when scheduling wakes;
- selecting a valid configured setup stores it before reactivating a dormant agent;
- current clients refuse to reactivate an inference-disabled agent without first writing a valid setup;
- sync/version capability checks and tests must cover an older-client-style rewrite that drops unknown setup JSON;
- if the existing lifecycle invariant is insufficient under real mixed-version sync, gate `No AI setup` until all participating nodes advertise the new setup capability rather than shipping a state that can silently run.

## Shared detailed resolution

Add `ProfileResolver.resolveDetailed(...)` and make the existing `resolve(...)` a thin compatibility wrapper.

The detailed result contains:

```text
ResolvedAgentSetup
  status                    // resolved | disabled | broken | legacyUnknown
  effectiveProfile?
  thinkingRoute?
  source                    // directModel | baseProfile | legacy tiers
  setupOrigin?
  brokenSelection?
  routeFingerprint?
```

Both the wake path and the header provider consume this result. No UI-side reimplementation of precedence is allowed.

At wake start, resolve exactly once and create an immutable `InferenceRunSnapshot`. Pass that snapshot through:

- conversation execution;
- compaction;
- optional report editing;
- usage recording;
- report persistence.

A setup change during an active wake must not alter the running request or its provenance stamp.

## Model publisher and serving-provider identity

Add optional structured publisher metadata to `AiConfigModel` (for example `publisherName` or a documented publisher identifier plus localized display mapping).

- Populate it from curated models and trustworthy catalog metadata at import/seed time.
- Custom or unrecognized models keep it null.
- Do not infer publisher from arbitrary display names at render time.
- Snapshot publisher display identity into report provenance so later catalog/config changes do not rewrite history.

The serving provider continues to come from the concrete `AiConfigInferenceProvider` selected by the resolved model row. The header and provenance details show both identities when useful.

## Immutable report provenance

### Staged provenance, not a single model stamp

Use the existing `AgentReportEntity.provenance` map with a versioned, typed carrier:

```text
ReportInferenceProvenance v1
  runKey
  threadId
  setupSource
  setupOrigin
  profileSnapshot?
  executor                 // immutable InferenceRouteSnapshot
  finalizer?               // only when another model was invoked
  finalizerOutcome?        // accepted | rejected | failed
  finalContentAuthor       // executor | finalizer
  routeFingerprint

InferenceRouteSnapshot
  modelConfigId?
  providerModelId
  modelName
  publisherName?
  servingProviderConfigId?
  servingProviderType
  servingProviderName
  relevantRuntimeSettings
```

Rules:

- If the executor’s report is persisted, it is the final author.
- If the Qwen report editor’s revision is accepted and replaces the draft, Qwen is the final author and the executor is retained as the analysis/draft contributor.
- Rejected or failed editor attempts are audit data only and must not receive authorship.
- Never store API keys, authentication headers, or base URLs.
- Names are denormalized deliberately so attribution survives provider/model rename or deletion.
- Historical reports without this stamp show attribution unavailable. Do not backfill from current config or the lossy live tiers of `modelIdForThreadProvider`.

The collapsed header uses `finalContentAuthor`. Expanded provenance details may say, for example:

> Analysis and draft by Mistral Small 4 via Melious.ai; final report by Qwen 3.5 via Melious.ai.

Stamp task-agent reports and task-agent compaction summaries in v1. Project/event/day agent report writers are fast-follow users of the same carrier.

## Design-system implementation

- Extract the existing in-card pill chrome into a shared `AiCardPill` before adding another copy.
- Keep colors, spacing, radii, typography, and motion on existing design-system tokens.
- Provider accents/icons supplement visible text and are never the sole identity signal.
- The current-setup row uses a 44 px minimum target, keyboard focus, hover state, tooltip/long-press details, and a complete semantics label.
- The read-only report attribution line is not styled like an editable control.
- `TldrHeader` remains Riverpod-free by accepting composed identity widgets/view data from `AiSummaryCard`.
- The Agent Internals profile section opens the same setup sheet and renders the same resolved identity/origin; do not maintain a second switching implementation.

## Mobile and accessibility strategy

- The identity region stays below the current header `Wrap`; operational controls retain their current layout behavior.
- In the equivalent steady state, only one identity row is rendered.
- In the mismatch state, labels and values wrap naturally on narrow cards.
- At 200% text scale, model, publisher, and provider remain textually discoverable; ellipsis may shorten secondary profile/origin detail but not erase identity.
- Screen-reader copy distinguishes `This report`, `Current setup`, and the combined-equivalent state.
- Provider color/icon is decorative when adjacent text already names the provider.
- Setup changes and failures are announced through semantics/toasts.
- Initial/background async refresh preserves the last rendered identity.

## Implementation sequence

1. **Model and setup types**
   - Add optional structured model publisher metadata.
   - Add `AgentInferenceSetup`, modes, and origin types.
   - Regenerate Freezed/JSON code.
   - Test old JSON compatibility, unknown enums, configured/disabled round-trips, and identifier spaces.

2. **Detailed resolver and immutable run snapshot**
   - Implement typed-setup resolution and legacy compatibility wrapper.
   - Add structural route fingerprints.
   - Resolve once at wake start and pass the snapshot through the workflow.
   - Test direct override, base profile, every legacy tier, disabled, broken/deleted configs, provider failure, and mid-wake config changes.

3. **Service writes and lifecycle safety**
   - Replace narrow profile mutation with one sync-aware `updateAgentInferenceSetup` operation.
   - Preserve convenience wrappers only when they delegate to that operation.
   - Implement profile selection, direct thinking-model selection, clear override, category recapture, and explicit disabled.
   - Atomically coordinate disabled mode with `AgentLifecycle.dormant`.
   - Add domain-log entries with old/new resolved identity and independent origins.
   - Test mixed-version-style rewrites and dormant/reactivation ordering.
   - Persist automatic-update preference independently, selectively remove
     automation jobs, and restore subscriptions without countdown replay.

4. **Contributor-aware report provenance**
   - Add the typed v1 carrier over the existing provenance map.
   - Stamp executor, editor outcome, final author, profile/source, publisher, provider, and route fingerprint from the immutable run snapshot.
   - Test accepted/rejected/failed editor outcomes and config changes during a wake.

5. **Header identity view model**
   - Compose current detailed resolution and latest report provenance.
   - Compute structural equivalence.
   - Preserve last data during refresh.
   - Test equivalent, different, no-report, unstamped, disabled, broken, deleted, and same-name/different-provider states.

6. **Header UI**
   - Extract `AiCardPill`.
   - Add combined and split identity states below the existing control `Wrap`.
   - Always render provider as text; include publisher when known.
   - Add warning state for broken selections.
   - Test independent hit targets, 44 px geometry, keyboard/semantics, 200% text scale, and 360/400/desktop widths.

7. **Persistent setup sheet**
   - Refactor profile-picker content for reuse and enrich its rows.
   - Add category recapture, profile selection, model selection, profile-default reset, and explicit disabled.
   - Handle zero-profile, zero-model, one-model, stale config, save failure, and cancelled nested-picker paths.
   - Add persistent-success toast and optional Run now action.

8. **Report attribution details**
   - Show a concise expanded-report attribution line and full staged provenance in report history/internals.
   - Keep the collapsed split header driven by final-author provenance.
   - Show attribution unavailable for unstamped reports.

9. **Localization, docs, and visual QA**
   - Add all user-visible copy to every required ARB file with the repository’s informal/formal conventions.
   - Run `make l10n` and `make sort_arb_files`.
   - Update `lib/features/agents/README.md` and `lib/features/ai/README.md` with resolution, lifecycle, and provenance diagrams.
   - Add a user-visible CHANGELOG entry under the current version and the matching Flatpak metainfo entry.
   - Capture light/dark screenshots for equivalent, mismatch, disabled, broken, and running states at phone and desktop widths.
   - Run formatter, targeted tests, and analyzer with zero warnings.

## Required test matrix

- New configured setup: base profile only, direct model only, and both.
- Profile selection clears the direct override; clearing the override preserves profile origin.
- Category recapture copies the current category default.
- Category recapture with no default produces disabled, never template fallback.
- Explicit disabled prevents manual, scheduled, and trigger-driven wakes.
- Automatic updates off prevents subscription/creation/scheduled automation
  wakes, clears countdown state, preserves Run now, and never replays missed
  changes when re-enabled.
- A final drain guard rejects an automation job queued before the preference
  changed, while preserving a queued user job.
- Legacy agents retain current behavior until edited.
- Older-client-style config rewrite cannot silently wake an explicitly disabled agent.
- Deleted override/profile/provider states are visible and deterministic.
- One immutable wake-start route is used even when setup changes mid-run.
- Executor-authored report attribution.
- Accepted editor-authored report attribution with executor retained as contributor.
- Rejected/failed editor remains audit-only.
- Current/report structural equivalence collapses to one line.
- Same display name through another provider remains split.
- Unknown/partial/unstamped provenance never collapses against live config.
- Header/source state survives background refresh without flashing.
- Profile/model pickers cover empty, single-candidate, multiple-provider, cancel, and save-failure paths.
- Accessibility covers 44 px targets, keyboard use, complete semantics, and 200% text scale.

## Localization concepts

Exact key names may follow existing conventions, but the localized concepts must include:

- `Current setup`
- `This report`
- combined-state semantics: `This report and current setup use {identity}. Activate to change setup.`
- `Attribution unavailable`
- `Model unavailable`
- `No AI setup · agent paused`
- `Use category default`
- `No category default configured — this will pause the agent`
- `Choose a saved setup`
- `Choose a thinking model`
- `Use profile default`
- `No AI setup`
- `Copied from the category default when this agent was created`
- `Copied from the {template} template version`
- `You chose this for this agent`
- `Using {model} for every future agent update until you change it`
- `Run now`
- `Automatic updates`
- `Automatic updates off`
- `Only Run now updates this report. No countdown is scheduled.`
- `No profile selected`
- `Analysis and draft by {model}; final report by {finalizer}`
- `via {provider}`
- `local`

Do not build translated sentences by concatenating English fragments; provide combined parameterized messages where grammar requires them.

## v1 scope and explicit deferrals

### v1

- Adaptive equivalent/split header identity.
- Visible model, optional publisher, and serving provider.
- Persistent profile selection and direct thinking-model override.
- Category-default recapture and explicit disabled mode.
- Typed setup with legacy compatibility and lifecycle safety.
- Shared detailed resolution and immutable wake-start snapshot.
- Contributor-aware task-report provenance and final-author attribution.
- Unified setup sheet from header and Agent Internals.
- Persistent automatic-update checkbox with manual Run now preserved.
- Required localization, documentation, tests, and screenshot QA.

### Deferrals

- Live category-default inheritance. Category defaults remain deliberate creation/reset snapshots.
- Per-capability overrides beyond task-agent thinking.
- Provider-only persistence; provider stays a picker grouping because a provider without a model is not executable.
- One-off “boost this run” controls.
- Historical attribution backfill.
- Provider/vendor logo assets beyond existing design-system visuals.
- Project/event/day report stamping beyond adopting the shared carrier as a fast-follow.
- Formal undo beyond selecting the previous setup again.

## Risks and mitigations

1. **False report authorship** — mitigated by staged provenance and explicit final-author outcome from the report-editor path.
2. **UI/runtime drift** — mitigated by one `resolveDetailed` result and one wake-start snapshot used throughout execution and persistence.
3. **Identifier-space confusion** — mitigated by explicit `modelConfigId`, `providerModelId`, and `providerConfigId` names and tests.
4. **Model publisher confusion** — mitigated by structured optional metadata and never guessing unknown publishers at render time.
5. **Serving-provider invisibility** — mitigated by always-visible text; dots/icons are supplemental.
6. **Header density** — mitigated by collapsing to one row when authoritative routes are equivalent and splitting only when truth differs.
7. **Silent broken fallback** — mitigated by explicit typed modes, visible warnings, and no unrelated fallback for new configured setups.
8. **Disabled state reactivated by old clients** — mitigated by the existing dormant lifecycle invariant plus sync capability validation/gating.
9. **Mid-wake setup change misattributes output** — mitigated by immutable resolution at wake start.
10. **Category-default ambiguity** — mitigated by past-tense copy semantics and explicit recapture behavior.
11. **Unstamped history fabrication** — mitigated by `Attribution unavailable`; no live-config inference or backfill guesses.
12. **Automation-off race** — mitigated by typed wake initiators, selective
    queue removal, early subscription gates, and a persisted-policy drain guard.

## Approval gate

Implementation may proceed only if the delivered UI and data path preserve all of these:

- a user can identify model and serving provider from the collapsed card;
- setup changes are persistent until changed again;
- current setup and report history cannot be confused during divergence;
- final visible report authorship is correct for executor/editor pipelines;
- explicit no-setup stops inference without legacy fallback;
- source/origin remains truthful;
- unknown or deleted data is labeled, not guessed;
- runtime and UI resolve through the same code;
- all targeted tests pass and analyzer reports zero warnings.
