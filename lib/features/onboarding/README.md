# Onboarding (FTUE)

First-time-user-experience for Lotti. The goal is to guide a brand-new user to the
core "aha" — *speak a thought, watch it become a structured task* — and to lift
D3/D7/D30 retention. The full design and phased build plan live in
[`docs/implementation_plans/2026-06-21_ftue_onboarding.md`](../../../docs/implementation_plans/2026-06-21_ftue_onboarding.md).

> **Status.** **Phase 0** (measurement substrate), **Phase 1** (welcome +
> connect-your-brain front door), **Phase 2** (the live voice→task aha), the
> **auto-show trigger + re-show cadence**, and the top-level **Settings ›
> Onboarding** replay entry described below are implemented. The **D1 return
> loop** is forthcoming. The welcome is **released to everyone and has no
> config flag**: cadence and completion state are its only gates. It is the
> sole first-run setup path; the pre-FTUE `AiProviderSelectionModal` and
> `AiSetupPromptService` have been deleted. The Daily OS walkthrough remains
> in a dark launch: its flag seeds off and the prepared all-install rollout
> lever remains `false` while production testing continues (see
> [Daily OS rollout and production testing](#daily-os-rollout-and-production-testing)).

## End-to-end flow

```mermaid
flowchart TD
    L[First launch · no provider configured] -->|eligible| W[OnboardingWelcomeModal]
    L -->|budget spent / already completed| NONE[no auto-show · replay via Settings › Onboarding]
    W --> WL[welcome · hero + promise + CTA]
    WL -->|Choose your AI brain| CN[connect · provider tiles]
    WL -->|Look around first| SK[skip → onDismiss · no persistence, grace period preserved]
    CN -->|pick provider| AK[apiKey · paste + verify]
    AK -->|verified: provider + models + profile| SU[success beat]
    SU -->|Get started| RS[recording style · pick analogue / modern]
    RS -->|Continue · style persisted| CAT[category · pick life areas]
    CAT -->|≥1 area created / reused| FT[first task · in-panel capture]
    CAT -->|nothing selected| DONE[done]
    FT -->|speak / suggestion / type → structure| CARD[created beat · in-panel task card]
    CARD -->|tap the card| TASK[real in-progress TaskDetailsPage]
```

Every step — welcome through the first-task finale — lives inside **one
transparent, barrier-dismissible full-screen route** (`OnboardingWelcomeModal`).
The finale deliberately stays in the same panel (the same dialogue the user has
been in all along) instead of popping out to a full-screen takeover: when the
task lands it is revealed *inside* the panel as a glowing tappable card, and
only the user's tap on that card leaves the modal — landing on the **real**
`TaskDetailsPage`.

Every panel follows the active app theme. The route itself stays transparent;
the step widgets resolve surface, text, alert, interactive, spacing, radius,
and typography values from `context.designTokens`. The animation palette uses
the same active token set, so theme changes do not leave a dark island inside a
light app.

## Auto-show trigger & re-show cadence

`state/onboarding_trigger_service.dart` decides *when* the welcome auto-shows,
independent of the "connect your brain" front door's own step logic above.

| Piece | Role |
|---|---|
| `shouldAutoShowOnboardingProvider` | `FutureProvider.autoDispose<bool>` — mirrors `shouldAutoShowWhatsNewProvider`'s shape exactly. Read-only eligibility check. |
| `isOnboardingWelcomeEligible` | Pure predicate the provider evaluates against — no DB/Riverpod, fully unit-testable. |
| `OnboardingWelcomeCadence` | `AsyncNotifier<void>` — the mutation side: `recordShown()` and `markCompleted()`, persisted to `SettingsDb` under a private `welcome_*` key prefix (deliberately **not** a `ConfigFlags` row — those are public, user-toggleable; this is per-install bookkeeping the user never edits directly). |

**Eligibility** (all must hold):
- the one-shot existing-install backfill has resolved; configured installs are
  marked complete before cadence is read, independently of the Daily OS rollout
  lever,
- What's New has nothing unseen left to show (sequenced behind it so the two
  auto-shown overlays never race for the screen),
- the welcome has not been marked `completed`,
- the user has not yet reached the real "aha" — `OnboardingFunnelState.
  reachedRealAha`, a structured task actually landing. This graduates on real
  activation rather than a raw task-count, which a floor/failure path could
  inflate,
- it has auto-shown fewer than 4 times, and
- once shown at least once, it is still within a 14-day grace window of the
  first show.

`BeamerApp`'s `AppScreen` sequences this after What's New:
`whatsNewControllerProvider`'s unseen→seen transition invalidates the welcome
and Daily OS gates so each gets a fresh eligibility check once the What's New
modal is out of the way.

There is **no fallback prompt**. The welcome owns first-run provider setup, so
once its re-show budget is exhausted nothing auto-shows. A user who never
connects recovers via the unconditional top-level **Settings › Onboarding**
replay entry (and ordinary AI settings):

```mermaid
stateDiagram-v2
    [*] --> neverShown: fresh install
    neverShown --> shown: shouldAutoShowOnboardingProvider(true) → recordShown() → OnboardingWelcomeModal.show
    shown --> shown: cold start, budget remains → recordShown() (shown_count += 1)
    shown --> shown: onDismiss (skip) [no persistence, grace period preserved]
    shown --> retiredBudget: shown_count reaches 4
    shown --> retiredWindow: 14 days since first show elapse
    shown --> completed: provider connected → markCompleted() (welcome_completed)
    shown --> activated: OnboardingFunnelState.reachedRealAha
    retiredBudget --> [*]: gate false; replay via Settings › Onboarding
    retiredWindow --> [*]: gate false; replay via Settings › Onboarding
    completed --> [*]: gate permanently false (welcome_completed)
    activated --> [*]: gate permanently false (reachedRealAha)
```

`markCompleted` (wired to the welcome modal's `onCompleted` callback, which
fires once a provider is connected) persists `welcome_completed` and
permanently retires the gate. This is what stops the welcome re-appearing after
a user finishes setup but before any structured task has landed (so
`reachedRealAha` is still false) — without it such a user would keep seeing the
welcome until the shown-count/window cap ran out. A plain skip (`onDismiss`)
persists nothing and does **not** retire the gate: the shown-count/window
budget already implements the "show again for a while, then stop" grace
period, and a hard block on first skip would defeat that.

## Daily OS rollout and production testing

`state/onboarding_rollout.dart` keeps the future all-install Daily OS rollout
prepared without activating it. `onboardingRolloutEnabled` controls only that
Daily OS force-enable migration and is currently `false`. The Daily OS config
flag also seeds `false`; the welcome has no flag.

| Piece | Lever off (current release) | Lever on (future rollout) |
|---|---|---|
| `applyOnboardingRolloutFlags` | Returns before any database read or write. | Overwrites the Daily OS walkthrough flag to `true` once, before `runApp`, then writes `onboarding_rollout_v1_flags_applied`. |
| `applyOnboardingRolloutBackfill` | Classifies an install once; a provider-ready install gets `welcome_completed`, then `onboarding_rollout_v1_backfill_applied` is written. | Same behavior — the Welcome cleanup is independent of this lever. |
| Failure behavior | The flag migration is a no-op. A backfill failure is logged and leaves its marker absent for the next evaluation. | Either migration logs its failure, leaves the relevant marker absent, and retries later. |

The force-enable remains necessary because `initConfigFlags` uses
`insertFlagIfNotExists`: changing a seed cannot update an existing `false` row.
The startup half therefore remains awaited from `registerSingletons()` after
seeding. The independent backfill is awaited by `shouldAutoShowOnboarding`,
where a Riverpod container exists. Its readiness signal waits for agent
initialization before resolving so template/version seeding cannot produce a
false one-shot classification. The marker is deliberately outside the QA reset
set: resetting Welcome completion can expose the flow again without a connected
provider immediately retiring it a second time.

```mermaid
stateDiagram-v2
    state "Welcome cleanup" as WelcomeCleanup {
        [*] --> BackfillPending
        BackfillPending --> WelcomeRetired: existing install has a resolvable planner route
        BackfillPending --> WelcomeEligible: install is not yet configured
        WelcomeRetired --> BackfillApplied: write marker
        WelcomeEligible --> BackfillApplied: write marker
        BackfillApplied --> [*]
    }
    state "Daily OS release" as DailyOsRelease {
        [*] --> DarkLaunch: onboardingRolloutEnabled = false
        DarkLaunch --> ManualTest: tester enables config flag
        ManualTest --> DarkLaunch: tester disables config flag
        DarkLaunch --> RolloutArmed: release changes lever to true
        RolloutArmed --> FlagForced: startup force-enables Daily OS once
        FlagForced --> [*]
    }
    [*] --> WelcomeCleanup: FTUE flag removed
    [*] --> DailyOsRelease: independent rollout track
```

### Resetting test state

Settings › Advanced › Onboarding Metrics exposes **Reset onboarding test
state**. After confirmation it removes all six `welcome_*` and
`daily_os_onboarding_*` cadence keys and clears the content-free onboarding
event log. It deliberately leaves the Daily OS config flag unchanged, so a
tester opt-in remains explicit, and it never deletes real user data.

Daily OS eligibility also checks whether the planner has **ever** had a plan,
including a soft-deleted plan. The reset cannot safely erase that history. Use
a clean profile/device to retest the complete first-run Daily OS walkthrough
after any day plan has existed.

## Phase 0 — measurement substrate

The substrate is built **before** any onboarding UI so the funnel is queryable and
the retention goal is falsifiable. It records a content-free event log and derives
the funnel state from it.

### Why a dedicated store

`captureEvent`/`LoggingService` only appends to text log files, and
`UserActivityService` is in-memory — neither can answer conversion questions. So
the funnel needs a queryable store. It lives in its own Drift database
(`OnboardingMetricsDb`) rather than the heavily-shared `SettingsDb`, mirroring the
other small single-purpose DBs (`NotificationsDb`, `EditorDb`).

### Components

| Piece | File | Role |
|---|---|---|
| `OnboardingMetricsDb` | `lib/database/onboarding_metrics_db.dart` (+ `.drift`) | Append-only `onboarding_events` table + queries. **Source of truth.** |
| `OnboardingEventName` / `OnboardingFunnelState` | `model/onboarding_event.dart` | Event vocabulary + derived-state model + `onboardingDayBucket` helper. |
| `OnboardingMetricsRepository` | `repository/onboarding_metrics_repository.dart` | Records events (injected clock/id/platform) and derives funnel state. |
| `OnboardingMetricsPage` / `OnboardingMetricsBody` | `ui/onboarding_metrics_page.dart` | Debug surface under Settings → Advanced → Onboarding Metrics; renders the funnel and exposes the confirmed cadence + metrics QA reset. |

### Privacy

The event table is **content-free by construction**: it stores only event names, a
coarse UTC day bucket, and a small fixed set of low-cardinality dimensions
(`platform`, `provider`, `reason`) plus an already-bucketed integer. No transcript,
audio, or thought text is ever written.

### Derivation: event log → funnel state

```mermaid
flowchart LR
    R[recordEvent / recordAppFirstSeenIfAbsent] -->|append| T[(onboarding_events)]
    T -->|getAllEvents| D[funnelState]
    D --> S["OnboardingFunnelState<br/>installFirstSeen · activeDays · activeDaysInFirst7<br/>per-event counts · reachedRealAha · isBaselineCohort"]
    S --> U[Onboarding Metrics debug page]
```

`OnboardingFunnelState` is computed on demand from the full event log — it is never
persisted as a second store.

### Baseline cohort

`recordAppFirstSeenIfAbsent()` runs once at startup (wired in `get_it.dart`, before
any onboarding UI shows) so that **pre-FTUE users upgrading into this build are
tagged as the baseline cohort** even if they never trigger the welcome. A user is
baseline when they had existing journal data at first record (`existing_user`) or
their first launch predates `kFtueReleaseDateUtc`. This gives a clean before/after
denominator for the retention comparison.

### Telemetry

Each recorded event also emits a `LogDomain.onboarding` line (toggle under
Settings → Advanced → Logging) for grep-friendly diagnostics, independent of the
queryable store.

## Phase 1 — welcome → connect → category

A transparent full-screen route hosts a small, locally-owned step machine
(`_OnboardingFlow` in `ui/onboarding_welcome_modal.dart`). Steps crossfade with an
`AnimatedSwitcher` + `AnimatedSize`; keeping the step state local (rather than
nested routes) keeps the in-panel back buttons reliably hittable.

```mermaid
stateDiagram-v2
    [*] --> welcome
    welcome --> connect: Connect your brain
    welcome --> [*]: Look around first (skip → onDismiss)
    connect --> welcome: back
    connect --> apiKey: pick a provider
    apiKey --> connect: back
    apiKey --> success: key verified · provider + models + profile created
    success --> recordingStyle: Get started
    recordingStyle --> category: Continue · style persisted
    category --> firstTask: ≥1 area created / reused
    category --> [*]: nothing selected → done
    firstTask --> [*]: created card tapped → pop & open TaskDetailsPage
    firstTask --> [*]: total structuring failure → done
```

- **`OnboardingWelcomeModal.show`** opens the transparent `PageRouteBuilder`
  (`opaque: false`, `barrierDismissible: true`, dim barrier). Tapping the dim
  barrier closes it, matching the app's modal convention. It records the
  connect-funnel events and, once the first-task step lands a real task, pops
  the route and opens that task (`openOnboardingCreatedTask` — a deep link
  through the canonical `/tasks/:id` route, which also switches to the Tasks
  destination).
- **Native provider creation.** Unlike a settings deep-link, the flow creates the
  provider **in place**: `OnboardingApiKeyPanel` runs the existing per-provider
  FTUE setup (`runFtueSetupForType` → `performXxxFtueSetup`), which creates the
  provider, ensures its known **models** exist, and seeds the provider's
  inference **profile** (profile seeding is gated on a usable provider of the
  matching type, so this connect step is what makes the profile appear).
  Crucially it passes `createDefaultCategory: false` — the
  onboarding category step owns category creation instead of auto-seeding a
  throwaway "Test Category".
- **Connect does not celebrate.** A quiet `OnboardingSuccessView` beat (checkmark
  scale-in + glow) acknowledges the connection; the celebration burst is reserved
  for the task payoff alone (one owner of the peak).
- **Step widgets** (`ui/widgets/`): `OnboardingHeroPanel` + `NeuralConstellation`
  (the theme-aware cinematic welcome and its animated hero),
  `OnboardingConnectPanel` (provider tiles), `OnboardingApiKeyPanel` (key paste
  + verify), `OnboardingSuccessView` (connect beat), and
  `OnboardingCategoryView` (the category step's presentational view).
- **Providers** — Melious.ai first, then Mistral, Gemini, and Qwen, with
  OpenAI / Ollama behind "More options". MLX is excluded from the FTUE
  (multi-GB download); it stays available in Settings. Visuals reuse
  `ai_provider_visual.dart`.
- **Funnel events** — `welcomeShown`, `providerModalShown`, `providerConnected`,
  `welcomeSkipped`.

### Theme and animation rendering

The route never installs a private light or dark theme. Ambient `ThemeData`
provides the active `DsTokens` extension, and every onboarding step consumes
that same set. `OnboardingBackdrop` also reads the Material brightness to select
the aurora compositor: additive `BlendMode.plus` keeps blooms luminous on dark
surfaces, while `BlendMode.srcOver` preserves their colour and contrast on a
light surface instead of adding them into white. The welcome constellation has
an intentionally mode-specific treatment: light mode uses the level-01 white
surface with high-emphasis monochrome nodes and branches plus alert-red
travelling activations; dark mode uses the semantic AI-card background with
the themed Ollama purple for nodes, Anthropic blue for branches, and AI-card
accent for activations. Its bottom fade uses transparent stops with the panel
surface's RGB values; this avoids the grey band produced when transparent black
is interpolated into a light surface. Later-step `OnboardingBackdrop` instances
stay on the quieter interactive-colour palette.

```mermaid
flowchart LR
    TM[App ThemeData<br/>light or dark] --> DS[context.designTokens]
    DS --> SF[panel surfaces + text + controls]
    DS --> NP[neural node / line / pulse palette]
    TM --> BR[Theme brightness]
    BR -->|dark| ADD[Aurora BlendMode.plus]
    BR -->|light| SRC[Aurora BlendMode.srcOver]
    ADD --> BG[OnboardingBackdrop]
    SRC --> BG
    NP --> BG
```

### The category step

`_OnboardingCategoryStep` teaches the app's core model — *which AI runs is chosen
per category* — instead of silently creating a throwaway category. The user
multi-selects life areas (Work / Fitness / Family / Friends, or adds their own); a
"Why areas?" disclosure explains the per-category-provider mechanism. On continue,
each selected area becomes a real `CategoryDefinition` bound to the just-connected
provider's seeded inference profile (`onboardingSeededProfileId`) **and** to Laura
(`lauraTemplateId`) as its default task-agent template, so every chosen area can
actually run inference and every task created in it — the onboarding first task
included — gets a task agent auto-assigned. Category names are UNIQUE across
**all** rows in the database — including soft-deleted, private-hidden, and
archived ones — so the duplicate check consults the unfiltered set
(`getAllCategoriesIncludingHidden`) and a matched area is **reused** rather than
re-created: the row is resurrected (`deletedAt` cleared), re-activated, and
rebound to the just-seeded inference profile so the first-task structuring can
run; Laura is bound only when the row carries no template of its own, and its
`private` flag is deliberately left untouched. A residual write failure
surfaces as an error toast instead of a silently dead Continue button.

`OnboardingCategoryView` renders the areas as a responsive grid of chips over
the shared alive backdrop. It uses two equal columns at the standard text scale
and comfortable widths, then collapses to one column for scaled text or narrow
panels so labels remain complete instead of ellipsizing. Unselected chips are
**teal-tinted frosted glass**
(a translucent brand-teal gradient painted over a `BackdropFilter`, under a crisp
theme-token hairline) so the colour lives in the chip material and the enriched
backdrop reads through; the selected chip fills solid brand with a trailing check
using the theme's on-interactive foreground. The shared
`_FrostedGlass` surface is reused by the quieter "+ Add your own" chip so the grid
reads as one glass family.

## Recording-style step

Between the success beat and the category step, a personalization step lets the
user pick how the mic looks during capture — and persists the choice. It's read
by the first-task step below (the live recording visual it renders), by the real
audio-recording sheet (`lib/features/speech/ui/widgets/recording/audio_recording_modal.dart`,
which swaps its VU meter for the energy orb accordingly), and by the standalone
**Settings › Recording Style** page (`lib/features/settings/ui/pages/recording_style_settings_page.dart`),
which lets the choice be changed again outside onboarding.

The live-preview mechanics and the two-card picker are factored out of
onboarding so Settings can reuse them pixel-for-pixel:

- **`RecordingStyleLivePreview`** (`ui/widgets/recording_style_live_preview.dart`,
  ConsumerStatefulWidget) owns the level source shared by both surfaces: a
  looping **simulated** signal by default (gated off under reduced motion), or
  the **live mic** when "Try with your voice" is on — recorded to a throwaway
  file via `AudioRecorderRepository` (levels only, never transcribed/saved;
  deleted after the recorder stops), falling back to the simulation if the mic
  can't start. Toggle changes are reconciled serially, so rapid input never
  overlaps recorder starts/stops or lets a stale transition claim the current
  preview.

```mermaid
stateDiagram-v2
    [*] --> Simulated
    Simulated --> Starting: Try with your voice on
    Starting --> Live: start succeeds and mic still desired
    Starting --> Stopping: start succeeds after toggle off or disposal
    Starting --> Simulated: start fails
    Live --> Stopping: toggle off or surface disposed
    Stopping --> Simulated: stop and delete complete
    Stopping --> Starting: toggle returns on after cleanup
    Stopping --> [*]: disposed after cleanup
```

- **`RecordingStylePicker`** (`ui/widgets/recording_style_picker.dart`) renders
  the two themed pairs off the level `RecordingStyleLivePreview` hands it:
  **Modern** (the `AiVoiceInputShader` orb + a brand-tinted `LiveWaveform`) and
  **Analogue** (the skeuomorphic `AnalogVuMeter` + a neutral `LiveWaveform`).
  Only the selected card animates; the other rests on a calm static waveform.
  Its card colours come from the injected ambient `context.designTokens` in
  both onboarding and Settings; the matching ambient `ColorScheme` drives the
  analogue meter, so neither surface can drift to a different theme.
- **`OnboardingRecordingStyleStep`** (`ui/widgets/`, ConsumerStatefulWidget)
  composes `RecordingStyleLivePreview` + the presentational
  **`OnboardingRecordingStyleView`** (title/explanation/Continue chrome around
  `RecordingStylePicker`), buffers the pick locally, and only commits it via
  `recordingStyleProvider.setStyle` on Continue.
- The choice is persisted by **`recordingStyleProvider`** (`state/recording_style.dart`,
  an `AsyncNotifier` over `AppPrefs`, default `modern`). Unlike the onboarding
  step, the Settings page has no "Continue" step — tapping a card calls
  `setStyle` immediately.

## Phase 2 — the live voice→task aha (the in-panel first-task step)

`OnboardingFirstTaskStep` (`ui/widgets/`) is the flow's **final in-panel step**
— the finale never leaves the onboarding dialogue for a full-screen takeover.
It hosts the presentational `OnboardingFirstTaskView` and wires it to the
**shared** `captureControllerProvider` (the same mic/realtime pipeline the
Daily OS capture screen uses — no bespoke audio wiring), to the persisted
`recordingStyleProvider`, and to the `onboardingCaptureToTaskServiceProvider`
orchestrator.

```mermaid
stateDiagram-v2
    [*] --> prompt
    prompt --> listening: tap the recording visual (mic opens)
    listening --> thinking: tap to stop (captured, transcript)
    prompt --> thinking: tap a starter suggestion (typed path)
    prompt --> prompt: mic error → re-arm on next tap
    thinking --> created: structuring lands a real task
    created --> [*]: card tapped → pop modal · open real task page
    thinking --> [*]: total structuring failure → done
```

The step maps the controller's `CapturePhase` onto the view's
`OnboardingFirstTaskPhase` (prompt / listening / thinking / created). On
reaching `captured` with a non-empty transcript it records the capture
modality once — `firstAudioCaptured` for the mic path, `typedCaptureUsed` for
the tapped-suggestion / typed paths (keyed on whether the capture carried an
`audioId`, so the voice-adoption metric isn't inflated by no-mic captures) —
then calls the orchestrator **exactly once per capture** (guarded against
double-fire), passing along the capture's `CaptureState.audioId` so the spoken
recording is linked under the task. When
a real task lands the step reveals the **created beat** inside the panel — the
task title as a glowing tappable card ("Your first task is ready"); checklist
proposals remain on the real task page where they can be confirmed. Tapping the
card (or its "Tap your task to open it" hint) hands the id to `onTaskCreated`,
and the host pops the modal and deep-links to the **real `TaskDetailsPage`**.

- **The style pick pays off here.** The active band renders the recording
  visual chosen in the style step: `VoiceOrbZone` (the shared Daily OS orb) for
  `modern`, or a tappable `AnalogVuMeter` + `LiveWaveform` pair for `analogue`
  — both riding the same live level. While the preference is still loading the
  orb stands in.
- **Guided first task.** Under the prompt, three localized **starter
  suggestions** ("Plan my week", …) give a no-mic path into the same pipeline:
  a tap rides the controller's typed path (`startTyping` + `updateTranscript`)
  straight into structuring, so even a user not ready to speak still watches a
  one-liner become a structured task.
- **Structuring** — `OnboardingTaskStructuringService` resolves the chosen
  category → profile → thinking model → provider and runs a single-shot
  `CloudInferenceRepository.generate` returning `{title, checklist[]}`.
  `OnboardingCaptureToTaskService` then materializes a real task **already in
  progress** (`PersistenceLogic.createTaskEntry` with `TaskStatus.inProgress` +
  `AutoChecklistService`) and emits the funnel events (`makeTaskTapped`, `realAha`,
  `structuringFailed`, `structuringFloorUsed`). On LLM failure it **soft-lands** on
  a title-only task (tagged `floor`, never counted as the real aha).
- **The task gets an agent that goes straight to work** — mirroring the normal
  creation path's `autoAssignCategoryAgent` hook, the service resolves the
  destination category (through `CategoryRepository`, not the async-refreshed
  cache — the category was created seconds earlier) and, when it carries a
  `defaultTemplateId` (Laura, bound by the category step), spawns a task agent
  via `TaskAgentService.createTaskAgent` with the category's default profile,
  on the structured and floor paths alike. Unlike the normal path (blank task,
  `awaitContent: true`), the onboarding agent is created *after* title,
  checklist, and transcribed audio have landed, so it is **not**
  content-awaiting — a skipped awaiting-content wake would be dropped and the
  never-again-edited task would leave Laura permanently inert. The creation
  wake runs the first full turn immediately, with the audio entry in its
  trigger tokens (`additionalWakeTokens`) the way a `transcriptionComplete`
  wake carries `{taskId, entryId}` after an in-task recording — so the user
  lands on a task page that is already alive: Laura's summary card plus any
  proposals pending their confirmation. The task also inherits the category's
  `defaultProfileId` into `TaskData.profileId`. All best-effort: no agent
  hiccup may cost the user the task.
- **Audio travels with the task** — the capture controller persists the spoken
  recording as a `JournalAudio` entry (transcript attached); the orchestrator
  links that entry under the created task (`PersistenceLogic.createLink`) and
  assigns it the task's category (`JournalRepository.updateCategoryId`) —
  both best-effort, on the structured and floor paths alike — so the task page
  carries the original audio and the recording shows up in category-filtered
  views instead of sitting orphaned and uncategorized in the journal. The
  typed path has no recording and creates no link.
- **Created beat + real-task payoff** — when the task lands, the panel shows
  its title as a tappable card breathing a soft accent glow, with "Tap your
  task to open it" underneath. Checklist proposals are deliberately not
  previewed here; they remain confirmable on the task page. The tap pops the
  modal and deep-links via the canonical `/tasks/:id` route
  (`openOnboardingCreatedTask`),
  which also switches to the Tasks destination — necessary because the flow
  may have been launched from another tab (e.g. the Settings → Maintenance
  debug entry). (`CrystallizeHero` lives on only as the hero-gallery
  `crystallize` style.)
- **Destination picker** — when the user created more than one area, a compact
  picker ("Where should this land?") appears under the active band so they
  choose which area the task lands in. It shows only while the capture is still
  being composed (prompt / listening); once structuring starts the destination
  is locked.
- **Escape hatches** — a "Rather type?" path opens a typed-capture dialog
  routed through the same structuring pipeline; tapping outside the panel
  closes the flow like every other step (the user can capture later); and a
  total structuring failure finishes onboarding via `onDone` rather than
  stranding the user on the thinking frame.

## Accessibility

Every critical action participates in keyboard focus traversal and activates
through the platform `ActivateIntent` (Enter/Space): provider tiles, category
chips, the analogue recorder, destination pills, starter suggestions, recording
style cards, and the created-task handoff. Focus feedback uses the design
system's `surface.focusPressed` or active interactive token. Back controls are
real `IconButton`s with the localized Material Back tooltip and an explicit
button semantics node. Category choices expose selected state to assistive
technology, and their responsive grid is covered at 200% and 320% text scale.

### Reduced motion

The shared voice visuals honor the OS "reduce motion" setting. The governing
principle is **kill the clock-driven looping animation, keep direct voice-level
feedback** (a volume response is information, not decoration):

- **`VoiceButton`** stops its idle-breath ticker (`_syncBreath`) while keeping the
  dBFS-driven core swell.
- **`AiVoiceInputShader`** holds its time ticker still and renders one calm static
  frame (still tinted by the live level).
- **`LiveWaveform`** ignores the live amplitudes and rests on a flat baseline
  (`LiveWaveformPainter.reducedMotion`), so the strip never dances.
- **`RecordingStyleLivePreview`** holds its simulated previews on a static
  frame under reduced motion — shared by the onboarding step and the
  Settings › Recording Style page.

The welcome and backdrop animations (`NeuralConstellation`, `AuroraHero`,
`CrystallizeHero`, and `WaveformTextHero`) carry their own reduced-motion
fallbacks.

`NeuralConstellation` paints a seeded, deterministic branching organism rather
than a proximity graph. The default topology is one root-like soma and spine:
secondary branches fork from stable parents, dim hairline offshoots probe
outward, and travelling activation tips move along the curved tendrils. The
welcome page opts into the denser variant (`vineCount` + `entanglement`): several
spines cross through shared convergence clusters, faint cross-links connect only
nearby separate vines, and the foreground branches draw as bundled strands so the
hero reads as neural tissue instead of a flat dot mesh. Later steps keep the
single-vine topology, lower alpha, fewer pulses, a smaller upward-shifted
composition, a panel-coloured content scrim, and connect-step title-safe veil so
provider cards and forms stay dominant. The painter loops **seamlessly**:
every oscillation (node drift, breath, branch activation, and travelling pulses)
runs an integer number of cycles per loop and is driven off the controller's
normalized value, so the frame at the loop wrap is identical to the start — no
snap (`neuralPulseCyclesForLoop`, `NeuralNode`, `neuralPulseEnvAt`,
`neuralBranchProgressAt`).
