# Task-agent model identity, quick-switch & provenance

**Date:** 2026-07-12 · **Branch:** `feat/task_agent_model_selection` · **Status:** plan approved, not implemented.

**Process:** 5-expert panel (interaction/UX, information architecture, AI-product/trust, design-system steward, systems/data-model), each proposed a full plan against a verified architecture brief; synthesized into one plan; scored review round: **AI-product 9, UX 7.5, IA 7.5, design-system 7** (systems review not completed — its lens is embedded in decisions 4–6 and risks 1–3, independently verified against the code). This document is the revision that resolves **every mustFix** from that round plus the cheap nice-to-haves; all `file:line` references verified on `main` (= this branch's HEAD).

## Summary

Add a tappable **model identity line** to the AI summary card header — provider-accent dot + human model name ("● Gemini 3 Flash ⌄") — showing the *effective thinking model the next wake will use*, resolved by the exact same code path as the wake itself. Tapping it opens a Wolt **`AgentModelSheet`** (the app-wide selector grammar) that shows the current identity + a labeled origin line, lets the user switch profiles (reusing the existing profile picker content with upgraded rows), and lets them **pin a specific thinking model** for this agent (reusing `InferenceProviderModelPickerModal`). Past-output provenance is solved by stamping denormalized model/provider/profile identity into the existing `AgentReportEntity.provenance` map at report creation (schema-change-free, synced) and rendering a quiet "Written by …" caption under the expanded report.

Data model: two additive nullable fields on `AgentConfig` (`thinkingModelOverrideId`, `profileIdOrigin`) — sync/backward compatible. Resolution gains one seam: `ProfileResolver.resolveDetailed(...)` returning the resolved profile **plus which tier won and whether a pin is broken**; both the wake path and the new UI provider consume it, so header truth == runtime truth by construction.

Non-negotiable 1 (identity obvious without internals) → the always-visible identity line. Non-negotiable 2 (change from the header) → line → sheet → profile swap (2 taps) or model pin (3–4 taps). Provenance → origin line (config) + report footer stamp (past output). Category defaults stay the default mechanism, untouched.

## Key decisions

1. **Lead with the model display name; serving provider = accent dot + "via X" detail.** The brain vendor the user cares about (Google/Meta/GLM/Qwen/Mistral) lives only in `AiConfigModel.name`; the provider enum is the serving pipe. `aiProviderAccent` deliberately gives OpenRouter/Nebius/Mistral neutral accents ("never impersonate"), so the name must carry identity.
2. **Placement: a dedicated identity row *below* the header `Wrap`, outside its run negotiation** *(revised per design-system mustFix)*. The original "third line inside the leading column" spec provably flipped 390–470 px cards from single-run to two-run headers whenever the countdown was visible (a ~145 px pill widens the leading block past the width budget), with the flip depending on model-name length — data-dependent header-height jitter, exactly what the fixed `_controlsRowHeight` (`tldr_section_part.dart:52-58`) exists to prevent. The identity row renders full-width under the title/controls `Wrap`, indented `34 + step3` px to align with the title column, so the `Wrap`'s single-run/two-run outcome is unchanged from today at every width. Header growth: exactly one 36 px row + `step1` gap, statically.
3. **Geometry** *(revised per UX mustFix)*: 26 px visual pill (the in-card pill grammar) wrapped in an `InkWell` with 5 px symmetric vertical hit padding → **36 px hit height**, full row width tappable. The agent-name link (`tldr_section_part.dart:99`, `HitTestBehavior.opaque`) sits in the `Wrap` above; the identity row is structurally outside it, so the hit regions cannot overlap. A widget test at 360 px asserts the pill and the agent-name link are independently hittable.
4. **Pill chrome: extract shared `AiCardPill`** from the 3 copy-pasted 26 px pills (`_ThinkingPill`/`_ReadMorePill`/`_OpenInternalsPill`) before adding a 4th copy. `DsPill` governs surfaces *outside* the card; inside, the aiCard pill chrome (accentSoft fill, `ai.border`, caption label) is the established grammar. Promote the inherited magic numbers (height 26, radius 13 = height/2, hPadding 10, left-6 inter-pill gap) to named constants documenting their relationship to `DsPill`'s token anatomy. Brand accents appear **only as an 8 px dot**, never as fills — and the dot is **omitted when `aiProviderAccent` resolves to the neutral fallback** (OpenRouter, Nebius, Mistral, …): a neutral dot inside an already-teal card carries zero identity; dot = brand signal only. New helper `aiProviderHasBrandAccent(type)` beside `aiProviderAccent`.
5. **New field `thinkingModelOverrideId`, never reuse legacy ids.** `AgentConfig.modelId` is non-nullable with a live default (`agent_config.dart:16`), holds a provider-native id while the picker returns `AiConfigModel.id` (a different id-space) — and, critically, **the resolver never consults it**: the legacy tier is `version.modelId ?? template.modelId` (`profile_resolver.dart:46`). The new field's doc comment states both facts so nobody wires `AgentConfig.modelId` into the chain. Not to be confused with `AiConfigInferenceProfile.pinnedHostId` (host pinning — same word, unrelated concept).
6. **Keep creation-time copy of the category default; add an origin marker (`profileIdOrigin`); do NOT switch to live resolution.** Live resolution creates cross-version split-brain on synced agents and threads category context into the wake path. Deferral hook: live inheritance later becomes a new explicit enum value, never a reinterpretation of nulls. Because the copy is creation-time, **all origin labels use past-tense copy phrasing** ("Copied from …"), never present-tense inheritance claims *(IA mustFix)*.
7. **Resolver API: `resolveDetailed`** returning `(profile, source tier, pinBroken)`; `resolve` becomes a thin wrapper so existing callers are untouched. This is the single anti-drift seam; a UI-side re-implementation of the chain is the failure mode to reject in review.
8. **The unresolved state is two states, honestly labeled** *(IA mustFix)*: `ModelSelectionSource.unresolvedBroken` — something IS configured but fails to resolve (deleted model config, unconfigured provider) → pill "Model unavailable"; vs `ModelSelectionSource.unresolvedEmpty` — the chain is genuinely empty (near-unreachable today: `AgentTemplateEntity.modelId` is required non-nullable, `agent_domain_entity.dart:431`) → pill "No model set". Different truths, different fix-it paths: the sheet names what was set and why it failed ("configure a provider" vs "pick a model").
9. **Choosing a profile clears the pin**: a bundle choice means "use the bundle"; a surviving stale pin would silently defeat it. Sheet copy states this. Pin state is visible as a pin glyph on the identity line + "Pinned" badge in the sheet.
10. **Broken pin never bricks a wake**: resolver falls back to the profile chain and flags `pinBroken`; the line then shows the *actual* effective model (same resolver feeds display) with the sheet surfacing "Pinned model unavailable".
11. **Report footer only in the expanded body**; the collapsed card stays clean. The one config-vs-record ambiguity window (user switched, wake hasn't run) is additionally covered by a **discrepancy-only tooltip segment**: when the newest report's stamped model ≠ current effective model, the pill tooltip gains "Last update by {model}" (tooltip only — zero steady-state clutter).
12. **Unstamped historical reports get no attribution line.** Tiers 3–4 of the existing `modelIdForThread` reconstruction (`agent_query_providers.dart:381-462`) consult live config and would fabricate. Omitting beats guessing. (A tier-1-only "Recorded model: {id}" reduced-confidence caption is an explicit deferral.)
13. **Toast with "Run now" action after a change; no automatic wake.** A change never burns tokens unasked; "I need horsepower now" is one more tap (`ToastAction` verified, `design_system_toast.dart:52`; wired to `triggerReanalysis`). The "Run now" action is suppressed while a wake is already running. Origin becomes a **required** parameter on every service method that touches `profileId` (compiler-enforced label integrity).
14. **`aiProviderIsServingLayer(type)`**: deterministic first-party set {gemini, anthropic, openAi, mistral, alibaba} suppresses the redundant "via Google" qualifier; serving layers (openRouter, nebiusAiStudio, genericOpenAi, ollama, …) show "via {provider name}" (for Ollama this doubles as the privacy/local signal). The doc comment states the rule — *first-party = the vendor serves only its own models* — and enumerates the reasoning for the non-obvious types (melious, omlx, genericOpenAi) so membership is a decision, not a fall-through accident. Sheet/tooltip only; the header line is dot + name.
15. **v1 stamps task-agent reports and compaction summaries** (the compactor runs with the wake's resolved model, `task_agent_execute.dart:140-147`, same `resolvedProfile` in scope — near-zero marginal cost). Project/event agent report writers are a named fast-follow.
16. **Profile/pin changes write a domain-log entry** with origin and old→new model names (the service methods already write domain logs) — the toast is ephemeral; "why did the model change on March 3" gets a durable answer in the internals Activity log for free.

## Header identity display

**What:** the effective thinking model's display name (`AiConfigModel.name`) — for task agents "the model ≈ the profile's thinking slot" (wakes consume only that slot, `task_agent_execute.dart:117-118`).

**Widget:** `ModelIdentityPill` in new file `lib/features/agents/ui/ai_summary_card/model_identity_pill.dart` — framework-free, props: `modelName`, `providerAccent` (nullable → no dot), `isPinned`, `unresolvedKind` (none/broken/empty), `onTap`, `semanticsLabel`, `tooltip`. Built on the extracted `AiCardPill` (`lib/features/agents/ui/ai_summary_card/ai_card_pill.dart` — pure visual extraction, byte-identical rendering for the three existing pills, named constants). Anatomy: optional 8 px leading dot in `aiProviderAccent(providerType, tokens)` (omitted when `!aiProviderHasBrandAccent(type)`) → optional 12 px `Icons.push_pin_rounded` when pinned → model name in caption typography, `ai.accent`, `maxLines: 1`, ellipsis → trailing 14 px `Icons.unfold_more_rounded` in `ai.accent` (the "this is a picker" signal; dot + caret never truncate). Tooltip / long-press: "Gemini 3 Flash · via OpenRouter · Profile: Balanced — tap to change" (+ discrepancy segment per decision 11; long-press reachability on touch covered by an explicit test).

**States:**
- **Resolved:** dot + name + caret.
- **Pinned:** pin glyph added.
- **Model unavailable** (`unresolvedBroken` — something set, resolution failed): muted variant (`DsDashedBorder`-style dashed `ai.border`-toned border — reuse the existing `DsDashedBorder` component, as `DsPill`'s muted variant does — `ai.metaText` italic label) "Model unavailable" — tappable; the sheet names the broken entry and the fix ("provider not configured" / "model was deleted").
- **No model set** (`unresolvedEmpty` — chain genuinely empty): same muted chrome, label "No model set"; the sheet's fix-it path is picking a profile/model.
- **Broken pin:** resolver fell back — the line shows the actual effective model (not the dead pin); the sheet discloses the broken pin.
- **Loading / background refresh:** provider retains last value (`valueOrNull` discipline the card already uses); the row is simply absent until first value. Never flashes.
- **While running:** stays enabled; an in-flight wake continues on the old model and the change applies at the next resolve (the toast copy already says so); the toast's "Run now" action is suppressed while running.

**Wiring:** `TldrHeader` gains an optional `Widget? modelIdentityPill` slot (the existing `playbackControl` slot pattern — header stays Riverpod-free), rendered as a **dedicated full-width row below the title/controls `Wrap`** (decision 2), indented `34 + tokens.spacing.step3` to align with the title column, `tokens.spacing.step1` top gap, 36 px hit height (decision 3). The agent-name link (muted caption → internals) and the identity line (bordered pill → sheet) are visually distinct affordances on separate rows.

**Data feed:** new `lib/features/agents/state/agent_model_identity_provider.dart` — `agentModelIdentityProvider` (`FutureProvider.autoDispose.family<AgentModelIdentity, String>`), composing existing seams: `agentIdentityProvider(agentId)` → `templateForAgentProvider` / `activeTemplateVersionProvider` → `ProfileResolver.resolveDetailed`. Watches the aiConfig update stream so renames/switches refresh instantly. View model `AgentModelIdentity` in new `lib/features/agents/model/agent_model_identity.dart`: `{AiConfigModel? model, AiConfigInferenceProvider? provider, AiConfigInferenceProfile? profile, ModelSelectionSource source, AgentProfileIdOrigin? profileIdOrigin, bool isPinned, bool pinBroken}`.

## Change affordance & flow

**Tap target:** the identity line. One affordance carries "what is it" and "change it" — nothing added to the trailing control cluster.

**Flow — `AgentModelSheet`** (new file `lib/features/agents/ui/agent_model_sheet.dart`), opened via `ModalUtils.showSinglePageModal` (same grammar as status/due-date/estimate sheets). The sheet is *outside* the aiCard, so normal design-system tokens apply and brand accents may breathe. Contents top to bottom:

1. **Identity block:** `aiProviderIcon` in an `aiProviderSurface` badge, model name, "via {provider}" when `aiProviderIsServingLayer(type)`, profile name (when a profile supplies the slot), `DesignSystemBadge` "Pinned" when overridden, and the **origin line** (next section). In the unresolved states this block names what was set and why it failed.
2. **Profiles section:** reuse the picker content from `lib/features/agents/ui/profile_selector.dart` (refactor `_ProfilePickerContent` so the sheet body is callable without the `InputDecorator` field). **Row upgrade:** each profile row's subtitle currently shows the raw mono `thinkingModelId` wire id (`profile_selector.dart:224`) — replace it with the resolved thinking-model *display name* + provider dot. The upgrade lands wherever `ProfileSelector` is used (internals, template detail page, category form), keeping the grain story coherent everywhere. `desktopOnly` filtering unchanged. Tap → `TaskAgentService.updateAgentProfile(agentId, profileId, origin: AgentProfileIdOrigin.userSelection)` (clears any pin) → pop → toast.
   **Empty state** *(UX mustFix)*: when zero profiles survive the `desktopOnly` platform filter (realistic on mobile even when profiles exist), render an explicit empty-state row — "No profiles available on this device" — with a CTA into Settings → AI, never an empty column.
3. **"Pin a model for this agent"** row → `InferenceProviderModelPickerModal.show(...)` (reused as-is; adaptive, branded, returns `AiConfigModel.id`), candidates filtered by the same thinking-slot predicate the profile editor uses (reasoning-capable text models from configured providers), `defaultModelId` = current effective thinking model's config id. Result → new `TaskAgentService.updateAgentThinkingModelOverride(agentId: ..., modelConfigId: ...)` → pop → toast.
   **Degraded states** *(UX mustFix)*: with zero eligible models the picker modal returns `null` without showing any UI — the row must be **disabled with an explanatory subtitle** ("No thinking-capable models configured"), never a silent no-op tap. With exactly one eligible model the picker short-circuits and pins instantly — the confirmation toast still fires so the instant pin doesn't read as a dead tap.
4. **"Use profile default"** row (only when pinned) → clears the override (1 tap to unpin).

**Feedback:** (a) the identity line re-renders immediately (provider invalidation) — primary in-place confirmation; (b) toast "Now thinking with {model} — applies to the next update" with action **"Run now"** → `triggerReanalysis` (suppressed while a wake is running); (c) no automatic wake; countdown/scheduled wake untouched — the next `ProfileResolver.resolve` simply picks up the new config; (d) domain-log entry (decision 16).

**Mental model:** profiles stay the friendly bundle (category defaults and templates keep pointing at profiles, unchanged); the pin is exactly one narrower knob — "this agent thinks with model X" — layered on top, visible as an explicit exception (pin glyph + badge) and trivially removable. Only the thinking slot is pinnable: wakes consume nothing else, so a per-slot matrix would be UI without a runtime consumer. Precedence, narrowest wins: **pin → agent profileId → version profileId → template profileId → legacy `version.modelId ?? template.modelId`**.

**Internals panel:** `_ProfileSection` (`agent_internals_body.dart:296-370`) is re-pointed to open the same `AgentModelSheet` and displays the same identity + origin line — exactly one switching surface, two entry points. (While touching it, migrate the section's `AppTheme` spacing/typography onto design tokens.)

## Provenance (current config)

**Data:** new nullable enum field on `AgentConfig`:
```dart
@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
AgentProfileIdOrigin? profileIdOrigin, // categoryDefault | userSelection
```
Enum `AgentProfileIdOrigin { categoryDefault, userSelection }` in `lib/features/agents/model/agent_enums.dart`. The unknown-enum→null pattern is proven in this file (`agent_config.dart:127`). Write sites:
- `assignCategoryDefaultTaskAgent` (`lib/logic/create/task_agent_assignment.dart:74-84`) → `categoryDefault` (via a new `profileIdOrigin` param on `TaskAgentService.createTaskAgent`, stamped at `task_agent_service.dart:109-112`);
- `AgentCreationModal` explicit pick → `userSelection`;
- `updateAgentProfile` → **required** `origin` parameter;
- `updateAgentThinkingModelOverride` → `userSelection`.

**Two provenance axes, kept distinct:**
- **Axis A — which tier won** (computed live, no storage): `ModelSelectionSource { agentPin, agentProfile, versionProfile, templateProfile, legacyModelId, unresolvedBroken, unresolvedEmpty }`, returned by `resolveDetailed`.
- **Axis B — why the agent-level profileId exists** (stored): `profileIdOrigin`.

**Display — one origin line in the sheet's identity block and in the internals `_ProfileSection`** (not on the header line; origin is a read-once "why", not a glance-level "who"). All copy is past-tense/copy-semantics — the category default is copied at creation, so present-tense "From your category default" would falsely claim a live link exactly when it matters (after the default drifts) *(IA mustFix)*:
- `agentProfile` + `categoryDefault` → "Copied from your category default when this agent was created"
- `agentProfile` + `userSelection` → "You chose this for this agent"
- `agentProfile` + `null` (legacy) → "Set when the agent was created" (honest about not knowing — no guessing)
- `versionProfile` → "From the {template} template (version snapshot)" — distinct from the template-head label because the snapshot can drift from the template's current profile
- `templateProfile` → "From the {template} template"
- `agentPin` → "Pinned on this agent"
- `legacyModelId` → "No profile set — using the fallback model"
- `unresolvedBroken` → "{what was set} can't be used — {reason}" (e.g. provider not configured / model deleted)
- `unresolvedEmpty` → "Nothing set" (per the user: "if none's set, then none's set — surface it")

## Provenance (past reports)

**Stamp at creation — the only trustworthy attribution.** Typed carrier in new file `lib/features/agents/model/report_model_provenance.dart` (mirrors the `project_agent_report_contract.dart` const-keys style):
```dart
class ReportModelProvenance {
  static const provenanceKey = 'model'; // namespaced under provenance['model']
  final String? modelConfigId;   // AiConfigModel.id
  final String providerModelId;  // wire id, e.g. models/gemini-3-flash-preview
  final String? modelName;       // "Gemini 3 Flash" — snapshot
  final String? providerType;    // InferenceProviderType.name — snapshot
  final String? providerName;    // provider config name — snapshot
  final String? profileId; final String? profileName;
  final String? selectionSource; // ModelSelectionSource.name
  // toJson() / static ReportModelProvenance? fromProvenance(Map<String,Object?>?)
  //   — tolerant of absent/partial/foreign maps
}
```
Names/types are **denormalized on purpose**: provenance is immutable truth that survives config rename/deletion — exactly where the live 4-tier `modelIdForThread` reconstruction (`agent_query_providers.dart:381-462`) goes lossy.

**Write sites:** `WakeOutputWriter.persist` (`wake_output_writer.dart:62`) gains `required ReportModelProvenance? modelProvenance`, merged into the report's `provenance` map at construction. Built in `task_agent_execute.dart` from `resolvedProfile.thinkingModel` / `.thinkingProvider` (in scope at :100/:117-118; `persist` call at :537) + the `resolveDetailed` source. Compaction summaries get the same stamp (decision 15). `AgentReportEntity.provenance` already syncs — zero schema/sync risk.

**Display:**
- **Expanded report footer** in `TldrBody`: one caption line in the aiCard meta tone — "Written by Gemini 3 Flash · via OpenRouter" ("via" suppressed for first-party providers). Meta text, not a pill — a fact, not an affordance. l10n provides a **combined key** `agentReportWrittenByVia` ("Written by {model} via {provider}") alongside `agentReportWrittenBy` ("Written by {model}") so locales aren't forced into English fragment concatenation.
- **Internals Reports history rows** get the same stamped caption when present.
- **Unstamped historical reports:** no attribution line anywhere. Never fabricate; no backfill.
- **Config vs record mismatch** (user just switched, wake hasn't run): no reconciliation UI — line = next-run config, footer = immutable record, each labeled by position; plus the discrepancy-only tooltip segment (decision 11).

## Data-model changes

All additive nullable fields with null defaults on freezed models — sync-compatible both directions (older clients drop unknown keys; newer clients read nulls). `make build_runner` after.

1. `AgentConfig` (`lib/features/agents/model/agent_config.dart`):
   - `String? thinkingModelOverrideId` — holds an **`AiConfigModel.id` (config-entity id)**. Doc comment states: (a) legacy `modelId` is a provider-native wire id — a different id-space; (b) `ProfileResolver` **never reads `AgentConfig.modelId`** — the legacy tier is `version.modelId ?? template.modelId` (`profile_resolver.dart:46`); (c) not to be confused with `AiConfigInferenceProfile.pinnedHostId` (host pinning).
   - `AgentProfileIdOrigin? profileIdOrigin` (unknown-enum → null).
2. New enum `AgentProfileIdOrigin` in `agent_enums.dart`.
3. `ProfileResolver` (`lib/features/ai/util/profile_resolver.dart`): new `resolveDetailed({agentConfig, template, version}) → ResolvedProfileDetails { ResolvedProfile? profile, ModelSelectionSource source, bool pinBroken }`. Pin handling: resolve the profile chain as today for all slots; when `thinkingModelOverrideId` is set and resolves (via `resolveInferenceProviderForProfileSlot` — it already takes config-entity ids, `inference_provider_resolver.dart:163`), substitute the thinking slot; if the pin can't resolve, log, fall back to the chain, set `pinBroken`. If the chain is unresolvable but the pin resolves, the pin supplies a thinking-only `ResolvedProfile` (like the legacy path). Distinguish `unresolvedBroken` vs `unresolvedEmpty` (decision 8). `resolve` becomes a thin wrapper — existing callers untouched. `ModelSelectionSource` + `ResolvedProfileDetails` live beside `ResolvedProfile` in `lib/features/ai/model/resolved_profile.dart`.
4. `TaskAgentService`: new `updateAgentThinkingModelOverride({required String agentId, required String? modelConfigId})` (null clears; stamps `profileIdOrigin: userSelection`; copyWith + `syncService.upsertEntity` + domain log with old→new names, mirroring `updateAgentProfile`); `updateAgentProfile` gains required `origin` and clears the pin; `createTaskAgent` threads `profileIdOrigin`.
5. New value types (not persisted): `AgentModelIdentity`; `ReportModelProvenance`.
6. New utils in `ai_provider_visual.dart`: `aiProviderIsServingLayer(type)` (documented membership rule, decision 14) and `aiProviderHasBrandAccent(type)` (decision 4).
7. **No changes** to `AgentReportEntity` schema, category defaults, templates, `WakeTokenUsageEntity`, or the wake-run table. No Drift migrations.

## Mobile strategy

- The identity row lives **below the header `Wrap`, outside its run negotiation** — the trailing 44 px control cluster (play, refresh, countdown, ×, Read more; at capacity at 360 px) gains nothing and the `Wrap`'s single-run/two-run outcome is byte-identical to today at every width (decision 2).
- The row spans the card's content width minus the title-column indent; the label ellipsizes ("Gemini 3 Fl…" still names the vendor — model names front-load the brand); dot + caret never truncate, so "it's a picker" survives any width.
- Header grows one 36 px row + `step1` gap, statically (no reflow jitter; provider retains last value).
- No width-conditional semantics: mobile and desktop show the same information; "via X" + origin live in the sheet at every width.
- All change flows are bottom sheets (Wolt), the app's mobile-native selector pattern; `InferenceProviderModelPickerModal` is already adaptive; long-press surfaces the tooltip content on touch (tested).
- Verify with the scratch screenshot harness at 360 / 400 / desktop widths, light + dark (recipe below) — harness never committed.

## Implementation steps (ordered)

1. **Data layer:** `AgentProfileIdOrigin` enum; `AgentConfig` fields; `ModelSelectionSource` + `ResolvedProfileDetails` in `resolved_profile.dart`; `make build_runner`. Tests: `agent_config_test.dart` (round-trip, old-JSON back-compat, unknown-enum → null).
2. **Resolver:** `ProfileResolver.resolveDetailed` + pin substitution + `pinBroken` + broken/empty split; `resolve` as wrapper. Tests: `profile_resolver_test.dart` (pin wins, broken pin falls back + flags, tier reporting for every chain permutation incl. `unresolvedBroken` vs `unresolvedEmpty`).
3. **Service:** `updateAgentThinkingModelOverride`; `updateAgentProfile` origin param + pin clearing; `createTaskAgent` origin threading; stamp `categoryDefault` in `task_agent_assignment.dart`, `userSelection` in `AgentCreationModal`; domain-log entries. Tests: `task_agent_service_test.dart`.
4. **Report stamping:** `ReportModelProvenance`; `WakeOutputWriter.persist` param; build the stamp in `task_agent_execute.dart` (reports + compaction summaries). Tests: `report_model_provenance_test.dart`, `wake_output_writer_test.dart` (stamp lands under `provenance['model']`, absent when null).
5. **Identity provider:** `agent_model_identity_provider.dart` + `AgentModelIdentity`. Tests: precedence matrix incl. pin/broken-pin/both unresolved kinds, origin combinations, reactivity to config changes.
6. **Pill:** extract `AiCardPill` (byte-identical rendering of the three existing pills, named constants); `ModelIdentityPill`; `TldrHeader` identity-row slot; connector wiring in `ai_summary_card.dart`; `aiProviderIsServingLayer` + `aiProviderHasBrandAccent`. Tests: `ai_card_pill_test.dart`, `model_identity_pill_test.dart` (all states, dot for gemini vs NO dot for openRouter, pin glyph, muted broken/empty variants, tap callback, semantics, tooltip long-press), `tldr_section_part_test.dart` extensions (slot rendering; 360 px test asserting pill + agent-name link independently hittable and `Wrap` run count unchanged; long-name ellipsis), `ai_provider_visual_test.dart` (serving-layer + brand-accent sets).
7. **Sheet:** refactor `profile_selector.dart` to expose the picker content + upgraded rows (display-name + provider-dot subtitle replacing the raw wire-id subtitle); `agent_model_sheet.dart`; toast + "Run now" action (suppressed while running); re-point internals `_ProfileSection` (+ token migration). Tests: `agent_model_sheet_test.dart` (profile switch calls service with origin + clears pin, pin flow, unpin, all origin-line variants, cancelled picker = no state change, **zero-profiles empty state with Settings CTA**, **zero-models disabled pin row**, one-model instant-pin toast, toast Run-now triggers reanalysis), `profile_selector_test.dart` extensions, internals-body test extensions.
8. **Report footer:** caption in `TldrBody` + internals history rows; unstamped → absent; combined-key rendering. Tests in `tldr_section_part_test.dart` / report-history test file.
9. **l10n:** keys below in all 6 arb files (informal tone; Romanian formal); `make l10n` + `make sort_arb_files`.
10. **Docs & polish:** `lib/features/agents/README.md` — Mermaid flowchart of the resolution chain (pin → agent profile → version profile → template profile → legacy `version.modelId ?? template.modelId`) + provenance stamping flow; CHANGELOG under current pubspec version + `flatpak/com.matthiasn.lotti.metainfo.xml`; `dart-mcp.analyze_files` zero warnings; `fvm dart format .`; screenshot pass at 360/400/desktop, light + dark.

## l10n (~18 new keys × 6 arb files)

`aiCardModelPillNoModel` "No model set" · `aiCardModelPillUnavailable` "Model unavailable" · `aiCardModelPillTooltip` "{model} · Profile: {profile} — tap to change" · `aiCardModelPillLastUpdateBy` "Last update by {model}" · `agentModelSheetTitle` "Model & profile" · `agentModelViaProvider` "via {provider}" · `agentModelSheetPinnedBadge` "Pinned" · `agentModelSheetPinModel` "Pin a model for this agent" · `agentModelSheetPinModelEmpty` "No thinking-capable models configured" · `agentModelSheetRemovePin` "Use profile default" · `agentModelSheetProfilesSection` "Profiles" · `agentModelSheetProfilesEmpty` "No profiles available on this device" (+ CTA label reusing existing settings key if present) · origin lines `agentModelOriginCategoryDefault` ("Copied from your category default when this agent was created"), `agentModelOriginUserSelected`, `agentModelOriginLegacyCreation`, `agentModelOriginTemplate`, `agentModelOriginTemplateVersion` ("From the {template} template (version snapshot)"), `agentModelOriginPinned`, `agentModelOriginLegacyFallback`, `agentModelOriginNothingSet` · `agentModelChangedToast` "Now thinking with {model} — applies to the next update" · `agentModelChangedToastRunNow` "Run now" · `agentReportWrittenBy` "Written by {model}" · `agentReportWrittenByVia` "Written by {model} via {provider}" · `agentModelPinUnavailable` "Pinned model unavailable — using the profile instead". Reuse existing `aiProvider*Name`, `aiModelPicker*` keys.

## v1 scope & deferrals

**v1 (smallest coherent):** everything in Implementation steps — identity line + provider + `resolveDetailed` (non-negotiable 1); sheet with profile swap + model pin + unpin + empty/degraded states + toast/Run-now (non-negotiable 2); origin marker + origin line (provenance, config half); report + compaction stamp + expanded footer + history captions (provenance, past half); profiles-stay-the-bundle + thinking pin; category defaults untouched.

**Explicit deferrals:** live category-default inheritance (future opt-in enum value, never null-reinterpretation) · "Use category default" CTA + staleness comparison in the sheet · structured brain-vendor taxonomy / vendor logo assets · tier-1-only "Recorded model: {id}" caption for unstamped reports; any backfill · provenance stamping for project/event agents (same stamp helper, fast-follow) · conversation-log model-name upgrade · "boost next wake" / `thinkingHighEndModelId` affordance · per-slot overrides beyond thinking · provider-level access as a concept · config-vs-record mismatch badge beyond the tooltip segment · formal undo.

## Risks

1. **Id-space confusion** (config id vs provider-native wire id) — highest-likelihood bug class; mitigated by field doc comments (decision 5), typed `ReportModelProvenance`, resolver tests asserting both ids.
2. **UI/runtime resolution drift** — mitigated structurally: both consume `resolveDetailed`; the tier-parity test is the contract; bespoke UI-side chains rejected in review.
3. **LWW config clobber from stale clients** — an older client rewriting `AgentConfig` drops pin/origin. Degradation is safe (pin lost → profile chain; origin lost → "set at creation") and self-heals; accepted explicitly, flagged in PR + README.
4. **Crafted-card density regression** — one extra 36 px row in a locked design; mitigated by dot-only brand rule (with neutral-dot omission), exact pill-chrome reuse, and the screenshot pass before merge; escalate to the design panel if it reads as clutter.
5. **Deleted pinned model** — silent fallback could contradict "absolutely obvious"; mitigated by `pinBroken` surfacing in the sheet and the line always showing the actual effective model (dedicated test).
6. **Stale-identity window** — handled by labeled separation (line vs footer), "applies to the next update" toast copy, Run-now, and the discrepancy-only tooltip segment.
7. **Legacy agents misread as unset** — every template has a required non-nullable `modelId` (`agent_domain_entity.dart:431`) and the legacy tier reads `version.modelId ?? template.modelId`, so `unresolvedEmpty` is near-unreachable; a chain entry that fails to resolve must show `unresolvedBroken` ("Model unavailable"), never "No model set" (explicit test).
8. **Sheet-chaining dismissal paths** (sheet → picker modal) — cancelled picker returns cleanly with no state change (explicit test).

## Appendix: baseline screenshot harness (recipe, never committed)

Scratch test `test/_scratch_agent_header_capture_test.dart` (deleted after use): renders the real `AiSummaryCard` via `captureInApp` with the `AgentTestBench` override set (identity + template "Task Laura" + report + suggestion list + TTS fakes), `withClock(Clock.fixed(...))` for a deterministic countdown pill, `Scaffold` wrapper (avoids yellow-underline text), and an explicit-pumps variant for the running state (indeterminate spinner never settles under `pumpAndSettle`). Captures: idle/countdown/running × phone (390) / desktop (672-wide card). Run: `fvm flutter test --update-goldens test/_scratch_agent_header_capture_test.dart` → PNGs in `test/screenshots/` (gitignored).
