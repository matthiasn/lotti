# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.1001]
### Added
- Synced notifications data layer: a separate `notifications.sqlite` store,
  Freezed notification entities, Matrix sync payloads for full alerts and
  state updates, backfill coverage, and macOS/iOS scheduler plumbing behind
  the new `enable_synced_alerts` flag.

## [0.9.1000]
### Added
- Live API-key verification on the AI provider connect form. As
  soon as you stop typing in the API key or Base URL field, the
  form checks the credentials against the provider's API and
  shows a status strip below the Base URL with one of three
  outcomes: a spinner while the check runs, a green confirmation
  with the number of models the key can see and the response
  time, or a warning row explaining what went wrong (invalid key,
  network error, timeout, unreachable host) with a Retry button.
  Covers Gemini, OpenAI, Anthropic, Mistral, Alibaba, OpenRouter,
  Nebius, and Ollama out of the box — no more "save the form,
  hope the key works, find out the next time you try to chat".
- Alibaba Cloud (Qwen) promoted to a first-class FTUE option.
  The pick-provider modal now carries a fifth tile for Alibaba
  with the NEW badge, sitting between Anthropic and Ollama, and
  the zero-providers state card adds a matching fifth chip in
  the same position. Alibaba also gets its own brand-orange
  accent token (light `#E0762A` / dark `#FFA868`) and a tagline
  ("Qwen models · multimodal · long context") so its tile and
  cards no longer fall back to the neutral interactive accent.
  Translations land in all six locales (informal tone).
- Voxtral (local) tile in the AI Settings pick-provider modal,
  added as the sixth tile (after Ollama) with the same
  `DESKTOP ONLY` badge. Picking it routes to the connect form
  preselected to `InferenceProviderType.voxtral` with the
  default base URL (`http://localhost:11344`) prefilled and no
  API key required. Until this release there was no UI
  affordance to add a Voxtral provider, even though the rest of
  the runtime (repository, default URL, known models, chip +
  visual) has supported it for some time.
- MLX Audio (local) provider scaffolding for embedded Apple
  Silicon speech. AI setup now offers MLX Audio, seeds Voxtral,
  Qwen3-ASR, Parakeet, and Qwen3-TTS model rows, prompts for
  model installation, and shows native download progress on both
  model overview and provider detail surfaces. Post-recording
  transcription routes through a guarded Swift channel. AI-summary
  playback remains wired through the same channel on macOS but is
  hidden behind the default-off `enable_ai_summary_tts` config flag
  while local TTS is evaluated. The iOS target does not link
  `MLXAudioTTS` yet because its Moss TTS target is not archive-safe
  on iOS; iOS `speakText` returns unsupported while STT remains
  linked. Intel macOS and builds without the MLX Audio Swift SDK
  keep compiling and report the feature as unsupported instead of
  loading Apple Silicon-only libraries.
- MLX Audio now also offers Qwen3-ASR 1.7B 4-bit and 8-bit model
  rows for local post-recording transcription tests on macOS and
  iOS. First-run MLX Audio setup now lets users choose which local
  STT model to install, with Qwen3-ASR 1.7B 8-bit preselected
  because it is materially faster than Voxtral Realtime for
  post-recording transcription. Batch transcription prefers
  configured MLX Qwen3-ASR models so speech-dictionary terms can be
  passed as Qwen prompt context; the realtime code path remains in
  place but its UI toggle is disabled until live transcription can
  use comparable biasing. MLX model download status is now held in a
  shared progress store so overview cards, provider-detail cards, and
  the modal render the same live percentage and the progress modal can
  be reopened while a download is running. Speech recognition can also
  fall back to a configured audio-to-text model directly when no
  applicable inference profile is available, which keeps local MLX STT
  usable on mobile without requiring a desktop-only profile. The native
  bridge now refuses transcription against missing or partial MLX models
  instead of starting an implicit background download from an inference
  call, and logs memory-stage diagnostics around model load and
  generation for crash investigation.

### Changed
- AI default-profile seeding is now strictly seed-on-create. User edits
  to a bundled profile (e.g. swapping the Ollama thinking model) survive
  restarts; previously the seeder reconciled model slots and flags back
  to the bundled values on every launch.
- AI Settings delete confirmations now use the same design-system
  toaster that the checklist row uses (warning tone, 5-second
  countdown bar, Undo action), replacing three custom hand-rolled
  SnackBars for provider / model / profile / prompt / skill
  deletions and a fourth for delete failures. The provider
  cascade list, previously rendered as a custom bullet block
  inside the SnackBar, now collapses into the toast description
  ("Also removed 2 models: gpt-4-turbo, claude-3.5-sonnet") so
  long lists ellipsize naturally. All copy moved into the
  `aiDeleteToast*` localization keys across English, Czech,
  German, Spanish, French, and Romanian (informal register).
- Profile cards in AI Settings now pin the `⋯` overflow menu to
  the far right of the card header — matching the provider cards
  — instead of letting it drift next to longer profile names.
- AI Settings Profiles tab Active badge now reflects whether the
  profile is the winning candidate for at least one configured
  provider — the same rule the provider detail page already uses
  for its "Active profile" section. Previously the badge was
  wired to `profile.isDefault`, which the seeder stamps on every
  shipped profile, so every seeded card lit up the green badge
  regardless of whether the user had actually wired the
  underlying provider. The picker logic moved into a new
  `lib/features/ai/ui/settings/util/active_profile.dart` so both
  surfaces consume the same definition; the detail page's
  Active-profile card also now shows the badge unconditionally
  (it can no longer fall off the card because of an unrelated
  `isDefault` flag flip). "Configured" mirrors
  `AiProviderCardStatus.statusFor` returning `connected`: cloud
  providers need a non-empty API key (drafts are skipped, even
  when their model rows survived the API-key clear), and Ollama
  needs a non-empty base URL plus at least one model row. The
  badge can no longer light up while the underlying provider
  card reads "Invalid key" or "Offline".
- The "Local Power (Ollama)" seeded profile now uses
  `qwen3.6:35b-a3b-coding-nvfp4` (35B MoE / ~3B active, NVFP4
  quant, 22GB download, 256K context, text-only) as the thinking
  model, with `qwen3.5:27b` retained as the image-recognition
  model. The Qwen 3.6 coding MoE is also added to the known
  Ollama model list so it can be selected from the model picker.
- Category tags now pick black or white text based on the
  background brightness instead of a fixed palette colour, so
  the label stays legible on dark category colours (e.g. the
  seeded Ollama charcoal `#0F172A`) and bright ones alike.
- AI provider setup-result modal (the post-FTUE
  "{Provider} is connected" sheet) now ships a single
  "Start using AI" CTA instead of a secondary "Review setup"
  button alongside it. The CTA fills the row on mobile-width
  surfaces and pins to the right with a comfortable cap on
  desktop / tablet dialog widths, so the one-button footer
  reads as a deliberate primary action at every breakpoint.

### Fixed
- Agent wake-cycle deadlines now survive app restarts as executable work.
  Persisted `nextWakeAt` rows are restored into the in-memory wake queue, so
  a 06:00 deferred wake that becomes due while the app is closed runs after
  the afternoon restart instead of lingering in the sidebar as stale. Completed
  subscription wakes also stop writing cooldown-only `nextWakeAt` rows when no
  follow-up job is queued, so the Wake Cycles list only shows work that can
  still run.
- Model IDs in the category Default-inference-profile picker no longer
  render with extra space between every digit. Replaced the generic
  `fontFamily: 'monospace'` (which Flutter doesn't ship, so macOS fell
  back per-glyph) with the bundled-Inconsolata `monoMetaStyle` helper.
- Voxtral (local) and Whisper (local) provider cards and detail-page
  status pills no longer report "Invalid key". The status helper only
  exempted Ollama; it now uses `ProviderConfig.noApiKeyRequired`, so
  all three local providers share the same base-URL + model-count gate.
- Agent wake-cycle countdowns now switch to `h:mm:ss` once a scheduled wake is
  more than an hour away, so next-morning wake deadlines no longer appear as
  giant minute counts like `385:20` in task/project AI report cards. Task-agent
  propagated updates also use the normal 120-second coalesced wake path instead
  of being pushed to the next 06:00 digest slot, and live wake titles now update
  across repeated agent-originated task title changes.
- Adding a second provider after tapping "Don't show again" on the
  FTUE pick-provider modal no longer strands the user on a
  `genericOpenAi`-prefilled connect form. The dismiss flag
  (`AI_PICK_PROVIDER_DISMISSED`) was routing every subsequent
  "+ Add provider" tap to `navigateToCreateProvider(context)` with
  no `preselectedType`, and `InferenceProviderFormController.build`
  defaults to `genericOpenAi` in that case — so users who'd set up
  Gemini first and then wanted Ollama saw an "OpenAI-compatible
  setup" with no surfaced way to switch types. The handler now
  routes dismissed users through the legacy
  `ProviderTypeSelectionModal` (a new `showForResult` entry point
  resolves with the picked type via a `Completer`) which lists
  every `InferenceProviderType` including Ollama, Voxtral, Whisper,
  OpenRouter, Nebius, and the generic OpenAI fallback — so the
  "start with Gemini, then add Ollama" workflow now works the
  same regardless of whether the dismiss flag is set.
- Speech recognition (and other entry-level AI skills) now run on
  standalone audio/text/image entries that have no parent task,
  using the entry category's default inference profile. Previously
  the AI popup-menu trigger silently no-oped whenever an entry had
  no linked task, so users with a category configured for Ollama +
  Voxtral could open the menu and tap Transcribe with no
  feedback and no transcription. `ProfileAutomationResolver` gains
  a `resolveForCategory()` path reading `CategoryDefinition`'s
  `defaultProfileId`, and `triggerSkillProvider` falls back to it
  when `linkedTaskId` is null. The popup also hides skills whose
  `contextPolicy` requires the full task (cover art, coding /
  design / research prompts, image analysis and transcription "in
  Task Context" variants) for standalone entries, and now applies
  the same fail-closed rule to `Modality.text` skills — those are
  only offered on the four text-bearing entity surfaces the popup
  actually renders on (`JournalEntry`, `JournalAudio`, `Task`,
  `JournalImage`), matching the existing audio/image-modality
  branches.

## [0.9.999]
### Added
- AI Settings FTUE pick-provider modal. Tapping the "Add provider" FAB
  on the AI Settings page now opens a centered `AiPickProviderModal`
  first instead of jumping straight to the empty connect form. The
  modal carries a `Set up AI features` title, a one-line subtitle,
  and four big provider tiles (Gemini RECOMMENDED, OpenAI, Anthropic
  NEW, Ollama DESKTOP ONLY) with radio-style selection. Footer hint
  pins the reassuring "Your API key is stored locally" copy plus a
  secondary `Don't show again` and a primary `Continue ▸`. Picking a
  tile and hitting Continue routes to the connect form preselected to
  that provider type. Tapping Don't show again writes a settings
  flag (`AI_PICK_PROVIDER_DISMISSED`) so subsequent FAB taps go
  straight to the form — the picker never harasses a user who has
  told us they know the flow.
- DRAFT badge on half-configured provider cards and on the provider
  detail header. A cloud provider with no API key yet (saved via the
  upcoming "Save as draft" affordance, or one whose key was later
  cleared) renders a secondary-toned `DRAFT` outlined badge next to
  the provider icon on `AiProviderCard` and inline with the
  display name on `_HeaderStrip`. Local providers (Ollama, Whisper,
  Voxtral) never need a key, so they are never reported as drafts.
  Surfaces in [[ai-provider-visual]] via the new `isProviderDraft`
  helper so the cards and the detail page share one source of truth.
- `popAiSettingsDetail()` back-affordance shared by all AI Settings
  detail pages (`AiProviderDetailPage`, `InferenceModelEditPage`,
  `InferenceProfileForm`). On mobile / pushed stacks it pops; on the
  desktop master/detail panel where the page sits in the panel slot
  (not on the Navigator stack) it falls back to beaming
  `/settings/ai`. Fixes the "back button does nothing" regression on
  the desktop surface that previously left users stuck on a detail
  page with no exit. Defensive guard means widget tests using a
  bare `MaterialApp.home` no longer crash on the GetIt lookup —
  the helper bails out silently when no NavService is registered.

### Changed
- Inference profile form chrome aligned with the rest of the AI
  Settings v5 pages (model edit + provider detail). Scaffold and
  AppBar now use `tokens.colors.background.level01` (the AI Settings
  surface tone) instead of the light theme's
  `surfaceContainerLowest` / dark theme's `scrim` pair, the AppBar
  is flat (`elevation: 0`, `scrolledUnderElevation: 0`), the title
  uses `subtitle1` typography, and the page padding is token-driven
  (`spacing.step5`).
- "Add provider" connect-form chrome redesigned to match the typed
  three-step flow. The legacy `Add Provider` SliverAppBar title is
  replaced in create mode by `_CreateModeChrome`: a breadcrumb row
  (`Settings › AI Settings › Add provider › <provider name>`, shown
  on viewports ≥ 720 px), a step indicator
  (`Choose provider › Connect › Review` with Connect highlighted),
  and a provider-tinted hero card pulled from `aiProviderVisual`
  carrying the localised `Connect <provider>` headline and tagline.
  Below the form the legacy `FormBottomBar` is swapped for an
  `_AddProviderFooterBar` with three actions: `Back to providers`
  (back-arrow tertiary), `Save as draft` (secondary, fires save
  WITHOUT the FTUE preview/result modal flow), `Save & continue ▸`
  (primary, keeps the existing FTUE setup workflow that lands the
  user on the connected-models success modal). Edit mode keeps the
  legacy chrome unchanged.
- Mobile responsiveness for the new chrome. The connect form's
  breadcrumb row and the tappable `Choose provider` step both drop
  on phone-sized viewports — the AppBar back-arrow already covers
  the same affordance, so re-rendering the breadcrumb chip on top of
  the form would just crowd the layout. The header card and step
  indicator stay; the footer's three buttons reflow onto multiple
  rows via `Wrap` instead of overflowing.
- API-key "Get a key at <console>" hint on the connect form is now a
  real link target — taps wire through `url_launcher` to open the
  provider's console in the system browser (`https://` is prepended
  for the bare-host URLs stored in `aiProviderKeyConsoleUrl`). The
  hint is also marked as `Semantics(link: true)` and underlined so
  screen readers announce it as a link, not a plain caption.
- Connect-form breadcrumb root crumb now reads `Settings` (using the
  canonical `settingsV2DetailRootCrumb` key, same as the Settings V2
  top-crumbs widget) instead of the unrelated `Theming` label that
  previously surfaced. Romanian CTAs (`Save and continue`,
  `Save as draft`, `Saved as draft`) were retoned to the formal
  `Salvați` register to stay consistent with the rest of the
  Romanian AI Settings flow, and the base-URL hint replaces the
  stilted `punctul final oficial` with `punctul final implicit`.

## [0.9.998]
### Fixed
- Sync stack hot-path cleanup driven by the 2026-05-10/11/12 desktop
  slow- and super-slow-query logs. Eight load-bearing offenders folded
  into one pass:
  - `BackfillRequestService` no longer runs the 2-minute periodic body
    against an empty sequence log. A new `hasActionableEntries()`
    probe (matches the `idx_sync_sequence_log_actionable_status_…`
    partial indices via `status IN (1, 2) LIMIT 1`) short-circuits
    both retire passes and `_loadNextUnqueuedMissingBatch` when no
    `missing`/`requested` rows exist — the 347 no-op ticks/day that
    each ran ~5 sync_db queries are gone.
  - `SyncDatabase.getPendingBackfillEntries` switched from drift's
    parameterised `status.isIn(...)` to a literal `status IN (0, 3)`
    via `CustomExpression`. The planner can now seek the outbox
    index instead of falling back to `SCAN outbox` (357 hits/day,
    avg 226 ms, max 1.8 s on 2026-05-12).
  - `InboundEventQueue._oldestActiveOriginTs` inlines its status set
    as a literal `IN ('enqueued','leased','retrying')` so the
    partial index `idx_inbound_event_queue_active_room_ts` finally
    matches; the parameterised form had degraded into a rowid scan
    at up to 862 ms per commit/abandon.
  - New `AgentRepository.getEntitiesByIds` collapses the per-id
    `Future.wait(getEntity)` fan-out used by both
    `ProjectAgentWorkflow._collectObservationPayloads` and
    `TaskAgentWorkflow._collectObservationPayloads` into a single
    `WHERE id IN (?, …)` query. `TaskAgentWorkflow._buildLinkedTasks
    ContextJson` switched to the existing bulk
    `getLinksToMultiple` + `getLatestReportsByAgentIds` pair —
    eliminates the compounding N×M `agent_links WHERE to_id = ? AND
    type = ?` + per-link `getLatestReport` fan-out (2 484 + 2 203
    slow hits on 2026-05-10).
  - `QueuePipelineCoordinator` debounces `AttachmentIndex.path
    Recorded` events into a 100 ms accumulator and flushes through a
    new bulk `InboundEventQueue.resurrectByPaths(paths)`. A burst of
    attachment downloads now resolves in one SELECT + UPDATE
    round-trip instead of N independent writer-lock transactions
    (222 super-slow hits/day on 2026-05-12).
  - `sync_db` schema bumped to v21 with two literal-status partial
    indices for outbox claim ordering:
    `idx_outbox_pending_created_id (created_at, id) WHERE status =
    0` and `idx_outbox_sending_expiry (updated_at, created_at, id)
    WHERE status = 3`. The pending-claim path no longer has to pay
    `USE TEMP B-TREE FOR ORDER BY` after seeking
    `idx_outbox_status_priority_created_at`.
  - Agent database schema bumped to v8 with
    `idx_wake_run_log_created_at`. `getWakeRunsInWindow` had been
    falling back to a base-table scan + temp B-tree because every
    existing wake_run_log index was leaded by `agent_id` /
    `template_id` / `status`.
  - `MatrixSyncMetricsPanel`'s on-screen poll widened from 2 s to
    5 s (now exposed as the `pollInterval` constant). The 30
    polls/min cadence had pulled the `GROUP BY status, producer`
    aggregate to 223 hits/day; widening removes the polling
    pressure without losing perceived liveness.

- Tasks Filter sticky footer no longer renders the Clear all / Save
  pills as floating text labels on dark mode. The button's inner box
  was 44 tall while its slot enforced a 56 minimum, so under the
  glass-blur footer the painted pill drifted out of alignment with
  the centered text and at low alpha against the dark sheet the
  silhouette washed out entirely. Both heights now share a single
  `DesignSystemFilterMetrics.actionMinHeight` token and the
  non-highlighted variant carries a 1 px border so the pill stays
  visible against the gradient overlay; Apply keeps its solid
  accent.

### Added
- AI Settings page redesigned to match the new design-system reference.
  The collapsing v1 title strip now sits above an `AiSettingsHeaderBar`
  that carries an inline search field; the page's "Add" affordance
  rides on a per-tab `DesignSystemFloatingActionButton` (Scaffold's
  `floatingActionButton` slot) instead of a header CTA — see the FAB
  bullet later in this section for the icon/handler swap rules. The
  tab row uses an `AiSettingsTabBar` that bakes the counters directly
  into each label — "Providers 2 / Models 5 / Profiles 2" — instead
  of a separate counter strip. Below the tab bar the active tab renders the
  new card surfaces: `AiProviderCard` is a 2-column responsive grid
  card with the provider's accented icon top-left, a `⋯` overflow
  menu top-right, the display name + tagline, a hairline divider, and
  a status row with a colored dot + left label + right meta — the
  three status variants are Connected (with model count tail), generic
  "Invalid key · Fix" (covers missing / wrong / revoked / 401 / 403 in
  one phrase per the design tweak), and "Offline · Make sure Ollama is
  running"; `AiModelCard` is a single-column row with the provider
  icon, model name + monospaced provider-model id inline, and the
  capability chips below (intentionally no on/off toggle); and
  `AiProfileCard` is a 2-column grid card with the active badge inline
  with the name and a task→model mapping list (Thinking / Image
  recognition / Transcription / Image generation → model). Unresolved
  model ids render as `missing` in the warning tone so dangling profile
  references are visible at a glance. With zero providers configured
  the page swaps in `AiSettingsFtueBanner` — an accented banner with a
  sparkle icon, lead copy, and a "Start setup" button that opens the
  same provider-type picker — followed by `AiSettingsNoProvidersCard`,
  a single wrapper card with "No providers yet" + the four first-class
  provider chips (Gemini / OpenAI / Anthropic / Ollama) that each open
  the connect form preselected to that provider. Per-provider chrome
  is wired through a new `AiProviderVisual` helper so the accent /
  surface / display name / tagline lookups stay consistent across the
  cards, chips, banner, and (upcoming) provider detail page. ~30 new
  l10n keys × 6 locales for the page chrome, status copy, capability
  chips, and the empty / FTUE surfaces.
- AI Settings FTUE modals redesigned to match the new design system. The
  old `FtueSetupDialog` / `FtueResultDialog` are replaced by
  `AiProviderSetupPreviewModal` and `AiProviderSetupResultModal`. The
  preview modal lists each model the FTUE will create as a checkbox row
  the user can untick — those `providerModelId`s are passed to
  `runFtueSetupForType` as `excludedProviderModelIds` and the
  per-provider setup helpers skip them at creation time, so the
  success-modal model count reflects exactly what landed in the
  database. Models the provider already owns appear in a read-only
  "Already added" section so re-running the wizard doesn't pretend
  they're new. Ollama short-circuits the preview because it has no
  canonical model preset, and providers whose entire preset is already
  configured skip straight to the result modal. The result modal
  shows a compact post-setup summary — "{Provider} is connected. We
  set things up for you." — with bulleted rows for added models,
  created profile, and test category (created vs reused), an errors
  block when present, and Review setup / Start using AI buttons. Both
  modals use the existing app dark / light tokens instead of the
  design's near-black, and pick up the per-provider accent from the
  `colors.aiProvider.*` tokens added in the next bullet.
- AI Settings FTUE backend now covers Anthropic and Ollama alongside
  the existing Gemini / OpenAI / Mistral / Alibaba flows. Anthropic
  setup seeds Claude Sonnet 4 (reasoning) and Claude Haiku 3.5 (fast)
  plus a new `Anthropic Claude` default inference profile bound to a
  fresh `Test Category Anthropic Enabled` test category. Ollama setup
  installs the test category bound to the existing `Local (Ollama)`
  profile and intentionally creates no model rows — Ollama serves
  whatever the user has pulled locally, so the upcoming connect modal
  will enumerate `/api/tags` and let the user pick from what's
  actually installed. Both providers are now members of
  `ftueSupportedProviderTypes`, dispatch through `runFtueSetupForType`,
  and render via `AiProviderSetupPreviewModal` /
  `AiProviderSetupResultModal`, so the FTUE flow fires end-to-end
  after a key paste (Anthropic) or a localhost ping (Ollama). The
  per-provider result types now share a sealed `AiFtueResult` base
  class so the analyzer catches a missing arm when the next provider
  is wired in.
- Design-system color tokens for AI providers: `colors.aiProvider.{gemini,
  openAi, anthropic, ollama}` each carry an accent + tinted-surface
  pair in both light and dark variants, generated from `tokens.json`
  through the existing token generator. Used by the upcoming
  redesigned AI Settings surfaces (quick-add provider tiles,
  provider cards, master/detail rail) so per-provider accents stay
  consistent across mobile, desktop, and modal layers.
- AI Settings provider detail page. Tapping a provider row on the
  AI Settings page now opens `AiProviderDetailPage` (under
  `lib/features/ai/ui/settings/provider/`) instead of dropping the
  user straight into the edit form. The detail page shows a
  provider-tinted header strip with the display name, tagline, and
  derived status pill; a Connection card with masked API key
  (last 4 visible), base URL, and display name plus an `Edit`
  action; a Models section that lists the provider's own models
  via `AiModelCard` with an `Add model` button; an Active profile
  section that surfaces the inference profile most strongly tied to
  this provider's models (default profile first, otherwise the first
  match) via `AiProfileCard`, hidden when no profile references the
  provider's models; and a Danger zone that routes through the
  existing `AiConfigDeleteService` so cascade-delete + confirmation
  modal + undo snackbar match the rest of the AI settings. The
  bottom of the page pads by `DesignSystemBottomNavigationBar.occupiedHeight`
  so the danger-zone card never slips behind the app's bottom nav
  on mobile.
- Provider card "Fix" affordance now auto-focuses the API key field.
  When a provider's status is `invalidKey`, the `Fix →` link routes
  through the provider detail page with `focusApiKey: true`, which
  immediately pushes `InferenceProviderEditPage(focusApiKey: true)`.
  The edit page wires a `FocusNode` through `AiTextField` and
  requests focus on the next frame, so the user lands directly on
  the field that needs editing in one tap. A regular card tap still
  opens the detail page without auto-pushing so users who want to
  inspect models / profile before editing don't get bounced.
- Card overflow menus do the right thing. The `⋯` icon on Provider,
  Model, and Profile cards used to render a disabled IconButton on
  top of a tappable card — tapping the icon just forwarded the tap
  to the card itself. Each card now accepts a `menuActions` list
  (`AiCardMenuAction` / `AiCardActionMenuButton` under
  `widgets/v2/ai_card_action_menu.dart`) and the AI Settings page
  passes Edit + Delete rows; Delete runs the existing
  `AiConfigDeleteService` so cascade-delete + confirmation + undo
  snackbar are consistent with the rest of the settings. Cards
  without a populated `menuActions` list (e.g. the cards embedded
  in the provider detail page) hide the icon entirely instead of
  showing a non-interactive affordance.
- Inference model edit page redesigned to match the v1–v3 visual
  language. The old SliverAppBar + `colorScheme.surface` chrome is
  replaced by a clean AppBar with a text `Save` action (the
  `FormBottomBar` is gone — Cmd+S still saves), a provider-tinted
  header strip that reads the model name + owning provider
  inline, and two design-system sections (`Identity`,
  `Capabilities`) rendered as `level02` cards on a `level01` page
  background. Provider, input modalities, and output modalities
  use a shared `_SelectorField` that styles a read-only
  `AiTextField` as a tap-to-open dropdown and tints the trailing
  caret amber when the field is empty so unset required selections
  are visible at a glance. All form copy (section names, field
  labels, hints, toggle descriptions, "Select a provider" hint,
  back tooltip, save button) is now localised across all six
  supported locales — previously the page shipped hard-coded
  English on every label.
- Card text on the Models and Profiles tabs no longer truncates on
  mobile. The model card now stacks the display name, the
  monospaced `provider/model-id` line, and the capability chips
  vertically — previously the name and id sat inline on one row
  and both ellipsised at narrow widths. The profile card lets the
  profile name, description, and each task→model slot wrap to
  multiple lines instead of clipping; slot rows are top-aligned so
  the icon + slot label stay flush with the first line of a
  wrapped model name. The inference profile form's body padding
  now includes `DesignSystemBottomNavigationBar.occupiedHeight` so
  the last form section clears the bottom nav on mobile.
- AI Settings desktop master/detail dispatch. The `ai` panel in
  the Settings V2 registry was promoted from a plain
  `AiSettingsBody` body to a multi-kind `AiPanelDispatch` so the
  right pane on desktop now swaps to `AiProviderDetailPage`,
  `InferenceModelEditPage`, or `InferenceProfileDetailPage` in
  place when a row is tapped (or when the user beams to
  `/settings/ai/provider/<id>`, `/settings/ai/model/<id>`, or
  `/settings/ai/profile/<id>`) — previously the detail page was
  pushed as a fullscreen route over the master/detail shell,
  hiding the sidebar. The three typed URL patterns
  (`/settings/ai/provider/:providerId`,
  `/settings/ai/model/:modelId`, `/settings/ai/profile/:profileId`)
  handle both surfaces: on desktop the panel slot reacts to
  `NavService.desktopSelectedSettingsRoute`, on mobile the Beamer
  location builder pushes the detail page on top of the AI
  Settings page so the back gesture still returns to the list.
  `AiSettingsNavigationService.navigateToConfigEdit` now beams to
  the matching typed route instead of calling `Navigator.push`
  directly, and the Fix-flow rides the provider URL with a
  `?focusApiKey=true` query parameter — `AiPanelDispatch` reads
  that query off the live route and rebuilds the detail page
  with `focusApiKey: true` so the edit form auto-pushes with the
  API key field focused regardless of which surface the user
  came in on.
- AI Settings desktop sidebar shows Providers / Models / Profiles
  as their own leaves under "AI Settings". Previously the three
  views lived only as tabs inside the AI Settings page body, and
  the sidebar carried a single (legacy) "Inference Profiles" leaf
  that pointed at the V1 profile list — the v3 redesign moved
  profile rendering into the tab body but the legacy leaf was
  never updated. The settings tree now mirrors the three tabs as
  three leaves, each panel renders `AiSettingsBody` pinned to its
  tab with the in-pane TabBar hidden, and the `ai-profiles` panel
  is repointed from `InferenceProfilesBody` (V1) to the v3
  Profiles tab body so a desktop user sees one consistent profile
  list whether they reach it via the sidebar or the AI Settings
  page directly. Clicking the AI Settings parent row itself also
  renders without the TabBar — the page-level default tab is
  already Providers, so the parent landing lands visually
  identical to the Providers leaf instead of briefly flashing a
  duplicate tab strip before the user picks a leaf. On mobile
  the page still ships its TabBar — the sidebar doesn't exist
  there, so the tabs remain the only way to flip between the
  three views.
- AI Settings "Add" affordance is a per-tab floating action button.
  The inline "Add provider" pill in the page header is gone — it
  was hard-coded to provider creation even when the user was
  looking at Models or Profiles, and it duplicated the FAB pattern
  the rest of the settings surface already uses
  (`InferenceProfilePage`, habits, measurables). The page now
  drives a `DesignSystemFloatingActionButton` in the Scaffold's
  `floatingActionButton` slot (wrapped in
  `DesignSystemBottomNavigationFabPadding` so it clears the
  bottom nav on mobile). Its `semanticLabel`, `icon`, AND handler
  swap per active tab — `Icons.bolt_rounded` on Providers,
  `Icons.psychology_alt_rounded` on Models, `Icons.tune_rounded`
  on Profiles. The icon set mirrors the sidebar leaf icons so
  the FAB glyph echoes the leaf the user is on and names what's
  about to be added. `AiSettingsHeaderBar` is now just the
  search bar — the subtitle paragraph the v2 redesign shipped
  was redundant with the page title + sidebar leaf, and the
  custom design-system text input it used had a different
  placeholder than every other search field in the app. The
  header now reuses `AiSettingsSearchBar` (which wraps the
  app-wide `LottiSearchBar`) so the styling and hint copy match
  the rest of the settings surface.
- Provider card's status row right-aligns the model count tail
  flush against the card's right edge. The v3 layout shipped a
  `Spacer + Flexible(Text)` pairing for the right-side tail,
  which split the remaining width 1:1 and parked "3 models · last
  used 2m ago" in the middle-right of the card instead of at the
  edge. `Expanded(Text(textAlign: end))` collapses the gap so the
  tail snaps to the right margin; the Ollama-hint variant on the
  offline status branch got the same treatment.
- Models tab regains the pre-v3 filter strip in full. The v3
  redesign hooked up the filter service to filter by
  `selectedProviders` / `selectedCapabilities` / `reasoningFilter`
  but never shipped the UI for any of them. The strip now reuses
  the existing `AiSettingsFilterChips` widget (which itself
  wraps `ProviderFilterChipsRow(useStyledChips: true)`), so the
  Models tab gets the same chrome the rest of the app already
  uses: provider-tinted pills (colored leading dot + matching
  border + dark accent-tinted background pulled from the
  per-provider `colors.aiProvider.*` tokens), capability chips
  (Text / Vision / Audio) plus a Reasoning toggle in a neutral
  Material FilterChip style, and an appearing "Clear filters"
  action when at least one filter is active. The chips sit in a
  `Wrap`, so the row stacks across multiple lines on narrow
  viewports instead of horizontally scrolling — the
  design-system-chip prototype shipped earlier on this branch
  (and its successor with `useStyledChips: false`) didn't match
  what the rest of the app does and were both removed.
- Sync conflict resolution screen rebuilt as an inline-diff picker.
  Tapping a conflict row now opens a dedicated page with a back chip
  + title + amber count pill in the header, lead copy, and an amber
  summary banner that calls out the entity type and how long ago the
  two sides diverged plus a subline listing the fields that differ.
  Below the banner are two diff cards — local (teal) on the left,
  remote (blue) on the right — with each side's title rendered as a
  word-level diff: tokens unique to the local side are tinted green,
  tokens the remote dropped are line-through red, and tokens the
  remote introduced are tinted blue. Each card carries the side's
  timestamp + per-side vector-clock counter (`vec N`) plus a category
  icon, word count, and audio duration when available, with a
  `local edit` / `via sync` provenance label on desktop. A picker
  pill row underneath mirrors the selection (`Use this device` /
  `Use from sync`, plus `Edit & merge…` on desktop), and a sticky
  glass footer holds Cancel + Apply with helper copy that reads back
  the chosen consequence in plain English. Below 768 px the cards
  stack vertically, the picker drops to two pills, and the footer
  surfaces `Edit & merge…` as a left-side text link. Apply commits
  via `PersistenceLogic.updateJournalEntity` only when a side is
  picked; Cancel beams back without writing. The diff itself is a
  pure-Dart word-level LCS helper so it carries unit tests for
  identical / additions-only / replacements / mixed cases.
- New design-system color tokens for the picker: `colors.conflict.*`
  carry the local / remote / diverged accent + tinted surface pairs,
  and `colors.diff.*` cover the added / removed / replaced highlight
  pairs. Both are wired through `tokens.json` and the generator so
  light and dark variants are emitted from one source.
### Fixed
- The Task action bar's inset stop circle now persists the running
  timer entry's `dateTo` to `DateTime.now()` before the timer service
  is cleared, instead of only clearing in-memory state. Previously
  `_onStopTimer` called `TimeService.stop()` directly, which left
  whatever `dateTo` was last written on disk — typically minutes
  behind the actual stop tap — so the recorded session was short by
  the elapsed-but-unsaved tail. The handler now routes through
  `EntryController.save(stopRecording: true)` for the running timer
  entry, mirroring the entry-editor stop button.
- Slow-query log on the 2026-05-10 desktop super-slow trace flagged
  four hot paths that all stemmed from query/index mismatches:
  - `InboundQueue.stats()` ran four separate `selectOnly` aggregates
    (three of them full SCANs of `inbound_event_queue` with a TEMP
    B-TREE for GROUP BY) on every `_emitDepth` tick — captured at
    1014 ms and 2244 ms in the slow log because no index covered
    `(status, producer)`. Collapsed to one
    `GROUP BY status, producer` query and added a v20
    `idx_inbound_event_queue_status_producer_enqueued` composite so
    the pivot is index-only over a tight key range.
  - `getProjectTaskRollups` (`database.dart`) fell back to
    `idx_journal_browse + USE TEMP B-TREE FOR GROUP BY` (327 ms)
    because the query omitted `task = 1` even though every Task
    write sets it. Adding the redundant predicate lets the planner
    match the v40 `idx_journal_project_task_status` partial index
    and stream the aggregate directly.
  - `ChecklistRepository.getChecklistItemsForTask` materialised every
    `ChecklistItem` the device had ever seen, JSON-decoded each one
    and filtered in Dart (558 ms on the agent hot path). Replaced
    with two indexed bulk-by-id lookups via
    `journalEntitiesByIdsUnorderedAllPrivate`: first the parent
    Checklists (whose `data.linkedChecklistItems` already lists
    their children), then the items themselves. The unused
    `deletedOnly` parameter was dropped because no caller passes
    `true`.
  - `SyncSequenceLogService` cache cleared every cached host
    watermark, last-seen timestamp and materialised upper bound the
    moment a single global 5-minute timer ticked over, regardless of
    which host had been active. That produced the 200–500 ms
    `getLastCounterForHost` waves visible in the slow log: a quiet
    host's watermark got wiped just because some unrelated host had
    been queried 5 minutes earlier. Replaced with a per-host
    expiry map and a separate global TTL for the entry-keyed
    last-sent-counter LRU; `_advanceLastCounterCache` now refreshes
    the host's window so a host being actively backfilled does not
    expire mid-run.
- The Projects tab "+" FAB now opens the project create page directly
  inside the Projects tab via `/projects/create` instead of beaming
  through `/settings/projects/create`. On desktop the old route landed
  on the Settings V2 root (no `projects` panel is registered there),
  so the create flow was unreachable. The same path swap is applied
  to the inline "New project" button on category pages so deep-links
  with a prefilled `categoryId=` continue to work. The legacy
  `/settings/projects/create` pattern is removed.
- The Categories list "+" FAB on Definitions → Categories now opens
  `CategoryCreateModal` directly instead of beaming to
  `/settings/categories/create`, which on desktop was bouncing the
  user back to Settings V2's root. The modal stays inside the
  current tab and the list refreshes via the shared category stream
  once the new entry is persisted.
- The "Save" / "Create" row on the project create page is no longer
  hidden behind the bottom navigation pill on mobile. The page's
  `FormBottomBar` is wrapped in a `Padding` sized to
  `DesignSystemBottomNavigationBar.occupiedHeight`, so it docks above
  the pill on phones and remains flush at the bottom on desktop where
  the helper returns 0.
- Project create no longer publishes a "Saved successfully" toast on
  the projects tab. The freshly-created project shows up in the list
  immediately on pop (the list watches `projectsOverviewProvider`),
  which is sufficient confirmation for a one-shot create flow — and
  avoids the disruptive Material FAB lift that a floating SnackBar
  would otherwise trigger on the projects list. Error toasts on the
  create page itself are unchanged and still dock above the form's
  bottom action bar.
- Conflict detail page now opens correctly on desktop. The Settings
  V2 panel for `sync-conflicts` was registered as a list-only body,
  so a row tap updated the URL but the right-hand pane kept
  rendering the list — only the mobile Beamer stack was wiring the
  detail. The panel now uses `DetailIdDispatch(idParamKey:
  'conflictId')` so the desktop pane swaps to `ConflictDetailRoute`
  when the URL gains an id, matching the categories / labels /
  dashboards / measurables flows.
- Linked-entries activity log on a task now sorts entries by each
  entry's `dateFrom` instead of the link's own `createdAt`, so the
  "Newest first" / "Oldest first" toggle reflects the timestamps
  shown in the row headers. Previously two entries linked in the
  same session could appear in an order that contradicted their
  visible times because their links shared a `createdAt` and the
  list was sorted by that field. The widget now reads a new
  `sortedLinkedEntriesProvider` that resolves each linked entity and
  falls back to `link.createdAt` only while an entry is still
  loading.

### Added
- The project create form now exposes a category picker between the
  title and target-date fields. The picker reuses the shared
  `CategoryField` and is seeded from the route's `?categoryId=` query
  parameter so the inline "New project" button on a category page
  still pre-selects the right category, while users opening the form
  from the Projects tab FAB can pick a category up front instead of
  having to backfill it after creation.

### Changed
- Sync Conflicts list page restyled to match the agents listing visual
  language. The legacy card chrome is gone; each row is now a hover-aware
  inline strip that pairs a tone-driven status badge (success for
  resolved, danger for unresolved) with an entity-type badge, the
  creation timestamp as the row title, and an 8-character mono prefix of
  the conflict id on the trailing edge with the full id revealed via
  tooltip. The full vector clock — previously wrapping two lines of
  monospace text inside every row — is no longer surfaced in the list
  and stays available on the conflict detail page where the merge view
  actually needs it. Below 600 px the row collapses to a two-line
  stacked layout so phone-width viewports stay legible. The shared
  `monoMetaStyle` helper that used to live inside the agents feature was
  also lifted into the design system so any feature that needs an
  Inconsolata mono cell pulls from a single source.
- AI summary card header (the `AI summary / Task Laura` row) keeps its
  wake / refresh affordances and Read more pill inline alongside the
  title on every viewport instead of stacking them underneath on
  cards narrower than ~360 px. The title block uses an `Expanded` so
  it softWraps to a second line if the controls really need the room;
  on a phone-sized card with the wake-cycle countdown active the pill
  also switches to a tighter compact width so the inline cluster
  reads less crowded. Previously the header dropped the entire
  control cluster to a second row even when only the refresh icon +
  Read more pill were present and would have fit alongside the title
  comfortably.
- Toast notifications triggered from the task details page (e.g.
  "Change applied" after confirming a proposed change) now float above
  the sticky `TaskActionBar` on every platform instead of being pinned
  to the screen / window bottom edge, so the confirmation reads as
  belonging to the task view it came from. The page wraps its
  `Scaffold` in a nested `ScaffoldMessenger`, scoping
  `context.showToast()` calls fired from inside the subtree to that
  messenger — Flutter then floats the `SnackBar` above the
  `bottomNavigationBar` slot automatically. Previously this was gated
  to macOS / Linux / Windows; on mobile the `TaskActionBar` would
  cover the toast docked at the screen bottom.

## [0.9.997]
### Changed
- Sidebar running-timer card now hides itself only when the timer's
  parent task is the same task currently open in the desktop task-
  details pane *and* the user is actually on a `/tasks/<uuid>` route.
  The detail page's sticky action bar already shows a running
  indicator, so duplicating the title in the sidebar would be noise —
  but the card still surfaces on every other tab (Habits, Settings,
  …) because `desktopSelectedTaskId` is sticky across tab switches and
  the action bar isn't visible there. The show/hide flip runs through
  a combined `AnimatedSwitcher` + `AnimatedSize` (~220 ms,
  `Curves.easeInOut`) so the card fades and the surrounding sidebar
  collapses smoothly instead of popping. The stream is seeded with
  `TimeService.getCurrent()` so a session already running is rendered
  on first frame instead of flashing through a hidden state.
- Sticky action bar's running "Track time" pill gets a touch more
  breathing room on the leading edge: the inset stop circle now sits
  8 px from the pill border (was 4 px) so it no longer crowds the
  edge while the elapsed digits tick.

## [0.9.996]
### Changed
- Audio recording player restyled to match the green Figma audio card.
  The play/pause control is now a soft circular pill drawn on the
  design-system surface token with the high-emphasis text color for
  the glyph; the previous gradient + drop shadow + animated progress
  ring are gone. The waveform's played bars use
  `tokens.colors.interactive.enabled` (the brand teal `#2BA184` in
  light mode, `#5ED4B7` in dark mode), with a thin teal scrubber line
  drawn at the playhead and bars widened to 4 px with 3 px spacing
  for parity with the Figma reference. The fallback progress bar
  (used while the waveform is still resolving) follows the same
  tokens, with the unplayed track now reading from
  `tokens.colors.decorative.level02` instead of an alpha overlay on
  `onSurfaceVariant`. The play/pause button drops a step in size (40
  px compact / 48 px standard) so it no longer dominates the card.
- Task details page now has a sticky action bar pinned to the bottom in
  place of the floating action button. A primary "Track time" pill
  starts a new timer when idle. While a timer is running on the open
  task the pill morphs into a live elapsed-time readout with an inset
  stop circle on the leading edge — tapping the pill body navigates to
  the running timer entry (matching the desktop sidebar's timer card),
  and only the inset stop circle stops the timer. The duration uses
  the same tabular-figures / slashed-zero / cv02–04 font features as
  the sidebar timer; under one hour it's compacted to `mm:ss` and only
  expands to `hh:mm:ss` once a session crosses the hour mark. Four
  round affordances cover the remaining frequent inline actions:
  record audio (immediately after the pill — turns red with a white
  glyph while a recording for the open task is active), add checklist,
  import image, and more actions (opens the previous menu for
  long-tail items, including capture-screenshot on desktop platforms
  that support it). Capture-screenshot is no longer a top-level
  affordance. On narrow viewports the row stays on a single line by
  dropping affordances in priority order: image first, then checklist;
  both remain reachable via the more menu. On mobile the bar takes
  over the bottom edge entirely: the app shell's bottom navigation
  pill is hidden whenever the active beamer route is `/tasks/<uuid>`,
  letting the action bar dock flush against the home indicator.

## [0.9.995]
### Changed
- Agent UI/UX refinements across the AI summary card, sidebar Wake
  Queue, and the renamed "Wake Cycles" settings page. The AI card's
  outer glow is trimmed to a soft tinted edge instead of a wash, the
  underlined subtitle below "AI summary" now reads the agent template
  name (e.g. "Task Laura") rather than the generic kind label, the
  Confirm-all button pins to the right edge of the proposals header
  to line up with the Read more pill above it, and the cards inside
  the agent internals panel (Reports / Conversations / Observations /
  Activity) now sit on the AI panel's row token so the dark backdrop
  reads as a unified surface. Settings → "Pending Wakes" is renamed
  to "Wake Cycles", its countdown is now zero-padded MM:SS (or
  HH:MM:SS once over an hour) with tabular figures so digits no
  longer breathe, refresh keeps the previously-loaded rows on screen
  instead of blanking to a spinner, and a new "Running now" block at
  the top of the page surfaces the currently-executing wake instances
  with a live elapsed pill. The desktop sidebar Wake Queue gains an
  Ongoing block (live duration since wake start), only shows scheduled
  wakes due within the next hour (anything farther out is hidden from
  the sidebar entirely), drops the per-row letter avatar, uses smaller
  mono font with ellipsis for long titles, prefers the linked task /
  project title as the row label, and the WAKES header itself is now
  an open-in-new link straight to the full Wake Cycles page.

## [0.9.994]
### Changed
- Desktop running-timer is now an inline sidebar section in the
  `aboveSettings` slot, replacing the bottom-anchored floating
  indicator. The new panel shows the running task title (up to two
  lines, in the design-system caption style), a ticking HH:MM:SS
  counter, and a stop button. Tapping the body navigates to the
  running task (or the timer's journal entry); tapping the stop
  button stops the timer. The mobile bottom-nav overlay is unchanged.
  The timer text uses Inter with tabular figures, slashed zero, and
  the `cv02`/`cv03`/`cv04` open-digit variants so 4/6/9 stay legible
  and digits don't breathe.
- Sidebar nav-item vertical spacing tightened from `step6` (24 px) to
  `step5` (16 px) — a 33 % reduction — to make room for the new timer
  section without the rail feeling crowded.

### Fixed
- Task detail "Linked from" no longer surfaces parent projects. Tasks
  link to a project as their organising context, but listing the
  project alongside other linked entries adds noise without the user
  ever wanting to act on it; `LinkedFromEntriesWidget` now filters
  out `ProjectEntry` items unconditionally.

## [0.9.993]
### Changed
- Task filter modal action bar now uses the new "Apply filter" glass
  footer: a full-width frosted-glass strip flush to the bottom of the
  modal, with a hairline divider on top and right-aligned Clear all,
  Save, and Apply filter buttons. The last filter section gains
  comfortable breathing room above the footer; long localized labels
  still fit because the buttons can grow past their default width.

### Fixed
- Task filter modal's Save button now applies the current modal draft,
  persists it to the saved-filters sidebar, and closes the modal — one
  action instead of three. Previously Save read from
  `liveTasksFilterProvider` (the last applied state), so any edits made
  in the modal before tapping Save were silently dropped from the
  persisted filter, and the modal stayed open afterwards. The
  design-system filter modal's `onSavePressed` callback now receives
  the committed name AND the current draft state, so any consumer can
  derive a payload from what's actually visible to the user.

### Changed
- Saved-filter "Saved / Updated / Deleted" confirmation toasts now
  render via the shared design-system toast (`context.showToast`) —
  same rounded pill, palette, and queue behavior the label-detail
  page uses when a label is created — instead of an ad-hoc themed
  [SnackBar]. The leading glyph is the standard tone-coloured
  `check_circle_rounded` from `DesignSystemToast`.

### Changed
- Re-skinned Settings → Agents → Pending Wakes onto the shared listing
  shell. The legacy stacked `_PendingWakeCard` column is replaced by
  the same toolbar / row primitives Instances, Templates, and Souls
  use: search, an optional Type filter (only when both `pending` and
  `scheduled` records exist), Group by All / Type, and Sort by Due
  soonest (default) / Due latest / Name. Each row shows the linked
  task or project title (or the agent name when no subject is
  attached), agent kind + wake type pills, and a live countdown chip
  that ticks once a second (the absolute due timestamp surfaces as
  the chip's tooltip). Internal: the per-row `Timer.periodic` is
  replaced by a single page-scoped `wakeCountdownTickerProvider`;
  rows derive their visible countdown via
  `ref.watch(... .select(...))` so 1K rows collapse to one timer and
  only rebuild when their displayed string changes. New
  `agentPendingWakeRowVmsProvider` joins `pendingWakeRecordsProvider`
  with `pendingWakeTargetTitleProvider` (one parallel `Future.wait`)
  into `PendingWakeVm`s the page maps into the shared
  `AgentListRowData`. Removed the legacy `agent_pending_wakes_list.dart`
  and the inline `WakeActivityChart` from this tab — the chart still
  lives under the Stats tab as a 24h overview.
- Re-skinned Settings → Agents → Souls onto the shared listing shell.
  The legacy ModernBaseCard / ListTile column is replaced by the same
  toolbar / row / search primitives Instances and Templates now use:
  search input, Sort by Name (default) / Recent / Oldest, and a hue-
  tinted `SoulAvatar` initial-tile leading. Each row shows the soul
  name and the active version as a mono `vN` cell. Tap target (deep-
  link to the soul detail) and the create-soul FAB are unchanged.
  Internal: new `agentSoulRowVmsProvider` joins
  `allSoulDocumentsProvider` + `activeSoulVersionProvider` into
  `SoulVm`s the page maps into the shared `AgentListRowData`; the old
  inline `_SoulsTab` / `_SoulListTile` widgets are removed.

## [0.9.992]
### Added
- New inline `SidebarWakeQueue` block on the desktop sidebar's
  `aboveSettings` slot (handoff S1), gated by the new
  `show_sidebar_wake_queue` config flag (default off). Renders a
  `WAKES N` header, the next two pending wakes as compact
  `avatar · agent · ETA` rows, and an `Open list` / `+N more` link
  that opens the full Pending Wakes view. ETAs are localized: `now`,
  `mm:ss` under an hour, `Xh MMm` beyond — and switch to the warning
  colour inside the last five minutes. Each row has a trailing `×`
  button that calls `cancelPendingWake` (pending) or
  `clearScheduledWake` (scheduled). Tapping the row body deep-links
  into the agent's instance page. When the queue is empty the rows
  collapse but the header stays visible so the section never feels
  stuck.

### Changed
- `SyncActivityIndicator` is now a single fixed-width row
  (`• tx N · • rx N`) pinned to the bottom of the sidebar via the new
  `belowSettings` slot, so the inline Wake Queue can take its
  previous position above Settings. Each numeric column reserves a
  fixed slot — values right-aligned inside it — so the LEDs and
  labels never reflow as the outbox / inbox depths roll over between
  digit counts.
- Re-skinned Settings → Agents → Templates onto the shared listing
  shell. The legacy ListTile + ModernBaseCard list is replaced by the
  same toolbar / group / row primitives the Instances tab now uses:
  search input, optional Kind filter (only when 2+ kinds exist),
  Group by Kind / All, Sort by Name / Recent / Oldest. Each row shows
  the template name, model id, kind pill, and active version (`v{N}`)
  in the mono meta cell; a pending-review template gets an
  `AgentPalette.purple`-tinted leading icon instead of the legacy
  positioned dot. Tap target and FAB behaviour are unchanged.
  Internal: new `agentTemplateRowVmsProvider` joins
  `agentTemplatesProvider` + `activeTemplateVersionProvider` +
  `templatesPendingReviewProvider` into `TemplateVm`s the page maps
  into the shared `AgentListRowData`.
- Extracted the Settings → Agents → Instances scaffolding (page shell,
  toolbar, group section, row, filter chip row, soul avatar) into a
  shared `lib/features/agents/ui/listing/` layer so the Templates,
  Souls, and Pending Wakes tabs can be re-skinned through the same
  primitives in the next pass. Public API: `AgentListingShell`,
  `AgentListRowData` (with a closed `AgentListPillTone` enum and a
  `Widget Function(BuildContext)?` `trailing` slot), `AgentListLeading`
  (sealed: avatar / icon), `AgentListFilterAxis` / `GroupAxis` /
  `SortAxis`, and the pure `buildGroupedAgentList` pipeline.
  `AgentInstancesPage` is now a thin adapter that maps `InstanceVm`
  into the shared row VM; rendering, filter / sort / group state, and
  the empty / loading / error branches all live in the shell. This
  scaffolding extraction is internal-only — the Instances redesign
  below is what users will see.
- Redesigned Settings → Agents → Instances. Replaced the filter strips
  + card list with a denser layout: a toolbar with multi-select Filters
  (Type / Status / Soul), Group by (Soul / Type / Status), Sort
  (Recent / Oldest / Name), live search and a result counter; active
  filters surface below as removable chips with Clear all. Each row
  shows name + template + ID + type and status pills + last-activity
  time, under a collapsible group header that surfaces per-group active
  and total counts. The page now uses background level-02 to match the
  rest of the settings surface; the AppBar reads "Agent Instances"
  on this tab.
- Responsive layout: at narrow widths the toolbar wraps to multiple
  lines and the search input takes a full line below; instance rows
  stack title / template / ID, then pills + time + chevron, on two
  rows.
- Search field focus is painted on the outer border (teal accent +
  glow) instead of an inner Material underline.
- Internal: `_typeLabel` / `_statusLabel` helpers, `SoulOption`, and
  `hueForSeed` consolidated into one place; per-page filter counts
  bundled into a cached `FilterCounts` so they're computed only when
  the row list changes.

## [0.9.991]
### Added
- New unified `AiSummaryCard` on the task details page replacing the
  separate AI summary panel and decision activity strip. Single
  deep-teal-tinted-navy surface that hosts the agent TLDR, an inline
  expandable Goal / Achieved / What's left / Learnings report under a
  Read more / Show less pill, the actionable proposals list with
  swipe + button confirm-or-reject and a Confirm-all batch, a
  collapsible `History · N` toggle for resolved proposals, and a
  recent-activity footer (See activity / Hide activity) capped at six
  rows. The wake-cycle affordances (running spinner, run-now refresh,
  countdown pill, cancel-timer) sit directly in the header.
- New `AgentInternalsPanel` right-side overlay reachable from the
  agent name link, the footer avatar, or the "Open agent internals"
  pill. Clamped to 600–800 px on wide screens; on narrow screens
  (phones in portrait, slim split-view windows) it renders as a
  full-screen modal that slides up from the bottom. Hosts the same
  five tabs (Stats / Reports / Conversations / Observations /
  Activity) as the standalone agent detail page via the new shared
  `AgentInternalsBody` widget.
- Design-system tokens for the AI surface: `color.aiCard.*` (card
  background, raised surface, row, borders, accent + accent-soft,
  footer washes, body / meta / faint-meta text) and
  `color.proposalKind.{add, update, remove, priority, estimate,
  status, label, due}.{color, surface}`. The token generator now
  emits these new groups and the matching `DsColorsAiCard` /
  `DsColorsProposalKind*` classes. Five new localized strings cover
  the activity row's relative time labels (now / minutes / hours /
  days / weeks).

### Changed
- `task_form.dart` now mounts `AiSummaryCard` instead of the old
  `AgentSuggestionsPanel`. The legacy `AgentSuggestionsPanel` and
  `TaskAgentReportSection` widgets and their tests are removed (no
  remaining call sites).
- `AgentDetailPage` body extracted into the new shared
  `AgentInternalsBody` so the standalone page and the side panel
  render the exact same tabs.
- Agent and tasks feature READMEs updated to describe the new card,
  the side panel, and the shared body. The tasks README's "Visual
  surface" section now distinguishes standard `TaskDetailSectionCard`
  cards from the dedicated AI surface and links to a new follow-up
  doc, `docs/design/missing_density_typography_tokens.md`, which
  catalogs every place the card overrides `height` / `letterSpacing`
  on top of base typography tokens and proposes a `Compact/*`
  density tier.
- Settings root list is shorter and friendlier for new users.
  Habits, Categories, Labels, Dashboards, and Measurables now sit
  under a single new "Definitions" entry; Config Flags moved into
  the Advanced sub-page next to Logging, Maintenance, and About.
  Existing deep links (`/settings/habits`, `/settings/flags`, …)
  are unchanged so bookmarks keep resolving.

### Fixed
- Checklist body no longer leaves a fat empty band between the
  Open / Done / All filter strip and the first item on devices with
  a top safe-area inset (notched iPhones). The plain
  `ListView.builder` introduced in #3060 was inheriting the ambient
  `MediaQuery.padding.top` as its own top padding; it now passes
  `padding: EdgeInsets.zero` explicitly so the first row sits flush
  under the filter divider on every form factor.
- Linux geolocation rewritten as a dual-mode `package:dbus` client.
  Inside the Flathub sandbox `DeviceLocation` calls
  `org.freedesktop.portal.Location` (`XdgLocationPortal` in
  `lib/services/linux_location_portal.dart`); the portal mediates
  GeoClue on the app's behalf and Lotti now appears under GNOME
  Settings → Location → Permitted Apps. Outside the sandbox
  (`flutter run`, dev builds) it talks to `org.freedesktop.GeoClue2`
  on the system bus directly (`LinuxGeoClueClient` in
  `lib/services/linux_geoclue_client.dart`), because the portal
  rejects unsandboxed callers with `Access denied` (the portal keys
  authorization off the caller's Flatpak/Snap app-id, which is empty
  for host processes). The picker keys off `/.flatpak-info`. The
  previous code path used the abandoned `geoclue` Dart package,
  required `<desktop-id>` to be replaced by the caller, never appeared
  in GNOME's permitted-apps list, and had no `--talk-name` entry in
  the Flatpak manifest. The `geoclue` dependency is removed and the
  manifest now declares `--talk-name=org.freedesktop.portal.Desktop`.

  Note: GeoClue itself still depends on a working WiFi-based
  geolocation backend. On Ubuntu 24.04 the default Mozilla Location
  Service URL returns 404 since Mozilla deprecated MLS in 2024;
  point GeoClue at BeaconDB by dropping into
  `/etc/geoclue/conf.d/00-beacondb.conf`:

  ```ini
  [wifi]
  enable=true
  url=https://api.beacondb.net/v1/geolocate
  submission-url=https://api.beacondb.net/v2/geosubmit
  ```

  then `sudo systemctl restart geoclue`. Without a working backend
  Lotti silently falls back to IP geolocation on every platform that
  uses GeoClue under the hood.

## [0.9.990]
### Added
- Activity-filter pill row above the linked entries section on the task
  details page. Three toggleable pills (Timer / Audio / Images) hide or
  show the corresponding linked entry types; checklists keep their
  dedicated section at the top of the page. Pills follow the Figma
  spec — accent fill at 15 % alpha, accent border, accent label when
  active; design-system tokens drive Timer; Audio and Images use the
  Figma hex values until those colors land in the token set.
- Sort + filter modal opened from a "Newest first / Oldest first"
  trigger on the right of the activity bar. Reuses the
  `DesignSystemFilterChoicePill` and `DesignSystemFilterPalette` from
  the task list filter modal so both surfaces share one chrome.
  Includes a "Show hidden entries" switch using the existing
  include-hidden controller.

### Changed
- Linked entry cards now use `TaskDetailSectionCard` (the existing
  design-system card already used by the linked tasks section) instead
  of `ModernBaseCard`. Card padding aligned with the task list card —
  `tokens.spacing.step4` (12 px) horizontal, `step4` vertical at the
  bottom and `step1` (2 px) at the top so the trailing IconButtons in
  the entry header provide the visual breathing room without doubling
  it.
- Audio player no longer wraps itself in a second card. The redundant
  `ModernBaseCard` was removed so the player sits flush inside the
  entry's section card with just a thin vertical pad.
- Checklist card header padding tightened (`step1` top; collapsed state
  also drops bottom to `step1`) and the chevron is now a proper
  `IconButton` with `Collapse` / `Expand` tooltips, so it gains a hover
  state matching the adjacent menu button.
- "Checklists" subheading removed from the task details page. The
  per-task sort menu still appears (right-aligned) when there are two
  or more checklists.
- Extracted `DesignSystemFilterChoicePill` from the private task filter
  sheet into the shared `design_system_filter_shared.dart` so both the
  task filter modal and the new linked-entries filter modal render the
  same exclusive-choice pill — fill cross-fade, accent border alpha
  tween, constant border width, 400 ms animation.
- Linked tasks section on the task detail page is redesigned to match the
  Figma spec: a single expandable card with a count badge in the header,
  per-row "to"/"from" direction glyphs (info-blue / success-green), status
  circles, and dividers between rows. The overflow menu retains the
  existing link/create/manage actions.

## [0.9.989]
### Added
- AI assistant icon and skill menu now appear on text journal entries.
  Skills that consume entry text (coding-prompt generation, image-prompt
  generation, cover-art generation) work the same way whether the source
  is a typed note or a voice recording's transcript.
- New built-in **Generate Design Prompt** skill. Turns task context plus
  the entry's notes into a UI/UX design exploration prompt that defaults
  to five functional prototypes (override-able from the entry text),
  enforces design-system alignment when one is mentioned, and surfaces
  clarifying questions up front. Output is two-section Markdown ready to
  paste into Claude / Figma Make / v0.dev.
- New built-in **Generate Research Prompt** skill. Produces a structured
  Markdown research brief (Background, Research Questions, Scope,
  Deliverables, Source Preferences, expected output format, open
  questions) ready to paste into Claude with Research or ChatGPT Pro
  with Deep Research.

### Changed
- Built-in skills are now defined in code under
  `lib/features/ai/skills/built_in_skills.dart` and read via
  `skillRegistryProvider` instead of being seeded into the AI config DB.
  This removes the seeding round-trip and lets skill content stay in
  lockstep with the code that uses it. A future skill-management UI will
  introduce a separate user-override layer rather than re-introducing
  seeding.
- Generated-prompt cards now render the source skill's own name (e.g.
  "Generate Design Prompt", "Generate Research Prompt") instead of always
  showing "AI Coding Prompt". `AiResponseData` now carries an optional
  `skillId` so the same card can distinguish sibling skills that share the
  `promptGeneration` response type.

## [0.9.988]
### Changed
- Outbox post-drain settle window raised from 250 ms to 1500 ms and lifted
  into `SyncTuning.outboxPostDrainSettle`. Bursty edits (rapid typing,
  imports, multi-entity flows) now coalesce into the next bundle instead
  of shipping one bundle per write, so the outbox sends fewer, fuller
  trains while keeping the first-departure latency unchanged.

### Fixed
- Faster task-list, projects, and inbound sync queries via new SQLite
  indices and tighter sync transactions.
  - New partial index `idx_journal_tasks_status_priority_date` streams
    the open-tasks list ordered by `(task_priority_rank, date_from DESC)`
    without falling back to a temporary B-tree, even when many categories
    are selected.
  - New covering `idx_linked_entries_from_id_hidden_to_id` resolves the
    bulk linked-time-spans query index-only on the linked side.
  - New `idx_inbound_event_queue_status_enqueued` lets the queue-stats
    `COUNT(*) + MIN(enqueued_at)` poll seek by status and pick MIN from
    the index instead of scanning the full queue ledger.
  - `claimNextOutboxBatch` no longer scans the outbox: the original
    `status = pending OR (status = sending AND updated_at < cutoff)`
    predicate is now two indexed seeks merged in Dart, each picked up
    by the existing actionable partial index.
- Sync apply for journal entities holds the journal writer lock only
  around the actual writes. Cross-database awaits (sync-sequence log
  recording, pre-write `journalEntityById` reads) now run outside the
  journal transaction so concurrent readers no longer queue for
  hundreds of milliseconds per applied event.
- Removed the per-open self-heal block that re-issued
  `CREATE INDEX IF NOT EXISTS` on every database connection. With
  drift's read-pool the block ran nine times per launch (writer plus
  eight read isolates) recovering from an incident that has not
  occurred in production. `beforeOpen` is now just
  `PRAGMA foreign_keys = ON`; if a migration is ever interrupted on a
  future device the next schema bump will repair it.

## [0.9.987]
### Fixed
- Inbox backfill no longer hangs for ten minutes per agent-bundle row. Removed
  the agent wake-cycle bundling layer that coalesced per-wake agent writes into
  a `SyncAgentBundle`. With generic dequeue-time outbox bundling in place, the
  wake-bundle envelope was redundant — and after the outbox bundler started
  claiming text-only rows in batches it became actively harmful: bundled
  `SyncAgentBundle` rows shipped a manifest whose envelope-only entries no
  longer pointed at any uploaded attachment, leaving inbound rows stuck in the
  10-minute pending-attachment wait until they were skipped. Agent writes now
  hit the outbox directly as `SyncAgentEntity`/`SyncAgentLink` rows and flow
  through the same bundling path as journal entities. The `SyncAgentBundle`
  wire variant remains parseable so messages from peers that predate this
  change still decode; the receiver no-ops them and any children missing
  locally resurface via the existing per-(host, counter) backfill path.

## [0.9.986]
### Fixed
- Reduced idle CPU usage after starting and stopping task timers. Inactive
  desktop and mobile navigation tabs now disable tickers for their cached
  `IndexedStack` children, and task/project agent countdowns update only their
  small countdown pill instead of rebuilding whole report sections in hidden
  tabs. Running-timer task icons also rebuild only when the linked task changes.
- Inbound sync rows waiting for missing attachment or agent-bundle JSON now use
  a bounded 10-minute wait with long backoff instead of either retrying forever
  or being skipped by the generic attempt counter too early. If the attachment
  is still missing after the grace window, the row is abandoned and normal
  backfill recovery can handle the long tail.

## [0.9.985]
### Added
- Sidebar **Sync activity indicator** (variant D4a). When the new
  `show_sync_activity_indicator` config flag is enabled, the desktop
  sidebar gains an ambient two-row monospace strip just above
  Settings: `tx <outbox-depth>` / `rx <inbox-depth>`, each with a
  5×5 LED that flashes for ~140 ms per packet committed on that
  channel (TX = events uploaded to the homeserver, RX = inbound
  events applied locally). Tap navigates to Settings → Sync. When
  the flag is on, the legacy red `289` Settings badge is suppressed
  so the count is shown in exactly one place. Hidden in the
  collapsed sidebar — the strip is too narrow there. Default off;
  opt in via Settings → Config Flags.

## [0.9.984]
### Added
- Task agents can now propose user-reviewed edits to historical time
  entries linked from the current task. The wake prompt exposes editable
  non-running entry IDs with their current time range and text, the new
  `update_time_entry` tool validates task ownership and excludes the live
  timer, and the suggestion row renders a current-to-proposed diff before
  confirmation.

### Changed
- `create_time_entry` completed sessions now allow any valid
  `endTime > startTime` range, including future and midnight-spanning
  blocks. Running timers keep the existing today-only and not-in-the-future
  restrictions.
- DailyOS due-task hot path (`getTasksDueOn` / `getTasksDueOnOrBefore`)
  now reads a denormalized `due_at INTEGER` column on `journal` instead
  of `json_extract(serialized,'$.data.due')`. The partial
  `idx_journal_tasks_due_open` is rebuilt on the column so the planner
  streams `ORDER BY due_at ASC` straight from the index without
  per-row JSON parsing, eliminating the planner-fragility that required
  the previous `INDEXED BY` pin plus JSON-fallback safety net. The
  `due_at` shadow is populated by `toDbEntity` on every upsert and
  back-filled for every existing task with a non-null `data.due` —
  including completed and rejected tasks — by the v41 migration. The
  serialized JSON payload is unchanged; the column is purely a
  query-acceleration shadow.
- DailyOS calendar prefetch (`sortedCalendarEntries`) now coalesces
  concurrent per-day callers into a single union-range DB round-trip
  with client-side filtering, modeled on the existing
  `_coalesceOpenTasksDueUpTo` pattern. Slow-query telemetry showed
  22+ identical date-range queries firing in the same second during
  multi-day prefetch; the wave collapses them into one read.
- `retireExhaustedRequestedEntries` and `retireAgedOutRequestedEntries`
  now flip rows in `pageSize`-bounded batches, each in its own
  transaction, so a large backlog never holds the sync-DB writer lock
  through a single multi-second UPDATE. Previously a stuck-row
  backlog could pin the lock for ~1.9 s, starving concurrent reads.

### Fixed
- Improved sync reliability between devices.

## [0.9.982]
### Added
- New `DsPill` design-system primitive
  (`lib/features/design_system/components/chips/ds_pill.dart`) with
  `filled`, `tinted`, `outline`, and `muted` variants plus `DsGhostChip`
  and `DsDividerDot` companions. Shared anatomy: 28 px tall, pill
  radius (`radii.badgesPills`), `spacing.step3` horizontal padding,
  `spacing.step2` leading/trailing gap, `body.bodySmall`-sized label
  with optional override, optional leading/trailing slots, and Material
  ink-well that supports both `onTap` and `onLongPress`. The muted
  variant paints a 1 px dashed border via a private `CustomPainter`
  rather than pulling in `dotted_border` as a dependency.
- New `CreateChecklistItem` on the FAB's create-entry menu
  (`create_entry_action_modal.dart`). When the FAB sits on a task
  detail page (i.e. `linkedFromId` resolves to a `Task`), the menu now
  surfaces *Add Checklist* as the first entry; on every other surface
  the item self-hides.

### Changed
- **Task detail header — Option B redesign**
  (`docs/design/design_handoff_task_header/`,
  `lib/features/tasks/ui/header/desktop_task_header.dart`,
  `lib/features/tasks/ui/header/desktop_task_header_connector.dart`).
  The classification + metadata Wrap with pipe separators is replaced
  by a two-tier hierarchy:
  - A breadcrumb above the title — `▣ Category / Project name` — gets
    the categorical "where am I?" info out of the chip soup. The
    10×10 rounded category square is the *only* place the category
    color is used as a fill. Project name truncates with ellipsis;
    "No project" placeholder remains tappable. Each segment has a
    `surface.hover` background, no pill chrome.
  - A single horizontal pill row carries the *actionable* metadata
    (priority, due, estimate, labels). Priority is `DsPill.tinted`
    in its accent (P0 = error, P1 = warning, P2 = info, P3 = success)
    with the production SVG glyph at 14 px. Due is `DsPill.outline`
    that flips to `DsPill.muted` "No due date" when null and keeps
    the urgency tinting (overdue → error, today → warning, otherwise
    `text.mediumEmphasis`). Labels render as filled pills with an
    8 px color dot; long-press still surfaces the description dialog.
    The `+ Add Label` ghost chip is shown only when no labels exist —
    once labels are present, tapping any one opens the same selector.
  - The status select is rewritten as `_StatusPill` with a per-status
    18 % alpha tint (in-progress → info, blocked → error, on-hold →
    warning, groomed → interactive accent, done → success), neutral
    tint for "open", and a strikethrough low-emphasis treatment for
    "rejected".
  - `_TrailingAlignedWrap` — a custom multi-child render box —
    replaces the old `LayoutBuilder`-with-Row/Column branch. Leading
    chips wrap greedily; the status pill is pinned to the right edge
    of whichever row it lands on, falling onto its own right-aligned
    line only when it doesn't fit on the last leading row. No
    breakpoint-driven layout switch.
  - All chips read `tokens.typography.styles.others.caption` (12 px)
    so priority through status share one rhythm. The estimate label
    uses `text.lowEmphasis` to defer to the running tracker.
  - The estimate chip in the connector is rebuilt on top of `DsPill`:
    `DsPill.muted` "No estimate" when unset, `DsPill.filled` with a
    36 × 6 progress bar in the trailing slot when running,
    `DsPill.tinted` in the error color when overtime.
- **Tasks list filter chips** typography unified with the detail
  header — `ActiveFilterChip` now uses `others.caption` (12 px) and
  the trailing remove icon is sized to 20 px.
- **Task list cards** — when the user has narrowed the filter to a
  single status, the trailing status pill is now omitted on every
  card (`tasks_tab_page.dart` passes `showStatus:
  selectedTaskStatuses.length != 1` to `TaskBrowseListItem`). With
  zero or 2+ statuses selected the chip stays as a disambiguator.
- **Checklists section on the task detail page** —
  `lib/features/tasks/ui/checklists/checklists_widget.dart`:
  - The inline `+` "Add Checklist" button on the section header is
    removed. Adding the first checklist now lives exclusively on the
    FAB's create-entry menu.
  - When the task has zero checklists, the entire section
    (header + sort menu) collapses to `SizedBox.shrink` so the empty
    state doesn't dangle.
  - The populated section now sits with a `tokens.spacing.step5`
    (16 px) gap above it so it doesn't crowd the previous block.

## [0.9.981]
### Added
- Outbox message bundling, gated by the new `useOutboxBundlingFlag`
  config flag (default off). When enabled, `OutboxProcessor` claims a
  contiguous run of consecutive text-only outbox rows up to
  `SyncTuning.outboxBundleMaxSize` (50, tuneable up to 100) in
  `(priority, createdAt)` order and ships them as a single
  `SyncMessage.outboxBundle` envelope delivered as a sidecar JSON
  attachment under `/outbox_bundles/<uuid>.json`. Media-attachment rows
  always travel alone — the batch claim stops one before the next
  attachment row. Receivers download the sidecar via the existing
  attachment-ingestor pipeline and unpack it through
  `OutboxBundleUnpacker`, dispatching each child through the per-type
  apply path used for individually-delivered messages. Bursty workloads
  (agent suggestions, checklist creation, sync backfill replay) drop
  to roughly 1 Matrix event per ~50 rows. See ADR 0015 for the design,
  rollout, and per-child fault-isolation details.

## [0.9.980]
### Added
- Categories settings list now matches the Labels / Dashboards
  baseline. A `DesignSystemSearch` field above the list filters
  rows by name (case-insensitive substring); a "+" floating
  action button at the bottom-right opens the existing
  `/settings/categories/create` route. The legacy in-header
  "Add Category" text button is gone — the FAB is the canonical
  create affordance now and uses the design-system circular FAB
  component already consumed by the Tasks tab. New arb keys
  `settingsCategoriesSearchHint`,
  `settingsCategoriesNoMatchQuery`, and
  `settingsCategoriesCreateTitle` cover all six locales; the
  no-match empty state echoes the active query verbatim
  (`No categories match "<q>"`) so users know what they typed.
- `DesignSystemToast` grows two new affordances and is now the
  shared toast surface for the migrated call sites:
  - `ToastAction(label, onPressed, semanticsLabel?)` renders an
    inline call-to-action (e.g. "Undo") in the trailing slot. Action
    and dismiss can coexist; the action label inherits the tone's
    border color so the CTA reads as part of the tone, not a generic
    link.
  - `countdownDuration` paints a thin tone-coloured progress strip
    along the toast's top edge that drains over the supplied
    duration; `initialCountdownProgress` lets a resumed countdown
    pick up mid-bar.
  - `BuildContext.showToast` learns matching `action`, `countdown`,
    `initialCountdownProgress`, `replaceCurrent`, and `clearQueue`
    parameters; a new parallel extension
    `ScaffoldMessengerState.showDesignSystemToast` exposes the same
    surface to async callbacks that may outlive the calling widget
    (e.g. swipe-to-dismiss `onDismissed`, where the row is removed
    from the tree before the toast fires — captured `messenger`
    survives the unmount, captured `context` does not).
    `replaceCurrent: true` only hides the *current* SnackBar (items
    already queued behind it still appear afterwards);
    `clearQueue: true` calls `clearSnackBars()` so terminal-status
    toasts (e.g. "all confirmed") supersede every queued per-item
    toast.
  - The shared SnackBar wrapper auto-extends its visible duration by
    one second when `countdown: true` so the bar reaches zero before
    the SnackBar fades.
- Migrated `ScaffoldMessenger.showSnackBar` call sites that were
  semantically tone-coded notifications now go through
  `DesignSystemToast`:
  - Checklist item swipe-to-delete + swipe-to-archive (warning tone,
    5s / 2s countdown, Undo action) — replaces the old
    `showCountdownSnackBar` helper.
  - Checklist correction-capture pending toast (success tone,
    countdown matches `kCorrectionSaveDelay`, Cancel action) — the
    `CorrectionUndoSnackbarContent` widget now renders
    `DesignSystemToast` internally and ticks every 500 ms only to
    refresh the "save in N s" title; the countdown bar runs off a
    single animation controller so parent rebuilds don't stutter it.
  - Agents: per-row Suggestion confirm / reject and AgentSuggestions
    panel confirm-all (success / warning / error tones based on
    result), with strings + messenger captured before the await so
    the toast still fires after the row is unmounted by the
    suggestion list rebuild. Confirm-all and per-row result toasts
    use `clearQueue: true` so terminal status replaces any in-flight
    per-item toasts.
  - Sync: Backfill Sync `Catch up now` and `Retry skipped events`,
    plus the QueueDepthCard `Retry all skipped` action (success on
    completion, error on throw).
  Out of scope and not migrated in this release: the
  `AiConfigDeleteService` cascade-deletion SnackBar (custom rich
  body) and the saved-task-filter pill toast (custom rounded chrome).

### Changed
- Settings sidebar order: Sync now sits directly below Agents in
  the Settings V2 tree (root order: `whats-new`, `ai`, `agents`,
  `sync`, `habits`, `categories`, `labels`, `dashboards`,
  `measurables`, `theming`, `flags`, `advanced`). Agents and
  Sync are both runtime / system concerns and read better as a
  pair than separated by the taxonomy leaves
  (habits / categories / labels).
- Settings V2 desktop now exposes the **provisioned-sync** (QR
  pairing) entry point. The Sync branch was previously leafless
  on V2 desktop, so the `ProvisionedSyncSettingsCard` that the
  mobile `SyncSettingsPage` already renders had no equivalent
  surface — provisioned setup was effectively unreachable on
  desktop. The Sync branch now declares `panel: 'sync'` and a
  new `_syncPanel` builder in the registry hosts the same card
  inside a `SyncFeatureGate` + `DesignSystemGroupedList` so the
  visual treatment matches the rest of the V2 detail pane.
- Settings list-page FABs now use the design-system circular FAB
  component (`DesignSystemFloatingActionButton`) — the same
  visual primitive the Tasks tab already consumes — instead of
  raw Material `FloatingActionButton`. Migrated sites:
  `LabelsListPage`, `DefinitionsListPage` (the shared host for
  Dashboards / Habits / Measurables, via the public
  `FloatingAddIcon` helper), `AgentSettingsPage` (Templates +
  Souls tab FABs), `InferenceProfilePage`, and
  `AiSettingsFloatingActionButton`. The previously-extended AI
  FAB drops its inline per-tab text label in favour of the
  circular shape; the per-tab label survives as the
  `semanticLabel` so screen readers and hover tooltips still
  announce `Add Provider` / `Add Model` / `Add Profile`
  correctly. (Categories already adopted the DS FAB in the
  parity commit above.)

### Removed
- `lib/widgets/misc/countdown_snackbar_content.dart` (and its test)
  — the `CountdownSnackBarContent` widget and its
  `showCountdownSnackBar` helper had no callers left after the
  checklist swipe flows moved to `DesignSystemToast`'s native
  `countdown` + `action` API.

## [0.9.979]
### Added
- Keyword search on the Config Flags page. A `DesignSystemSearch`
  field above the list filters flags by their localized title or
  description (case-insensitive, leading/trailing whitespace
  trimmed). When no flag matches, a centered empty-state message
  replaces the list. The filter logic lives in a pure
  `filterDisplayedFlags` function so it can be unit-tested
  independently of `BuildContext`. The list itself is wrapped in
  design-system spacing tokens (`step2` vertical, `step4` between
  the field and the list) so the search affordance reads as part
  of the same surface rather than a floating chrome.
- The `enable_whats_new` config flag is now a user-toggleable entry
  in the Config Flags list (icon, title, and description sourced
  from the new `configFlagEnableWhatsNew{,Description}` arb keys
  across all locales). The DB-side flag definition was already in
  place — this surfaces the toggle in the UI so users can hide the
  What's New tree leaf without editing the database.

### Changed
- Config Flags page polish — four follow-ups on top of the keyword search:
  - The `DesignSystemSearch` field is now pinned at the top of the page
    while only the list of flag rows scrolls beneath it. `FlagsPage` opts
    its `SliverBoxAdapterPage` chrome into a new `fillRemaining: true`
    mode that hosts the body inside `SliverFillRemaining(hasScrollBody:
    true)` and folds the bottom-nav-occupied space into the body padding.
    `FlagsBody` itself becomes `Column[fixed search, Expanded(scrollable
    list)]` so the same restructure works inside the V2 detail pane
    (`'flags'` panel registry entry flips to `scrollable: false` since
    the body now owns its scrolling).
  - `DesignSystemListItem` gains a `subtitleMaxLines` parameter (default
    `1`, preserving the existing single-line ellipsis for every other
    caller). Flag rows pass `null` so long descriptions like "Generate
    AI summary for task actions" wrap onto a second / third line
    instead of truncating. Honored on both the plain-text `subtitle`
    and the `subtitleSpans` paths.
  - The flag list now hides the divider on hover — `_FlagsList` becomes
    stateful, tracks `_hoveredIndex` via the existing
    `DesignSystemListItem.onHoverChanged`, and suppresses the divider
    both *below the hovered row* and *above the next row* so the
    hovered row is never bisected by a hairline. Mirrors the polish
    already used in the task-list rows.
  - Added a horizontal page gutter and consistent vertical spacing so
    the search field and the rounded list container both honour the
    same edges; cards no longer sit flush against the screen edge.
- Backfill Sync settings page rebuilt around the Option C "compact ledger"
  design: a welded status row (Inbound queue · Missing · Skipped) at the top,
  a leader-dotted Sync statistics ledger, an `Automatic backfill` toggle, and
  a single collapsed `Advanced recovery` group containing every manual
  recovery action (`Catch up now`, `Retry skipped events` when present,
  `Manual backfill`, `Reset unresolvable`, `Re-request pending`,
  `Ask peers for unresolvable`, `Retire stuck entries`). All visuals are
  driven by design-system tokens — `DesignSystemButton`, `DesignSystemToggle`,
  `tokens.colors.*`, `tokens.spacing.*`, `tokens.radii.*` — so the page reads
  as part of the rest of Settings V2 instead of a one-off.
- Settings V2 (tree-nav + detail pane) is now the canonical desktop chrome.
  `SettingsRootPage` reduces to a plain mobile→`SettingsPage` /
  desktop→`SettingsV2Page` dispatch with no flag observation; mobile is
  unchanged.
- Settings V2 Agents tab is now URL-driven and the sidebar tree mirrors the
  in-page tab strip. Each tab gets a dedicated tree leaf under `Agents` in
  the same order as the in-page TabBar — `agents/stats`,
  `agents/templates`, `agents/instances`, `agents/souls`,
  `agents/pending-wakes` — and the `templates` / `instances` / `souls`
  panels are wrapped in `DetailIdDispatch` so the "+" FAB and row taps
  swap the right-hand panel between list / detail / create.
  `SettingsLocation` registers the bare
  `/settings/agents/{stats,templates,instances,souls,pending-wakes}`
  patterns so Beamer accepts them without falling through to a parent
  location, and `SettingsTreeUrlSync` carries a symmetric URL-driven
  guard alongside the existing tree-driven one so URL → tree sync
  preserves panel-local trailing segments (`/create`, a detail UUID)
  instead of canonicalizing them away. The in-page tab strip
  (`_AgentSettingsTabBar`) is hidden when `NavService.isDesktopMode` is
  true — exposing both navigation surfaces caused the URL → tree → URL
  feedback guard to leak across rapid tab clicks (silently swallowing
  subsequent sidebar / FAB / row beams) and let the sidebar selection
  drift out of sync because a top-tab click never expanded the parent
  branch in the sidebar. The body still resolves its content from the
  URL, so dropping the bar on desktop is purely additive; mobile / push-
  stack callers keep the legacy local-`setState` behavior.
- `DetailIdDispatch` forces `StackFit.expand` on its inner
  `AnimatedSwitcher` so Scaffold-based panel bodies (`AgentSettingsBody`,
  …) receive bounded constraints and lay out their `floatingActionButton`
  the same way they would unwrapped.

### Removed
- The `enable_settings_tree` config flag and its description, the legacy
  desktop `SettingsColumnStack` view, the `DisableV2Button` escape hatch
  (and its embeds in `EmptyRoot` / `DefaultPanel`), and the matching arb
  keys (`configFlagEnableSettingsTree{,Description}`,
  `settingsV2DisableAction`, `settingsV2DisableFailed`) across all locales.
  The `placeholderButtonIconSize` constant is gone with its sole caller.

### Fixed
- Category selection modal now closes itself when a row is tapped on
  mobile and narrow desktop. The bottom-nav redesign opens these
  modals on the **root** Navigator (above the bottom nav), but the
  picker callbacks were popping `Navigator.of(<outer-page-context>)`,
  which resolves to the per-tab nested Navigator the page lives in
  rather than the root Navigator that hosts the modal. Selecting a
  category therefore left the picker stuck open while the underlying
  per-tab stack popped. The four affected callers
  (`DesktopTaskHeaderConnector._showCategoryPicker`,
  `CategorySelectionIconButton`, `CategoryField`, `AddBlockSheet`)
  now name their `builder` argument `modalContext` and pop with
  `Navigator.of(modalContext).pop()` — the same pattern commit
  c6627fe8d already applied to the estimate / due-date / priority
  pickers, and that `ProjectDetailsPage._pickCategory` was already
  using.

## [0.9.978]
### Changed
- Settings V2 detail surface consolidated to a single page-title
  surface. The full breadcrumb path (e.g. `Settings › Sync ›
  Backfill Sync`) now lives in the page header at Heading 3
  typography — non-leaf segments are tappable and call
  `SettingsTreePath.truncateTo(depth)`, mirroring the click rules of
  the old in-pane crumbs. The new `SettingsV2TopCrumbs` reads ids
  from `settingsTreePathProvider` and resolves them against the
  shared `SettingsTreeScope.index`, falling back to just the root
  label when the scope isn't mounted. `LeafPanel` now returns the
  cached `IndexedStack` directly: the in-pane crumb trail, the
  Heading-3 leaf title, and the outer `step6 / step5` `Padding`
  gutter are all gone, so registered panels fill the detail pane
  edge-to-edge. The `_LocalCrumbs` and `_CrumbLink` helpers were
  deleted along with the `LeafPanel` test cases that exercised
  them; the remaining tests assert the IndexedStack matches the
  `LeafPanel` size (no outer Padding) and that no chevron renders
  inside the leaf subtree.
- Sync conflict resolution moved out of the **Advanced** branch and
  into the **Sync** branch in the Settings V2 tree. The leaf id is
  now `sync/conflicts` and the panel registry key is
  `sync-conflicts`. The Beamer URL stays at
  `/settings/advanced/conflicts` (and the `:conflictId` /
  `:conflictId/edit` subroutes are unchanged) so existing deep
  links and the legacy column-stack layout keep working — only the
  V2 tree shape and the panel registry / label resolver follow the
  reorg. The Sync branch is now always visible regardless of
  `enableMatrix`: the matrix-only leaves (backfill / stats / outbox /
  matrix-maintenance) are still flag-gated, but Conflicts stays
  reachable so legacy or local-only conflicts can always be
  resolved. The localized subtitle key was renamed
  `settingsAdvancedConflictsSubtitle` →
  `settingsSyncConflictsSubtitle` to match the new branch.

- Task agents now react immediately to recorded audio. Brand-new task agents
  on a blank task no longer surface a "wake in 2:00" countdown — the
  orchestrator skips the throttle deadline while the agent is awaiting
  content, and the content gate keeps the agent from running until real
  content arrives. The moment a transcription finishes (cloud or realtime),
  the task agent is nudged via a manual wake that bypasses the standard
  throttle, so the user does not wait through a 2-minute window after
  speaking. Subsequent typing edits still go through the normal 2-minute
  coalescing throttle. Implemented via a new `WakeReason.transcriptionComplete`
  and an `awaitingContent` mirror in `WakeOrchestrator`, populated by
  `TaskAgentService` on creation and restoration.

## [0.9.977] - 2026-04-25
### Review polish (Settings V2)
- `SettingsTreeView` and `SettingsDetailPane` now share a single
  tree + `SettingsTreeIndex` via the new `SettingsTreeScope`
  inherited widget hosted by `SettingsV2Page`. The five config-flag
  subscriptions and the `buildSettingsTree` call happen exactly
  once per page mount instead of being duplicated in each consumer,
  and the two views can no longer disagree on the tree shape.
- Leaf panel bodies are now kept mounted across sibling-leaf
  switches: `SettingsDetailPane`'s `AnimatedSwitcher` uses a stable
  `'leaf'` key and `LeafPanel` caches visited bodies behind an
  `IndexedStack`, so scroll position, filter state, and in-flight
  async loaders survive when the user pings between sibling
  entries (e.g. `agents/templates` ↔ `agents/souls`).
- Panel registry switched from an ad-hoc `_scrollable(...)` wrapper
  to a declarative `SettingsPanelSpec(build: ..., scrollable: ...)`
  so each body opts in to the outer `SingleChildScrollView` at the
  registration site — contributors can't accidentally double-scroll
  a `CustomScrollView`-bearing body any more.
- `SettingsTreeUrlSync` replaces its single `_programmaticBeam` bool
  with a counter so overlapping rapid taps don't leave the
  URL → tree guard stuck or released early between post-frame
  callbacks.
- `SettingsTreeNavWidth` splits its `_userAdjusted` flag into a
  user-intent flag and a persisted-load-race flag, guards against
  state writes after dispose, and cancels queued persists from the
  debounce timer when the notifier has been disposed.
- `SettingsTreeIndex.build` now reports duplicate node ids via a
  pluggable `duplicateReporter` callback (defaults to `debugPrint`),
  so duplicates remain visible in release builds and not just in
  debug asserts. `ancestors(id)` returns the pre-wrapped
  unmodifiable view stored on the index rather than allocating a
  fresh copy per read.
- `beamUrlToPath` canonicalizes URLs by stripping `?query` and
  `#fragment` before prefix matching, so settings URLs carrying
  query parameters resolve to the correct leaf instead of
  collapsing to the empty root.
- Misc cleanup: `SettingsTreePath` uses stdlib `listEquals`,
  the escape-hatch fallback now writes the shared
  `enableSettingsTreeFlagDescription` constant rather than an empty
  string, and the breadcrumb link uses design-token spacing and
  radii in place of hardcoded 4/2 dp values.

### Fixed
- Bottom navigation bar polish: the sync outbox badge on the Settings tab now
  sits in the top-right of the icon to match the Tasks badge, and the audio
  and time recording indicators dock flush against the visible nav-bar pill
  instead of floating above it.
- Desktop linked-task navigation no longer takes over the full window. Tapping
  a linked task from a task's details now pushes onto a per-pane stack inside
  the right-hand details area, leaving the task list pane visible. The back
  arrow at the top of the task details only appears on desktop when a linked
  task is on top of the stack, and clicking it pops back to the previous task
  instead of being a no-op. Mobile navigation is unchanged.

### Added
- Saved filters for the Tasks tab. Build a filter (status, priority,
  category, agent, etc.) in the Tasks Filter modal, tap the new **Save**
  button next to Apply, give it a name, and pin it under "Tasks" in the
  expanded sidebar. Saved filters live in `SavedTaskFiltersController`
  (Riverpod, `keepAlive: true`), persist as a JSON list under
  `SAVED_TASK_FILTERS` in `SettingsDb`, and surface as a treeview with
  active-state highlight, hover-revealed two-tap delete, double-click
  inline rename, drag-to-reorder, and a "Tasks · {filter name}" indicator
  in the tasks pane header. Activating a saved filter applies it via
  `JournalPageController.applyBatchFilterUpdate` while preserving the
  ephemeral search query.

## [0.9.976] - 2026-04-25
### Changed
- Agent wake cycles now sync as one bundled Matrix payload instead of emitting
  one outbox row per agent entity/link mutation. `AgentSyncService` wraps wake
  execution in a zone-local `AgentWakeSyncInterceptor` keyed by the wake run,
  buffers only agent entity/link messages, deduplicates by id, preserves
  superseded child vector clocks via `coveredVectorClocks`, and flushes a
  descriptor-backed `SyncAgentBundle` to the outbox when the wake exits.
  Receivers resolve the bundle attachment, apply entities before links through
  the existing agent sync handlers, and record each child payload in the
  sequence log so the convergence/backfill contract stays unchanged while wake
  traffic collapses to one Matrix message.
- `runInWakeCycle` is reentrant-safe (nested calls reuse the active
  interceptor) and routes nested-transaction post-commit messages into the
  wake buffer so multi-transaction wakes still ship as a single bundle.
- The success-path bundle flush now swallows and logs outbox failures via
  `DomainLogger` instead of failing the wake run — the database writes have
  already committed, and maintenance/backfill paths can resurface the
  committed rows. The failure-path flush continues to attempt one final
  bundle send before re-throwing the original wake error.
- The interceptor's merge step only carries forward the SUPERSEDED clock
  (`previous.vectorClock`), since `OutboxService._prepareAgent{Entity,Link}`
  already adds the current clock to `coveredVectorClocks` downstream and the
  receiver's `_filterCoveredVectorClocks` strips it again before pre-marking
  covered counters.
- Matrix verification emoji sequence now wraps onto multiple lines on narrow
  phone viewports. The 7-emoji row was overflowing horizontally on Samsung
  devices in portrait (`RIGHT OVERFLOWED BY 24 PIXELS`), cutting off the
  last cell. `VerificationEmojisRow` now uses a `Wrap` layout so the cells
  flow onto a second line when the screen width is constrained while
  keeping centered alignment on wide screens.
- Resync Settings (Sync → Maintenance → Re-sync messages) now has an "Entity
  types" section with two checkboxes — "Journal entities" and "Agent
  entities" — both on by default. Unticking "Agent entities" lets the user
  bypass the agent-entity sweep when catching up a fresh device, where the
  agent corpus can otherwise enqueue ~20k entries and dominate the backfill
  cost. The Start button disables and an error hint shows when neither
  checkbox is selected; `Maintenance.reSyncInterval` enforces the same
  contract and emits a single `MAINTENANCE/reSyncInterval` log line if the
  call is invoked with both flags off.
- Linux: emojis no longer render as tofu in agent reports, journal text, or
  any widget consuming a design-system text token. The token generator now
  emits `fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto
  Color Emoji']` on every `TextStyle` so widgets that bypass the
  `ThemeData`-level fallback (e.g. `AgentMarkdownView`) still resolve the
  correct emoji glyphs. The global theme's emoji fallback was widened from
  Linux-only to all non-web platforms — fontconfig (or the equivalent on
  each OS) ignores missing families so listing all three is harmless. The
  previously-broken `linux/install_emoji_fonts.sh` now ships its
  `flatpak/75-noto-color-emoji.conf` companion so the script runs without
  errors on Ubuntu/Debian dev boxes.
- New attachment family `/agent_bundles/<wakeRunKey>.json` is recognized by
  `isAgentPayloadPath`, the matrix stream helpers' `extractJsonPathFromEvent`,
  and the queue-apply adapter's transient attachment-error filter. Wake run
  keys are URL-encoded in bundle file paths to keep them within the documents
  directory.

## [0.9.975] - 2026-04-25
### Added
- Task Agent now sees the active running timer when one is running. If the
  timer is for the task being woken, the agent gets full details (timer
  id, started, live tracked range, elapsed minutes, current entry text)
  and can propose a richer description via the new `update_running_timer`
  tool instead of stacking a parallel `create_time_entry` — user-gated,
  replaces the timer entry text outright on approval, and keeps the
  in-memory `TimeService` snapshot in sync with the persisted `entryText`,
  `dateTo`, and `updatedAt`. If the timer is for a different task, only
  the live tracked range is exposed (no id, no other-task identity, no
  entry text) so the agent can avoid proposing `create_time_entry`
  intervals on this task that overlap with what is already being tracked
  elsewhere. Source-task ownership is checked before the `timerId`
  comparison so the active timer id is never echoed across task boundaries.

### Changed
- `create_time_entry` no longer rejects completed sessions whose start day
  is earlier than the wake day. The agent can now log a session the user
  dictates from yesterday or further back; the same-day constraint between
  `startTime` and `endTime` (no entries spanning midnight) and the
  not-in-the-future cutoff at wake time are preserved.
- `PersistenceLogic.updateJournalEntityText` now returns `false` when its
  catch block fires, mirroring the contract of `updateJournalEntity`. A
  caught exception during the update no longer surfaces as a silently-true
  result with only a logged exception, so callers (including the new
  `update_running_timer` flow) can rely on the boolean to decide whether to
  proceed with downstream side effects.

## [0.9.974] - 2026-04-25
### Changed
- Task Details typography pass: the entry editor, AI summary (TLDR + expanded
  report), Task Agent reports/conversations markdown, linked-task titles, and
  agent suggestion items now pull font family, sizes, and weights directly
  from the design-system tokens. The editor body and agent markdown body share
  `body.bodySmall` (Inter, 14pt, w400); editor headings map to
  `heading.heading3` / `subtitle.subtitle1` / `subtitle.subtitle2`;
  linked-task titles use `subtitle.subtitle2`. Code blocks gain a subtle
  theme-aware surface (`background.level02` lifted by the `surface.enabled`
  overlay), a 1-px low-emphasis border, and DS radii (`radii.xs` inline /
  `radii.s` block). The Task Agent markdown checkbox is now compact,
  non-interactive (no hover overlay or click cursor), and shares the
  checklist row's `radii.xs` rounded shape, low-emphasis border, and
  `interactive.enabled` fill.
- The AI Coding Prompt / AI Image Prompt card on Task Details now renders
  both its TLDR summary and its expanded full-prompt body through the shared
  `AgentMarkdownView`, so its typography, links, and code-block surfaces
  match the agent report and entry editor (`body.bodySmall` body text, DS
  heading mapping, low-emphasis checkbox style) instead of the package-default
  `GptMarkdown` styling.

## [0.9.973] - 2026-04-24
### Fixed
- `VectorClockService` now advances its persisted counter only after the
  associated write + outbox enqueue both succeed. A new reservation API
  (`reserveNextVectorClock` returning a `VcReservation`, plus a
  `withVcScope` zone-based wrapper) bumps the in-memory watermark
  synchronously so concurrent reservations stay collision-free, but
  `commit` is what persists to `SettingsDb`; `release` rewinds the
  in-memory watermark when the reservation was the latest. The known
  burn call sites — `PersistenceLogic.createDbEntity`, `updateDbEntity`,
  `updateJournalEntity`, `createLink`, plus
  `AgentSyncService.upsertEntity`/`upsertLink`/`insertLinkExclusive`
  and the outermost `runInTransaction` — are now wrapped in
  `withVcScope` so an `applied=false` rejection, a transaction
  rollback, or an exception anywhere between `getNextVectorClock()` and
  `outboxService.enqueueMessage()` rolls the counter back instead of
  burning a gap that only backfill could close. `getNextVectorClock()`
  stays available for low-stakes callers — outside a scope it still
  auto-commits; inside one it auto-attaches. Follow-up to the atomic
  claim fix in this release, which closed the merge-send race but
  could not help counters burnt before any outbox row was ever created.
- Outbox processor now atomically claims the next row (pending →
  sending) via `OutboxRepository.claim()` instead of reading it as
  `pending` and sending it with a stale snapshot. Under the old
  path, a merge that fired during the ~hundreds of ms of send I/O
  would `updateOutboxMessage` the row in place (matching
  `status=pending`), the processor would still send the pre-merge
  payload and mark the row `sent`, and the merged
  `coveredVectorClocks` — including the old VC the merge existed
  to preserve — were silently abandoned. The result was scattered
  single-counter holes that the receiver flagged as missing and
  that only backfill could resolve. With the atomic claim the row
  is `sending` during send, merges' CAS-on-pending update no
  longer matches, and the merged content is spilled into a fresh
  pending row that still rides its own Matrix event. The legacy
  `fetchPending + refreshItem` pair is gone; the actor-side
  `OutboundQueue` already used the same claim and is now on a
  shared repository contract.

## [0.9.972] - 2026-04-21
### Added
- Settings V2 foundations behind the `enable_settings_tree` config
  flag (desktop only; default off). First three steps of the A2
  tree-nav + detail-pane rollout documented in
  `docs/design/settings/settings_v2_implementation_plan.md`:
  the domain layer (`SettingsNode`, `NodeBadge`, `NodeTone`,
  `buildSettingsTree(...)`, `SettingsTreeIndex` with
  `findById` / `ancestors` / `pathToBeamUrl` / `beamUrlToPath`);
  the state layer (`SettingsTreePath` notifier implementing the
  four click rules from spec §3 plus `syncFromUrl` / `truncateTo`
  / `clear`, and a `SettingsTreeNavWidth` notifier that
  clamps to 280-480 dp with a 300 ms debounced persist under the
  distinct `SETTINGS_TREE_NAV_WIDTH` key); and the chrome
  (`SettingsV2Page` with a fixed 56 dp header, a locale-backed
  `SettingsTreeView` rendering every flag-gated root node via
  `SettingsTreeNodeWidget`, the `SettingsTreeResizeHandle` with
  drag / double-tap reset / arrow-key ±8 / shift-arrow ±32 /
  Home-to-default, and a detail-pane placeholder with a persistent
  "Disable Settings V2" button — the escape hatch back to the
  legacy column stack, since no real panels are wired up yet).
  `SettingsRootPage` picks the surface via a flag watch on
  `enableSettingsTreeFlag`; with the flag off the legacy
  multi-column stack is unchanged.
- Stray `/settings/maintenance` pathPattern in
  `lib/beamer/locations/settings_location.dart` replaced with the
  canonical `/settings/advanced/maintenance` — every caller
  already routed through the latter, and the A2 tree index now
  points at the single canonical URL. The old `/settings/maintenance`
  URL is kept as a pattern alias that renders the same
  `MaintenancePage`, so any hand-edited bookmark that hit the
  advertised pattern on `main` keeps working.

### Changed
- `BackfillRequestService` now skips analysis+dispatch while the
  `BridgeCoordinator` is mid-walk (forward-reading fresh timeline
  events from the last applied event id). Gaps observed during the
  walk may be closed by events still in the pipe, so the periodic
  timer and `nudge()` wait for the walk to conclude before asking
  peers for anything — preventing bogus ~100-entry requests that
  raced ahead of the inbound path. Exposed via a new
  `QueuePipelineCoordinator.isBridgeInFlight` getter forwarded from
  the bridge's existing `_inFlightBridge` state. Manual
  `processFullBackfill` bypasses the gate so a user action is never
  silently dropped.
- Sync V2 is now the only inbound pipeline. The
  `use_inbound_event_queue` config flag, its Flags-page toggle,
  localized strings, and the `suppressLegacyPipeline` switch on
  `MatrixService` are gone. `QueuePipelineCoordinator` is a required
  constructor argument, the consumer's live ingestion is always
  suppressed, catch-up routes unconditionally through the
  coordinator's bridge, and the legacy connectivity-driven
  `forceRescan` coalescing plus the `_maybeStartQueuePipeline`
  flag-branching are removed. Settings seed, CI database expectations,
  and the integration-test helpers were trimmed to match.
- Checklist "Add a new item" pill border now lights up on focus. The
  previous fix that silenced the themed inner outline left the outer
  pill visually static on tap, removing the last affordance that the
  field was actually editable. `_AddItemField`'s outer `AnimatedContainer`
  now listens to `widget.focusNode` and cross-fades its 1 px border
  between `tokens.colors.decorative.level01` (idle) and
  `tokens.colors.interactive.enabled` (focused) over 200 ms easeInOut.
  Border width stays pinned at 1 px so the pill never breathes across
  the transition, and sibling rows in the checklist don't shift.
- Desktop Settings is now a horizontally scrollable multi-column
  layout instead of a two-pane list + detail. Every meaningful level
  of the route tree renders as its own column: `/settings/sync`
  stacks `SettingsPage + SyncSettingsPage`, `/settings/sync/backfill`
  adds `BackfillSettingsPage` as a third column on the right, and
  label/category/dashboard/measurable/habit/agent drill-downs work
  the same way — up to five columns for
  `advanced/conflicts/<id>/edit`. Columns share a single fixed
  width (the previously-draggable `listPaneWidth`, now pinned so the
  rest of the layout stays put), the rightmost column expands to
  fill any remaining viewport, and the row becomes horizontally
  scrollable with an auto-scroll to the newly-added column when the
  stack no longer fits. Drilling from Sync into Backfill adds the
  third column on the right instead of replacing the Sync sub-menu.
  Mobile keeps the single-page push navigation fallback.
- Settings list rows now match the task list's subdued treatment.
  `DesignSystemListItem`'s default activated-row fill moved from the
  saturated `tokens.colors.surface.active` to the new shared
  `DesignSystemListPalette.activatedFill` — `interactive.enabled` at
  12 % opacity, the same source the task-list palette now consumes —
  so selection reads as a gentle hint rather than a loud block. The
  component also gained an `onHoverChanged` callback and a
  `dividerColor` override; the settings root menu uses both to
  coordinate divider visibility across rows, fading the 1 px line
  between any two rows to transparent whenever either is hovered or
  active. The divider keeps its reserved 1 px of vertical space, so
  hover never causes the column to jitter, and hover tracking is
  keyed by item identity rather than list index so feature-flag
  toggles can't strand the suppression on the wrong row.
- Queue-pipeline `InboundWorker` now fans the adapter's prepare phase
  out across the whole batch via `Future.wait`. Prepare is I/O-bound
  (attachment downloads, gzip decode, JSON decode) with no shared
  state, so running it in parallel collapses each batch's prepare
  critical path to the slowest entry instead of the sum. Apply still
  runs sequentially inside `journalDb.transaction` to preserve the M1
  writer-lock discipline, and prepared payloads are cached by
  `eventId` so apply consumes each one exactly once. Directly
  addresses the cold-start catch-up throughput cliff where every
  entry waited on its predecessor's attachment download before its
  own prepare could begin.

### Changed
- Reconnect bridge now attempts a forward-walk from the last applied
  event id. Previous reconnect behaviour walked the SDK's cached
  timeline backward from newest-cached to oldest-cached; when the
  cache already reached months below the current `lastAppliedTs`,
  every page trivially crossed the boundary on page 0 and the bridge
  stopped without hitting the server — so a reconnecting client had
  to rely on peer backfill responses to close gaps in the
  `[lastAppliedTs, now]` window. The bridge now calls
  `room.getTimeline(eventContextId: lastAppliedEventId)` (Matrix
  `/rooms/{id}/context/{eventId}`) for a fresh server-side slice
  anchored at the marker, then `timeline.requestFuture()` paginates
  `/messages?dir=f` toward the tip. Backward walk remains as a
  fallback when no anchor is known or when the server cannot resolve
  the anchor. Unverified in production — needs observation against a
  real reconnect with a known gap before we can claim it actually
  closes the peer-dependent case.

- Outbox drain no longer stop-and-go-crawls through large backlogs.
  `_drainOutbox` was capped at 20 passes per runner callback, after
  which it bounced back through `ClientRunner.enqueueRequest` — which
  meant the `UserActivityGate.waitUntilIdle` check and the runner's
  FIFO queue traversal fired once every 20 items instead of once per
  drain. `OutboxProcessor` also fetched 10 rows per call via
  `fetchPending(limit=10)` and threw nine away to send only the
  oldest. The pass cap is now 2000 (effectively "drain everything in
  one pass, with a pathological safety net"), and the processor
  fetches just 2 rows (the head-of-queue plus a cheap `hasMore`
  probe). Together, a thousand-row outbox that previously took ~50
  runner re-entries + 9000 wasted row reads now drains in one runner
  pass with zero waste — the observable symptom being outbox
  throughput that looks pathologically slow under bulk enqueues.

- Queue pipeline now drops self-echoed events at the live-timeline
  ingress. Every message this device sends via the outbox comes right
  back through Matrix's `/sync` on the same room — the legacy pipeline
  consulted `SentEventRegistry` to short-circuit those echoes, but the
  new queue pipeline was missing the check, so every outbox send
  turned into an extra inbound enqueue + prepare + apply + attachment
  download. Under a large outbox drain this quietly doubled the DB
  pressure and blocked genuine peer events behind thousands of
  no-op-self-echoes, which is what made outbox throughput look
  pathologically slow. `QueuePipelineCoordinator._handleLiveEvent`
  now consumes from the shared `SentEventRegistry` before touching the
  queue or the attachment ingestor, and logs a coalesced summary line
  (one every 30s) with the suppressed count.

- Reconnect bridge no longer exits prematurely when the SDK's local
  timeline cache hadn't loaded the wake-up window yet. Before the fix,
  a single boundary-crossing page whose events were all
  duplicates/filtered-out still satisfied the "boundary reached" stop
  condition, leaving gaps in `[untilTimestamp, now]` to be filled by
  the slower backfill cadence. `collectHistoryForBootstrap` now keeps
  paginating past the boundary for up to `boundaryContinuationCap`
  (5) extra `/messages` round-trips when the sink reports `accepted=0`,
  giving the SDK a chance to pull more history into its cache.
  Paired with this, `QueuePipelineCoordinator` now records a
  "barren bridge" signal whenever a reconnect walk finishes with
  `boundaryReached` and zero total accepted events — the precise
  signature of a wedged cache — and the next sequence-log gap
  detection triggers a one-shot unbounded `collectHistoryForBootstrap`
  to close the hole aggressively instead of waiting for the normal
  backfill cadence. Single-flight guarded so a burst of gap signals
  coalesces onto one walk, and the signal expires after 5 minutes so a
  stale wedge from hours ago cannot hijack a later gap.

- Checklist "Add a new item" pill no longer sprouts a second outline
  when focused. `_AddItemField` wraps a `TextField` in a container
  that draws its own 1 px pill border, but only set
  `border: InputBorder.none` on the inner field — so the app's shared
  `InputDecorationTheme.focusedBorder` (a 2.5 px primary-colour
  outline) still overlaid itself inside the pill on tap. Every
  state-specific border (`enabledBorder`, `focusedBorder`,
  `disabledBorder`, `errorBorder`, `focusedErrorBorder`) plus
  `filled` / `fillColor` are now explicitly neutralised on the
  decoration, so the field stays visually flat inside the pill in
  all focus states.

- New "Ask peers for unresolvable entries" action on the Backfill
  Settings page. Flips every `unresolvable` sequence-log row back to
  `missing` so the normal backfill sweep re-asks peers — covers the
  case where the originating host is dead but a currently-alive peer
  still has the payload. Complements the narrower "Reset Unresolvable"
  action, which only resets rows whose `entry_id` is already known
  locally (a tiny subset after a bulk retirement event). Confirmation
  dialog with row count before the flip.

- New "Retire stuck entries" action on the Backfill Settings page.
  Runs `retireAgedOutRequestedEntries(amnestyWindow: Duration.zero)`
  after a confirmation dialog, promoting every currently-open
  `missing`/`requested` sequence-log row to `unresolvable`. Bypasses
  the 7-day amnesty window for the case where a user has identified
  stuck rows blocking the watermark and wants immediate recovery
  without waiting for the periodic sweep.

- `agent_links` upsert no longer fails when a sync-incoming
  `soul_assignment` or `improver_target` link arrives with a new `id`
  but the same `from_id` (soul) or `to_id` (improver) as an existing
  active row. `insertOnConflictUpdate` only handles primary-key
  conflicts, so the partial unique indexes
  (`idx_unique_soul_per_template`, `idx_unique_improver_per_template`)
  threw `SqliteException(2067)` — apply was classified retriable,
  retries exhausted after 10 attempts, and the queue row was silently
  abandoned. `upsertLink` now preemptively soft-deletes the colliding
  active row under the same transaction before inserting, matching
  the v6 migration's duplicate-cleanup pattern. Soft-deleted rows stay
  in the table as tombstones for audit.

- Stuck `sync_sequence_log` rows no longer block the watermark
  indefinitely. A row can slip into `requested` via the
  backfill-response-hint path (which never sets `last_requested_at`)
  or age out of the active backfill window before hitting the
  request-count cap — in either case the row sat in a non-terminal
  status forever, preventing `getLastCounterForHost`'s contiguous
  prefix from advancing and causing every new event on the same host
  to re-emit the same gap range through gap detection. A new
  age-based retire runs alongside the existing exhausted-retire on
  every backfill sweep: any `missing`/`requested` row older than
  `SyncTuning.backfillAmnestyWindow` (7 days) is promoted to
  `unresolvable` regardless of `request_count`. Observed state on a
  real pair of devices: 3 rows on desktop and 4 on mobile, all
  created April 8, permanently blocking the watermark — they now
  retire on the next sweep and gap re-detection stops.

- Outbox no longer grows unbounded. `status = sent` rows are pruned
  after 7 days; `error` rows are kept forever so persistent failures
  remain inspectable, and `pending`/`sending` rows are never touched.
  Observed before this change: 395k sent rows on desktop, 265k on
  mobile — a direct contributor to slow outbox enqueue/dedup queries
  and heavier WAL checkpointing. The sweep runs at startup (after a
  30-second grace so it doesn't contend with init) and every 24 hours
  thereafter.

## [0.9.969] - 2026-04-21
### Fixed
- Task title edit affordance restored. The new `DesktopTaskHeader`
  rendered the title as plain read-only text and showed nothing when a
  task had no title, leaving users with no obvious way to tap into the
  inline editor. The read-only title now renders a trailing pencil
  (`Icons.edit_outlined`) next to the label, and empty titles display a
  localized "No title" placeholder in the same tappable slot. Task list
  rows in turn render the existing `taskUntitled` "(untitled)" label in
  the design-system error color + italic so missing titles stand out
  rather than silently collapsing the row.

## [0.9.968] - 2026-04-20
### Fixed
- Three Phase-2 queue-pipeline gaps flagged in the design review:
  (1) when the sync room is picked after `MatrixService.init()` or the
  user switches rooms, `MatrixService.saveRoom` now calls a new
  `QueuePipelineCoordinator.onRoomChanged` hook that seeds the new
  room's `queue_markers` row and prunes rows belonging to previous
  rooms — otherwise the worker replays stale rows against the new
  room and the new room never gets a marker. (2) On cold start under
  the queue flag, `QueuePipelineCoordinator.start()` now fires a
  background `bridge.bridgeNow()` pass once the worker and bridge are
  attached, mirroring the 300 ms startup `forceRescan` the legacy
  pipeline runs — reconnects whose timeline is not flagged `limited`
  no longer silently drop events delivered during login. (3) The F7
  `stop(drainFirst: true)` path now uses a new `drainUntilEmpty` loop
  that flushes the decryption pen, sleeps until each retry lease
  matures via `InboundQueue.earliestReadyAt`, and re-peeks until the
  queue is empty or `drainUntilEmptyTimeout` (30 s) elapses — the
  previous single `drainToCompletion` returned as soon as no rows
  were ready at call time, stranding retriable / decryption-pending /
  noRoom rows across a flag-off restart.

### Added
- Phase 0 sync diagnostic observability (additive logs only; no behaviour
  change). `MatrixStreamSignalBinder` now records two probes on the sync
  room: a `sync.limited` line with `prevBatch`, `eventCount`, and the
  `sinceMs` gap since the previous sync response whenever the Matrix
  server returns `timeline.limited == true`; and an
  `onTimelineEvent.ordering` summary every 100 events tracking strict
  reorderings and same-timestamp ties. Both route through the
  `MATRIX_SYNC` log domain into the dated `sync-*.log` file. Data feeds
  the Inbound Event Queue redesign (`docs/sync/2026-04-20_inbound_event_queue_design.md`).
- Stateful inbound sync queue (Phase 1 + 2), gated on the
  `USE_INBOUND_EVENT_QUEUE` settings flag (default off). When the flag
  is on, live events, the `limited=true` bridge, and the new
  "Fetch all history" / "Catch up now" actions route through an
  `InboundQueue` (Drift-backed, stored in `sync_db`) + `InboundWorker`
  with a single drain loop per room. Per-room markers live in a
  new `queue_markers` table so commit + marker advance is atomic
  and monotonic via `TimelineEventOrdering.isNewer`. Encrypted events
  are held in a `PendingDecryptionPen` so pre-decryption ciphertext
  never lands in `raw_json`. The legacy `MatrixStreamSignalBinder`
  is suppressed when the flag is on, keeping the two pipelines
  mutually exclusive. Sync Settings gains a flag-gated queue
  section with a depth card, a Catch-up-now button, and a
  Fetch-all-history dialog with per-page progress and cancel.
  Pipeline-tagged log lines (`pipeline=queue` / `pipeline=legacy`)
  let the Phase-2 validation gate compare apply rates between the
  two paths.

### Fixed
- Desktop UI freeze during Matrix sync. The per-event apply loop in
  `MatrixStreamProcessor` used to hold the SQLite writer lock while
  awaiting attachment downloads, gzip decodes, and disk reads — on an
  20-event catch-up slice this blocked user-driven journal saves for
  seconds at a time. `SyncEventProcessor` now splits into `prepare`
  (all I/O, no DB writes) and `apply` (pure DB writes); the pipeline
  runs prepare for a chunk in bounded-concurrency batches (4 at a
  time) outside the transaction, then opens a single transaction to
  apply the pre-resolved results. Outbox send-side `gzip.encode` is
  also offloaded to a worker isolate for payloads above 2 KB.
- Regression test guards the invariant that every `prepare` completes
  before the writer transaction opens.
- Live sync stalling until force-restart. `MatrixStreamLiveScanController`'s
  `_scanInFlight` guard could remain set indefinitely if the apply pipeline
  hung on an unbounded `downloadAndDecryptAttachment()` — every subsequent
  timeline signal then coalesced into `_liveScanDeferred` and dropped. Two
  complementary fixes: (1) every Matrix attachment download is now wrapped
  by `downloadAttachmentWithTimeout` (default 45 s,
  `SyncTuning.attachmentDownloadTimeout`) which converts a hang into a
  `FileSystemException` routed through the existing retry tracker; (2)
  `scheduleLiveScan` is now a stuck-scan watchdog: if a scan has been
  in-flight longer than `SyncTuning.liveScanStuckThreshold` (90 s), the
  guard is released, `liveScan.stuck.released` is logged, and a fresh
  scan is scheduled. Both fixes are independent safety nets; together
  the pipeline recovers on its own rather than requiring a restart.

### Changed
- Sync log volume reduced by ~40% at info level. The outbox send path used
  to emit ~10 info lines per successful send across four subdomains
  (`sendMatrixMsg`, `sendNext()`, `outbox.send`, `OUTBOX queue`); a single
  capture at the outbox processor now summarises the send with `type`,
  `subject`, `retries`, elapsed `ms`, and remaining `pending` queue depth.
  Per-event `attachment.observe` and `attachmentIndex.record` lines are
  now gated behind a `verboseLogging` flag on `AttachmentIngestor` /
  `AttachmentIndex`; production wiring passes `false` so the
  steady-state and pagination-burst line counts drop, while tests keep
  the flag on to preserve existing per-event assertions. Failure, retry,
  and circuit-breaker diagnostics are unchanged.
- Sync signal sources consolidated. The live timeline only subscribes to
  append triggers (`onNewEvent`, `onInsert`); `onChange`, `onRemove`, and
  `onUpdate` had no legitimate driver in a single-user append-only sync
  model and are no longer wired. The `signalTimelineChange` /
  `signalTimelineRemove` / `signalTimelineUpdate` counters are dropped
  from `metricsSnapshot` and the `liveScan.summary` breakdown.
- `AppLifecycleRescanObserver` removed. The 30 s wake detector in
  `MatrixStreamLiveScanController` and the connectivity-driven rescan
  already cover resume; the lifecycle observer duplicated those triggers
  and produced the `forceRescan.skipped (already in flight)` noise
  (116 of 321 lines in the 2026-04-20 log).

## [0.9.967] - 2026-04-20
### Changed
- Task detail header rebuilt against the desktop Figma as a scoped
  migration. Replaces the pinned title sliver + legacy
  `TaskHeaderMetaCard` with a new `DesktopTaskHeader`:
  - Three explicit lines: title → classification (category, project,
    labels) → metadata (due date, estimate, priority, status); each
    row wraps on narrow widths.
  - Inline capsule-style multi-line title editor (Heading 3 bold,
    pencil-on-hover, check / cancel on edit). ⌘S / Ctrl+S / ⌘-Enter
    commit; Esc cancels.
  - Figma priority / status / project / due-date / work-category
    chips; estimate chip with progress bar and overtime styling;
    assigned-label chips as outlined pills with a leading color dot
    and high-emphasis primary text.
  - Subdued placeholder chips for every empty state ("No project",
    "unassigned" category, "No due date", "Add Label") that open the
    corresponding picker when tapped. Long-press on a label chip
    still reveals its description dialog.
  - Due-date urgency is now tri-state: orange for due today, red for
    overdue, subdued otherwise.
  - Metadata row uses a text-scale-aware breakpoint: both groups sit
    side-by-side (space-between) on wide viewports and stack cleanly
    on narrow ones / with accessibility text scale.
  - The in-header `more_vert` ellipsis is gone — entry actions stay
    on the pinned app bar. That app bar now also surfaces the task
    title in `subtitle2` once the header scrolls out of view.
  - Presentational widget is Riverpod-free and exercised in
    Widgetbook (Default, Editing, Long title (wraps), Empty
    classification + metadata, Playground). A thin
    `DesktopTaskHeaderConnector` wires the existing status / priority
    / category / project / due-date / label pickers and
    `EntryController` mutations.
  - `TaskLabelsWrapper` is removed entirely — the estimate chip,
    assigned-label chips, and the Add Label affordance it used to
    render are all inside the header now.
  - AI Task Summary, Task description (agent report), Linked Tasks
    and Checklist cards on the task detail page now render on a flat
    `TaskDetailSectionCard` surface (solid `background.level02`,
    `radii.l`, subtle `decorative.level01` border, no gradient, no
    drop shadow) matching the task list. Section titles inside the
    touched cards use the design-system `subtitle2` token instead of
    Material `textTheme.titleSmall`.
  - Deleted: `TaskTitleHeader`, `TaskHeaderMetaCard`, and the
    per-chip `*_wrapper.dart` / `*_widget.dart` files that only fed
    the old header. Shared modal content widgets
    (`TaskStatusModalContent`, `showDueDatePicker`,
    `CategorySelectionModalContent`,
    `ProjectSelectionModalContent`) are retained and reused by the
    new connector.
  - Task language selection — previously a flag-shaped pill inside
    the header — moves into the pinned app bar's triple-dot menu as a
    standard list item (`ModernSetTaskLanguageItem`). The currently
    selected language's flag renders inline next to a "Set language"
    label (falling back to `Icons.language` when unset); tapping the
    row opens the existing `LanguageSelectionModalContent` modal and
    persists the selection via the journal repository.
  - `ActionMenuListItem` now accepts an optional `leading` widget in
    addition to its existing `icon`, so entries like the language
    action can render a flag at its natural 4:3 aspect without
    re-skinning the menu row.

## [0.9.966] - 2026-04-19
### Added
- Collapsible desktop navigation sidebar. A new menu icon at the top of
  the sidebar toggles between the expanded layout and a narrow 72 px
  icon-only strip. Destination labels are hidden in the narrow state
  and surface as tooltips on hover, while the brand logo hides to free
  up horizontal space. Drag-to-resize is disabled while the sidebar is
  collapsed so labels never end up clipped at intermediate widths; the
  divider still paints its hairline so adjacent panes do not shift
  across the transition. The collapse flag and the previously-used
  expanded width are persisted to `SettingsDb`, so re-expanding
  restores the exact prior divider position and the state survives
  restarts.

### Fixed
- Priority / status / label pills in the task filter sheet no longer
  "breathe" when toggled. `_TaskFilterChoicePill` used to widen its
  border from 1.0 → 1.5 px on selection, which nudged every sibling
  chip in the `Wrap` by 1 px per edge on each toggle. The border width
  is now pinned at 1.5 px in every state and the pill is stateful with
  a 400 ms `easeInOut` animation controller that cross-fades the
  border and fill colour alphas between deselected and selected, so
  the outer dimensions of every chip are identical at every frame and
  neighbours never reflow.
- Sync startup no longer does every step twice. The connectivity-driven
  `forceRescan` and the consumer's `runInitialCatchUpIfReady` used to race
  into `_attachCatchUp()` concurrently because neither acquired
  `_catchUpInFlight` for its run, producing two `catchup.waitForSync`
  passes, two `backfill.start events=610` fetches, and two ordered
  replays of the same 89-event slice (visible in logs as paired
  `processor.resolve` / `processor.apply` / `sequence.recordReceived`
  lines). `_attachCatchUp()` is now the single owner of
  `_catchUpInFlight` and the deferred-live-scan flush: it short-circuits
  with `catchup.skipped (in flight)` when another run is already in
  progress, and every other entry point (`forceRescan`,
  `runInitialCatchUpIfReady`, `runGuardedCatchUp`,
  `_scheduleInitialCatchUpRetry`, `startWakeCatchUp`, `_startCatchupNow`)
  defers to it rather than managing the flag themselves. The obsolete
  `bypassCatchUpInFlightCheck` parameter and `forceRescan.skippedCatchUp`
  log are removed.
- Pre-history gap handling no longer logs per incoming event. Hosts that
  carry a permanent unresolved prefix (e.g. `lastSeen=81982` stuck while
  the VC counter keeps climbing) used to re-emit `largeGapDetected
  gapSize=7344`, `gapDetectedRange`, `recordReceivedEntry detected N
  gaps`, and `apply.agentEntity.gapsDetected count=7344` for every single
  catch-up event, dominating the desktop sync log. The sequence service
  now suppresses those lines on incremental extensions of an already
  materialised range and returns only the newly materialised subrange in
  its `gaps` result, so the caller-side `apply.*.gapsDetected` log is
  driven by actual new signal. A fresh idle restart now logs on the order
  of tens of lines instead of 400 KB.
- Redundant `start.catchUpRetry` catch-up on every startup. The signal
  binder's 150 ms follow-up `runGuardedCatchUp('start.catchUpRetry')` now
  only runs when the initial catch-up has not yet completed. Once the
  consumer reports `catchup.initial.completed`, the retry is skipped
  instead of kicking a second full `_waitForSyncCompletion` +
  event-replay pass.
- Connectivity bootstrap no longer duplicates the startup rescan.
  `connectivity_plus` emits the current state synchronously on subscribe,
  which used to schedule a `forceRescan` that raced the dedicated startup
  rescan. The listener now swallows the first emission
  (`service.forceRescan.connectivity.bootstrapSkipped`) while still
  recording the connectivity signal for metrics.

## [0.9.965] - 2026-04-19
### Fixed
- DailyOS mobile page no longer surfaces "Failed to load timeline" and
  "Failed to load budgets" on devices where the v39 migration's partial
  expression index `idx_journal_tasks_due_open` is missing or cannot
  satisfy SQLite's `INDEXED BY` clause. `JournalDb._selectTasksDue` now
  catches `SQLITE_ERROR` from the pinned fast path and retries once
  without the pin, so the open-task due-date query still returns rows
  when the planner cannot prove the partial's WHERE. In addition,
  `beforeOpen` recreates `idx_journal_tasks_due_open` and
  `idx_journal_task_status_private` as `CREATE INDEX IF NOT EXISTS` on
  every launch (guarded on the `journal` table existing), so devices
  that landed at `user_version = 39` with a missing index self-heal on
  next open. The CREATE statements now live in a single pair of private
  top-level constants reused by `onUpgrade`, `beforeOpen`, and the
  migration tests. Regression tests cover both the self-heal path and
  the unpinned fallback in
  `test/database/task_indexes_v39_migration_test.dart`.

## [0.9.964] - 2026-04-19
### Changed
- Outbox / sync DB: removed a 40–600 ms main-isolate blocking query that
  was triggered on every outbox enqueue (including each image paste or
  drag-and-drop). `getLastSentCounterForEntry` used to compute
  `MAX(counter)` against an index that did not include `counter`, forcing
  SQLite to read every matching row from the heap for hot entry_ids. The
  v11 schema replaces `idx_sync_sequence_log_host_entry_status` with a
  covering `idx_sync_sequence_log_host_entry_status_counter`, the query
  is rewritten as `ORDER BY counter DESC LIMIT 1` (index-only scan with
  early terminate), and the sequence service now caches the last-sent
  counter per `(hostId, entryId)` with LRU capacity 2048. Follow-up
  lookups for the same entry hit the cache and skip the DB entirely; the
  cache is kept consistent by refreshing it on `recordSentEntry`. Under
  the same load as 2026-04-19 (3092 invocations, p50 43 ms, peak 618 ms)
  this collapses to a single sub-millisecond index probe per distinct
  entry per TTL window. Removes the multi-second UI freeze observed when
  pasting/dragging images.
- Sync: eliminated the dominant source of redundant work on devices that
  carry a permanent pre-history gap in the sequence log. Previously,
  every incoming event on such a host re-ran a multi-chunk scan of the
  `sync_sequence_log` table plus a batch-insert pass over thousands of
  already-materialized rows, and emitted four INFO log lines per event.
  The sequence log now memoizes the highest counter already materialized
  as a missing range per host and short-circuits the entire pass when
  the observed range is already covered. When the observed counter does
  advance, only the incremental delta is scanned and logged. This
  removes the main cause of severe mobile UI blocking on slow sync
  queries and the bulk of the daily sync-log volume on desktop.
- Sync: missing or requested rows whose backfill request count reaches
  the per-entry cap are now retired to the terminal `unresolvable`
  status automatically at the start of each backfill cycle. Without
  this, a permanently unresolvable counter — a pre-history entry, a
  purged payload, or a mapping whose payload vector clock is
  permanently behind the requested counter — kept the contiguous-prefix
  watermark in `getLastCounterForHost` stuck forever, which in turn
  forced gap detection to re-enter on every subsequent event for the
  same host. The watermark now advances past these rows and gap
  detection stays quiet.
- Sync attachments: the matrix SDK's "File is no longer cached" error
  used to be emitted as a full exception with stack trace on every
  replay of an evicted attachment event, with zero recovery value. The
  ingestor now records the event id the first time this happens and
  short-circuits subsequent attempts immediately, collapsing bursts of
  hundreds of error entries per day to one info line per eviction.
- Sync: duplicate in-flight descriptor fetches for the same attachment
  event are now deduplicated. Two text events referencing the same
  `jsonPath` within a single catch-up or live-scan wave previously each
  launched an independent download, decrypt, and decode; they now
  share a single future keyed by the index key and descriptor event id.
- Outbox: the `sendNext.state` and `dbNudge count=...` observability
  lines are now coalesced. They emit on state transitions and at a
  30-second minimum interval instead of once per tick, removing the
  majority of steady-state outbox log lines without changing enqueue
  or send behavior.

## [0.9.963] - 2026-04-19
### Added
- Agent suggestion panel now surfaces the reasoning behind resolved
  proposals without cluttering the list. A collapsed "Recent activity"
  strip shows the three most recent ledger entries (newest-first) with
  verdict icons — check for confirmed, X for rejected, undo for
  agent-retracted — and when a rejection or retraction carries a reason
  it lives behind an info icon whose tooltip reveals the text on tap or
  hover. The strip stays hidden entirely when there is no resolved
  activity to show. A "Confirm all" action sits next to the pending
  badge whenever more than one open suggestion is pending, fanning out
  to `ChangeSetConfirmationService.confirmAll` per distinct change set.
- Initial-language auto-apply: `set_task_language` now bypasses the
  deferred-confirmation flow when the task has no language set yet, so
  the agent can pick the language silently on first use. Re-tagging a
  task that already has a language continues to flow through the
  standard change-set approval path, and the same single-use guard that
  protects the title carve-out prevents a second call in the same wake
  from silently overwriting the freshly-applied language.

### Changed
- Suggestion rows no longer display the raw snake_case tool key beneath
  the human summary. The tool name was developer-facing noise that did
  not help the user decide whether to confirm or reject a proposal.

## [0.9.962] - 2026-04-19
### Changed
- Task agent: the mandatory `update_report` tool call at the end of every
  wake is now a hard guarantee instead of a prompt-only request. When the
  model stops without calling it — a routine failure mode for weaker
  local models such as Qwen 3.6 served via `mlx-vlm` — the workflow now
  issues one additional inference pass with `tool_choice` pinned to
  `update_report` and a direct reminder message, forcing the final
  report. `ConversationRepository.sendMessage` and the underlying
  inference layer (`CloudInferenceRepository`, `CloudInferenceWrapper`,
  `InferenceRepositoryInterface`, `OllamaInferenceRepository`) gained a
  threaded `toolChoice` parameter that overrides the default `auto`
  selection policy; the override is currently honored on the OpenAI-
  compatible path and silently ignored by the Gemini/Ollama/Mistral
  sub-repositories, which still benefit from the retry's pointed user
  message. The task-agent scaffold and the seeded report directive also
  now lead with a non-negotiable "final step" instruction so compliant
  models need no retry at all.

### Added
- Initial-title auto-apply: when the task agent calls `set_task_title` on
  a task whose title is still null or empty, the title is applied
  immediately without a user-approval prompt, so a freshly dictated task
  lands with a meaningful name instead of an empty-looking suggestion
  waiting in the panel. Once a title is present the tool reverts to the
  standard deferred confirmation flow, and a second silent-abort guard
  inside `TaskToolDispatcher` no-ops any race in which a manual edit,
  synced edit, or previously-confirmed proposal populated the title
  between the LLM emitting the call and the dispatcher running.
- Task agent suggestions are now surfaced in a single consolidated panel
  on the task detail page instead of two disconnected cards, and the
  agent itself can autonomously retract its own stale proposals. On every
  wake the agent receives a unified proposal ledger listing every
  suggestion it has ever made for the task, grouped into open vs.
  resolved entries and carrying stable fingerprints. A new immediate
  `retract_suggestions` tool lets the agent withdraw proposals that are
  no longer relevant (the task state already matches them, the user made
  the change manually, or they duplicate another open proposal) without
  any user prompt — the item simply disappears from the active
  suggestion list, leaving an auditable trail alongside user
  confirmations and rejections. Dedup now excludes retracted items from
  its basis so the agent can cleanly re-propose after the task context
  materially changes, while user rejections remain sticky.

## [0.9.961] - 2026-04-18
### Changed
- Sync pipeline: removed duplicate-work in inbox attachment handling and
  sync-family logging. `AttachmentIndex.record` now dedupes per eventId so
  repeated observations from live scan + catch-up + backfill passes become
  no-ops instead of thrashing the per-path slot between events sharing one
  `relativePath`. `SyncEventProcessor` and `SyncSequenceLogService` no
  longer emit each log line twice (once via `DomainLogger`, once via a
  paired direct `LoggingService.captureEvent` to a sync-file domain) —
  `DomainLogger` is the single emitter and falls back to a direct
  `sync`-domain capture when no domain logger is wired. Descriptor catch-up
  skips events whose `relativePath` is not in the pending set, so the
  per-run scan no longer records ~1000 unrelated events into the
  attachment index. Removed the per-tick `OUTBOX enqueueRequest() done`
  log, which fired on every debounced wake and carried no signal.
- Sync pipeline: the per-event apply loop in `MatrixStreamProcessor` now
  runs inside a single `JournalDb.transaction`, so a slice of N sync
  events commits once instead of N times. Drift coalesces the journal
  table stream emissions to one notification per slice, collapsing the
  reader/writer lock contention that produced multi-second waits behind
  otherwise-cheap `id IN (?)` lookups during large catch-up replays.
  Per-event error handling is unchanged: individual apply failures are
  still caught locally and scheduled for retry, so the transaction only
  rolls back when a commit genuinely fails.

## [0.9.959] - 2026-04-18
### Changed
- Desktop task switcher: switching between open tasks in the desktop split
  layout now crossfades the detail pane instead of cutting abruptly. The
  transition is a 480 ms `easeInOutCubic` fade driven by an `AnimatedSwitcher`
  keyed on the selected task id, so it fires only when a genuinely different
  task is opened — reloads and in-place data updates for the currently open
  task do not trigger the animation.

## [0.9.958] - 2026-04-18
### Changed
- Desktop navigation sidebar: the Tasks and Settings notification counts now
  render as a design-system number badge in a dedicated trailing slot on the
  right of each row (instead of a Material `Badge` overlapping the icon and
  label). The vertical spacing between sidebar items is now 24 px to match
  the Figma layout. Sidebar rows are no longer pinned to a fixed 48 px
  height — each row grows with its label, so increasing the OS/app text
  scale no longer vertically clips "Projects", "DailyOS", "Insights",
  "Logbook" or "Settings". The mobile bottom-nav preserves its existing
  overlay badge.

## [0.9.957] - 2026-04-18
### Changed
- Database schema bumped to v39 with two new partial indexes on the
  `journal` table: `idx_journal_tasks_due_open` (keyed on the JSON-extracted
  due date for open tasks) lets the due-date query stream straight from the
  index without an external sort, and `idx_journal_task_status_private`
  covers `countInProgressTasks` and similar global task-status counts with a
  narrow index instead of scanning the full task set. Both partials carry
  `type = 'Task' AND task = 1 AND deleted = FALSE` so they stay consistent
  with the other task indexes and SQLite's theorem prover reliably proves
  coverage for the paired queries.

## [0.9.956] - 2026-04-18
### Fixed
- AI-proposed time entries can now be confirmed from the task "Proposed
  changes" panel. The approval-time validator previously rejected any
  `create_time_entry` whose `startTime` or `endTime` fell after the
  originating wake timestamp, which left suggestions like 11:13–11:48 or
  11:00–13:00 stuck as pending with a "Failed to apply change" toast
  whenever the agent rounded or estimated a session past the wake instant.
  The wake timestamp is still used for the same-day check (so
  after-midnight approvals keep working), but the "not in the future"
  cutoff no longer applies at approval time — the user is the authority
  when confirming. `endTime` must still land on the same day as
  `startTime`. Direct agent-time tool calls (if ever wired) still refuse
  fabricated future times.

## [0.9.955] - 2026-04-17
### Changed
- Align the desktop tasks and projects surfaces with the Figma design system.
  Sidebar, task list, task details and projects list now share the deeper
  `background/01` surface, and task cards sit on `background/02` so the
  subtle card/raised-surface contrast matches the Figma reference. Dark-mode
  `text/*` tokens are raised to the Figma-specified opacities (high 100%,
  medium 80%, low 64%) so headlines, subtitles and timestamps read with the
  correct contrast without changing type weights.
- The selected task row uses the Figma `surface/selected` token (teal at
  16%) for a subtler highlight instead of the previous stronger tint.
- Task group headers ("Today", "Yesterday" …) and the `N tasks` counter use
  the caption (12 px) token for a lighter hierarchy.
- Task title header and the pinned `SliverAppBar`s above it render on
  `background/01` with no elevation, so the strip no longer reads darker
  than the body.
- Sidebar drops the legacy "+ New" quick action, always uses the filled
  settings glyph, and swaps the Ionicons/MDI nav glyphs for Material
  rounded/outlined equivalents (Tasks, Projects, DailyOS, Habits, Insights,
  Journal, Settings). The Insights nav tab now reads "Insights"
  (English/en-GB) and "Einblicke" (German).
- Task list filter chips use the design-system chip component and render
  inline under the search bar, with priority chips carrying a leading
  priority glyph. Tasks and projects filter triggers now use
  `filter_list_rounded` to match the Figma funnel glyph.
- Tasks and projects headers are pinned outside the scroll view so the
  title stays static and pull-to-refresh only drags the list below it.
- The floating action button component is now a rounded-24 teal surface
  (`radii.xl`) matching Figma, and the journal/task details FAB was swapped
  from Flutter's default circular FAB to the design-system FAB so list and
  details FABs share the same shape and bottom-right anchor. The task
  details showcase action bar uses the Figma `subdirectory_arrow_right`
  glyph for the "linked" round action.

## [0.9.954] - 2026-04-17
### Added
- Optional gzip compression for JSON sync attachments, gated by the
  `use_compressed_json_attachments` config flag (off by default). Receivers
  unconditionally decompress attachment events that carry a
  `com.lotti.encoding: gzip` marker, so peers already on this release stay
  compatible once the flag is flipped on. Only `.json` attachment paths are
  compressed; media files are already on compressed formats and skip the
  branch.
- The new compression flag is toggleable from Settings → Flags, with
  localized labels and descriptions across all supported languages.

## [0.9.953] - 2026-04-16
### Fixed
- Raise the open file descriptor soft limit to 10,240 at startup on macOS and
  Linux. Apps launched from Finder/Spotlight on macOS inherited launchd's
  legacy 256 limit, which was trivially exhausted under real-world load
  (sockets, SQLite handles, attachment writes, log files). Under slow-network
  conditions this manifested as sporadic `EMFILE` errors in the Matrix sync
  pipeline and cascading DNS lookup failures until the app was restarted.

### Added
- Log the file descriptor soft/hard limits and the adjustment outcome at
  startup (`MAIN / fdLimits`), so the current ceiling is discoverable from the
  app logs without requiring `launchctl` or `ulimit` inspection.
- Annotate `EMFILE` failures on the attachment save path with current
  descriptor limits (`attachment.save.emfile` event), making future FD
  pressure incidents self-diagnosing.

## [0.9.952] - 2026-04-15
### Changed
- Task filter modal redesigned with the design system filter sheet, replacing
  the old Material chips and switches with pill-shaped sort/priority selectors,
  tappable selection fields for status/category/label, and Clear All / Apply
  action buttons.
- All filter modals (task, project, selection sub-modals) now use Wolt modal
  sheet for consistent adaptive presentation (bottom sheet on mobile, dialog
  on desktop).
- Selected filter chips now show contextual icons: status icons with color,
  category icons from the category definition, and colored dots for labels.
- Priority glyphs updated to match Figma: P0 uses new_releases icon, P1 uses
  signal_cellular_alt, P2/P3 use ascending bar variants with faded unfilled
  bars. Priority pill spacing tightened so all options fit on one row.
- Categories and labels list pages now use design system list items in a grouped
  container, matching the visual style of the settings page.
- Categories page header replaced with the standard SettingsPageHeader for
  consistent back-button behavior across mobile and desktop layouts.
- Dashboards, measurables, and habits list pages now use design system list
  items in a grouped container, consistent with categories and labels.
- Maintenance and logging domain settings pages now use design system list items
  in a grouped container, consistent with the rest of the settings pages.
- Sync settings and sync maintenance pages now use design system list items
  in a grouped container, consistent with the rest of the settings pages.
- Settings page uses a 3-column desktop layout for wider screens.

## [0.9.951] - 2026-04-13
### Added
- Project one-liner: AI-generated summary subtitle on project list cards,
  giving an at-a-glance status for each project (mirrors the existing task
  one-liner feature).
- Project agent now produces a dedicated `one_liner` field in its report,
  separate from the longer TLDR summary.

## [0.9.950] - 2026-04-11
### Removed
- Removed the gamey theme and all gamey-styled widgets (GameyFab, GameyCard,
  GameySettingsCard, GameyJournalCard, GameyTaskCard, shimmer/celebration
  overlays). Standard Flutter widgets and existing modern cards are used instead.

### Added
- Resizable panes in desktop layout: users can drag dividers between the
  navigation sidebar and content area, and between the list and detail panes,
  to adjust widths. Pane sizes persist across sessions via SettingsDb.

### Fixed
- Tasks desktop split view now keeps the current loaded list window mounted
  until refreshed pages resolve, which reduces visible flicker during task
  saves and other live updates while preserving regrouping after sort changes.

## [0.9.949] - 2026-04-10
### Changed
- Redesigned dashboard list page: removed the old SliverAppBar top bar,
  replaced flat list items with rounded grouped cards using
  DesignSystemListItem, and applied design system tokens for spacing,
  colors, and typography.

### Added
- AI one-liner subtitle in task list: each task row now displays the
  agent-generated summary below the title (max 2 lines), giving users
  at-a-glance progress visibility without opening the detail view.
- Time recording indicator in task list: a red dot appears on any task
  row that is actively recording time, positioned as a trailing element
  in the row layout.
- Live task data in list rows: editing a task's title, status, or other
  data in the detail pane now updates the corresponding list row
  in-place via a lightweight `taskLiveDataProvider`, without requiring
  a full list refresh.
### Fixed
- Removed animated transitions (`animateTransitions`) from the paged
  task list to eliminate visual flicker when loading pages or refreshing
  data.

## [0.9.948] - 2026-04-10
### Changed
- Task filter modal: replaced the old custom filter modal with the design
  system version from Widgetbook. The new modal uses the same visual language
  as the projects filter and includes sort, status, priority, category, label,
  project, and agent assignment filters with display toggles.
- Project filtering now lives inside the task filter modal with a grouped
  selection view (projects grouped by category). Removed the separate
  ProjectHealthHeader from the task list.
- Search mode (full text vs. vector) is now only shown on desktop when vector
  search is enabled. On mobile, full-text search is always used.
- Cover art thumbnails are now always shown on task cards.

### Removed
- "Show projects header" display toggle (superseded by in-modal project filter).
- "Show distance on cards" display toggle (was a debugging tool only).
- "Show cover art" display toggle (cover art is now always shown).

### Added
- Checklist filter tabs: added a "Done" tab alongside "Open" and "All" to
  filter checklist items by completion state. Tab order is Open, Done, All.
- Desktop mode: responsive layout switches from mobile bottom navigation to a
  persistent left sidebar when the window is wider than 960px. The sidebar
  includes all navigation destinations with Settings pinned at the bottom,
  plus the "New" and AI assistant action buttons.
- Desktop split-pane view for Tasks, Projects, and Dashboards: the list and
  detail views are shown side by side. Selecting an item in the list
  reactively opens its detail in the right pane without losing list scroll
  position. Full-width sections (Habits, My Daily, Journal, Settings)
  continue to use the entire content area.
- Active item highlighting: the selected task or project card is visually
  marked in the list pane when a detail view is open.
- Localized empty-state placeholders for the detail pane in all seven
  languages.
### Fixed
- Checklist cards no longer play a visible collapse/expand animation on first
  render. Items snap into their initial state immediately, preventing jank
  when multiple checklists load at once on slower devices.

## [0.9.947] - 2026-04-09
### Changed
- Bottom navigation rollout: every main app tab now uses the Widgetbook
  design-system bottom navigation shell instead of the legacy Spotify-style
  bar, with the floating pill centered consistently across the app.
- Mobile bottom sheets and Wolt modals now open on the root navigator on
  narrow screens so they render above the floating bottom navigation and block
  tab switching while a modal is active.
- Tasks and Projects now share the same design-system floating action button,
  and the shared bottom-navigation spacing now lifts floating action buttons
  and recording indicators clear of the navigation chrome across list, detail,
  and settings surfaces.
- Task status selection modal redesigned: replaced wrap-of-chips with a
  vertical list of tappable rows — each showing the status icon, label,
  and a trailing checkmark on the currently-selected status.
- Status icons updated to match design reference: Groomed uses a pencil
  icon, In Progress a play arrow, Blocked a warning triangle, On Hold
  pause bars.
- Status icon colors are now brightness-aware: lighter muted shades on
  dark backgrounds, higher-contrast shades on light backgrounds.
- Icon mapping centralised in `taskIconFromStatusString` so the status
  chip and the selection modal always stay in sync.
- Status rows wrapped with `Semantics` for screen-reader accessibility.

## [0.9.946] - 2026-04-08
### Changed
- Checklist widget redesigned to match Widgetbook reference: progress ring now
  always visible in the header (collapsed and expanded), filter strip (Open/All)
  uses a highlighted background for the selected tab, and the add-item field is a
  plain text field without suffix icons.
- Checklist item rows no longer enter edit mode on title tap; only the pencil icon
  opens the inline editor.
- AI suggestion dialog strings in the checklist item row are now fully localized.
- "Share" label in the checklist card menu is now localized.
- Fixed `ChecklistItem` rendering in the entry details view.
- Progress ring and completion fraction are now hidden when a checklist has no
  items, and the three-dot menu is hidden when no actions are available.
- Checklist item row now uses a minimum height instead of a fixed height so the
  inline editor can expand for multi-line text and content is no longer clipped
  when the system text scale is increased.
- Add-item field uses a minimum height constraint instead of a fixed height.
- Increased spacing between the progress ring and the completion fraction text.

## [0.9.945] - 2026-04-08
### Added
- Standalone soul evolution: dedicated 1-on-1 sessions focused on personality
  refinement, aggregating feedback from all templates sharing a soul. Accessible
  via "Soul 1-on-1" on the soul detail page, with its own review page and
  session history.

### Changed
- Tasks tab migration: added a new design-system tasks browse page behind the
  `enable_tasks_redesign` runtime flag, wired through a `/tasks` root switch so
  the legacy page stays available during rollout. The new page keeps the
  existing infinite-scroll paging controller, current filter model and modal,
  create-task flow, and task-detail navigation while rendering sort-aware
  section groupings for due-date, priority, and creation-date presentations.
- Tasks tab redesign: aligned the grouped-task card presentation more closely
  with Figma by switching to the actual status glyphs, inset dividers, grouped
  header treatment for priority sections, tracked-time metadata, and a filter
  modal search-mode control instead of an inline full-text/vector toggle.
- Tasks tab polish: replaced the provisional priority glyphs with the actual
  Figma P0-P3 icons and restored the intended breathing room below the search
  row.
- Tasks and projects grouped cards: both tabs now share the same hover and
  selection row-surface behavior so active rows blend over adjacent dividers
  consistently, while task category chips now use the same category tag
  component as projects and the task rows have slightly looser spacing.
- Bottom navigation migration: the redesigned Tasks tab and the Projects tab
  now render the Widgetbook design-system bottom navigation bar, while the
  remaining tabs keep the legacy Spotify-style navigation during the rollout.

## [0.9.944] - 2026-04-08
### Added
- Desktop zoom: Cmd+/- keyboard shortcuts and View menu items for
  zooming the app UI in and out, with Cmd+0 to reset. Zoom level
  persists across sessions.

## [0.9.943] - 2026-04-07
### Added
- Token usage Stats tab in Agents Settings — iOS battery-usage-inspired
  dashboard showing 7-day and 30-day token consumption with interactive
  bar charts, average vs. today comparison, per-model breakdowns, and
  per-template source activity with high-usage alerts.
- Wake activity chart migrated into the new Stats tab for a unified view.

## [0.9.942] - 2026-04-07
### Added
- Soul evolution UI: standalone soul evolution page with an interactive
  evolution catalog, soul selector, and a conversation-based refinement
  workflow that lets users iteratively shape agent soul documents from
  templates.
- Pluggable soul document: soul documents can now be customized per agent
  template, decoupling soul content from the shared default.
- One-on-one v2: redesigned agent one-on-one conversation experience.
- Manual planning flow: new "Set time blocks" step for manual daily planning.
- Customer care dashboard: new frontend with admin authentication.

### Changed
- Proposed changes card: removed inline confirm/reject buttons from
  individual change items; users now confirm or reject via swipe gestures
  or the bulk "Confirm all" button.
- Settings page restyled to use design system list items, matching the
  current Figma visual language.
- Context menu component aligned with Figma design specifications.
- Projects tab: task rows now display agent one-liner summaries, follow-up
  tasks automatically inherit the parent project, and the layout alignment
  and scroll behaviour have been improved.
- Pending agent wakes UX: improved wake card presentation and prevented
  redundant wake scheduling.

### Fixed
- Agents no longer trigger self-notification loops.
- Projects page no longer flickers during live data refreshes.

## [0.9.941] - 2026-04-02
### Changed
- Agents settings: added a `Pending Wakes` dashboard under `Settings > Agents`
  with a live badge count, per-wake countdown cards, and per-card wake
  deletion for deferred and scheduled wakes.
- Agents settings: the `Instances` tab now shows a compact task-agent fleet
  summary under the filters, with current totals for all, active, dormant,
  and destroyed task agents.
- Task-agent wake prompts no longer inject sibling-task TLDR directories, and
  the related-task drill-down tool now stays defined in the registry while
  being hidden from the LLM until a stronger retrieval path is in place.

## [0.9.938] - 2026-03-29
### Changed
- Projects detail task summaries: project-task rows now show the latest
  task-agent `oneLiner` subtitle between the task title and metadata, matching
  the current Figma spacing and typography on mobile and desktop layouts, and
  open project detail pages now refresh automatically when a task-agent report
  finishes.
- Task-agent reports: the `update_report` contract now requires a dedicated
  `oneLiner` tagline alongside the TLDR and full report so task cards can show
  a concise current-state summary without reusing the longer report text.
- Projects detail data path: highlighted task rows now bulk-load the latest
  task-agent reports for all linked task IDs in one repository call, avoiding
  N+1 report queries on larger projects.
- Projects list grouped cards: category group containers now render the same
  subtle bordered card treatment shown in the current Figma list designs,
  instead of relying on background fill alone.
- Projects detail live refresh: when related-task updates reload the derived
  project detail record, the page now keeps the previous content mounted until
  the new record resolves, avoiding full-page flicker and scroll-position jumps.
- Projects detail scrolling: the top-level detail route now renders the task
  panel through a sliver-based lazy list, which keeps large project task lists
  steadier during fast downward scrolling instead of eagerly laying out every
  task row.

## [0.9.937] - 2026-03-29
### Changed
- Follow-up tasks now automatically inherit the project of the parent task they
  were created from, both from the UI (create task button, linked tasks header,
  desktop menu) and from the agent follow-up task workflow.

## [0.9.936] - 2026-03-28
### Changed
- Design system navigation: the mobile detail back control is now a reusable
  component with the intended regular-weight label styling, so detail pages do
  not drift into heavier back-button text.
- Projects detail task statuses: project-task rows now use the Figma-aligned
  colored status glyphs for in-progress, done, on-hold, blocked, and related
  task states instead of flattening every status icon to the same gray tone.
- Projects detail task typography: project-task titles are explicitly kept at
  regular body-small weight, and the duration plus status line now uses one
  shared compact caption text style.
- Projects detail task list: task rows now let long task titles wrap across
  multiple lines and keep duration plus state metadata underneath, with extra
  vertical breathing room in the `Project Tasks` header.
- Projects list spacing: widened the grouped project-row horizontal inset so
  titles, metadata, and status pills sit with the intended breathing room
  inside each card.
- Projects detail redesign: the top-level Projects flow now opens a new
  design-system-aligned detail page at `/projects/:projectId`, with editable
  category, due date, and status controls, a health-band header, manual agent
  refresh, an expandable AI report, and the current project-tasks card.
- Projects detail data path: the new detail surface now builds from live
  project, task, category, and project-agent state while reusing the same
  shared component tree in the app and Widgetbook. Project-task rows now open
  task details directly, while the older settings-scoped project views remain
  in place for category-driven flows during the rollout.
- Projects detail UX polish: category and due-date pickers are now reachable
  even when no value is set, the empty-state report copy only appears when
  both summary and full content are absent, and expanded reports strip the
  leading H1 title that the UI already renders above the report section.
- Projects visual polish: grouped project rows, progress rings, and project
  task rows now match the linked Figma spacing more closely, with progress
  colors driven by completion level and the mobile detail title reduced to the
  intended heading size.
- Projects tab search: the live top-level Projects page now enables local
  substring search against the grouped list, and the shared design-system
  search field keeps typed text stable across rebuilds while centering the
  search text correctly on mobile and desktop surfaces.
- Task agents now receive parent-project context on wake when a task belongs
  to a project, including the latest project-agent TLDR and full report body
  so task recommendations can align with project-level priorities and
  blockers.
- Task agents now also receive a bounded directory of related tasks from the
  same project, using stored sibling task-agent TLDRs plus logged time spent,
  and can inspect one of those sibling tasks on demand through a new
  read-only drill-down tool scoped to the current wake context.

## [0.9.933] - 2026-03-27
### Changed
- Projects tab: the new top-level Projects tab now ships behind the
  `enableProjects` feature flag with the intended design-system mobile layout.
  The live tab and the Widgetbook mobile reference now mount the same
  sliver-driven header, grouped category sections, and floating create action,
  while the search field stays disabled pending the later vector-search
  follow-up.
- Projects filters: the Projects tab and Widgetbook showcase now share the
  same design-system filter modal, nested field-selection sheet, and state
  model for project-status and category filtering instead of keeping separate
  mock-only filter behavior.
- Projects tab reactivity: grouped project snapshots now refresh automatically
  when relevant project, task, category, or private-visibility updates arrive,
  so status changes such as `Active` to `Completed` are reflected in the UI
  without reopening the page.

## [0.9.932] - 2026-03-23
### Changed
- Projects now expose a user-facing health band (`Surviving`, `On Track`,
  `Watch`, `At Risk`, `Blocked`) in the tasks-page project header and project
  detail page based on the latest project-agent report.
- Project health tracking now marks project summaries stale when any linked
  task activity changes, and the app state layer now aggregates health bands,
  stale-summary state, and active project recommendations for future dashboard
  surfaces.
- Direct edits to a project and task linking changes now use the short
  deferred wake path, while other task-level activity stays stale-only
  until the next scheduled project digest unless refreshed manually sooner.
- Projects now also have a top-level tab behind the `enableProjects` feature
  flag, reusing the existing bottom navigation and loading grouped
  project/category data through a single batch overview path.

## [0.9.931] - 2026-03-23
### Added
- Qwen 3.5 Plus model: added Alibaba Cloud's advanced multimodal reasoning
  model with text and image understanding for complex analytical tasks.
- Chinese AI Profile: new default inference profile using Qwen 3.5 Plus for
  reasoning alongside Qwen VL Flash (vision), Qwen Omni Flash (audio), and
  Wan 2.6 (image generation).
- Alibaba FTUE setup dialog: added first-time setup wizard for Alibaba Cloud
  providers with model and category creation.

### Changed
- FTUE setup simplified: provider setup wizards no longer create prompts —
  all AI capabilities are handled by the skill-based automation system via
  inference profiles.
- Project agents now skip dormant daily digests, track pending project
  activity in synced agent state, and show stale summaries in the tasks-page
  project header until the next 06:00 report refresh.
- Project detail pages now render the current project-agent report inline,
  expose a manual refresh action, show when no project agent exists yet, and
  return to the originating category instead of dropping back to the top
  settings page.
- Confirmed project-agent next-step proposals now persist as active project
  recommendations that supersede older active guidance and can be resolved or
  dismissed from the project detail page.

## [0.9.929] - 2026-03-21
### Added
- Design system Tabs: added a new Widgetbook-first Tabs component with
  small/default sizes, token-driven interactive states, optional counter and
  icon slots, and focused widget/widgetbook coverage.
- Design system Calendar picker: added a Widgetbook-first calendar picker with
  month rail navigation, token-driven monthly range cells and weekly date
  cards, plus focused widget/widgetbook coverage.
- Design system Progress bar: added a Widgetbook-first determinate progress bar
  with default and chunky variants, optional header content, token-driven fill
  and track treatments, and focused widget/widgetbook coverage.

### Changed
- Design system controls: tightened accessibility contracts for unlabeled
  controls, added real tooltip behavior and resilient label truncation to
  toggles, reset transient interaction states when controls become disabled,
  added a disabled state to split buttons, and now enforce the same
  visible-label-or-semantics contract across chips, tabs, dropdowns, and split
  buttons.

## [0.9.928] - 2026-03-17
### Added
- Voice-driven time tracking: the task agent can now create time tracking entries
  from voice dictation. Users can say things like "I worked on the API from 2 to
  4 PM" or "Start a timer at 7 PM" and the agent will propose a journal entry
  with the correct timestamps. Supports both completed sessions (start + end)
  and running timers (start only). Entries require user approval via the change
  set confirmation UI.
- Projects UI: full project management interface with create/detail pages,
  project picker for tasks, category integration, health header on tasks page,
  and project-based task filtering. Each project auto-creates an AI agent for
  analysis and reporting.
- Projects feature flag: all project UI is gated behind the `enableProjects`
  config flag (default: off), keeping the feature hidden until ready for release.
- Expandable project health header: the tasks page header now shows a collapsible
  summary card with project/task counts that expands to per-project rows with
  status chips and navigation.
- Project status picker: interactive bottom sheet on the project detail page for
  changing project status across all five variants.

### Removed
- Prompt tab and prompt editing page from AI settings. Prompts are now managed
  internally and no longer require manual user configuration.

### Removed
- Tags: removed the entire tag concept — generic tags, person tags, and story
  tags — including all UI (tag modals, tag settings pages, tag chips on entries),
  sync/outbox infrastructure, services, and repositories. The `tag_entities` and
  `tagged` database tables are intentionally left in place to avoid migrations
  but are no longer accessed or defined in the schema. Deprecated fields are
  retained in data models for JSON backward compatibility.

## [0.9.927] - 2026-03-16
### Fixed
- Matrix sync catch-up: fixed two bugs that prevented cold-restart catch-up
  from paginating server history correctly. Backfill no longer short-circuits
  on marker ID before reaching the timestamp boundary, and the local expansion
  loop no longer overwrites paginated events with a smaller local-only snapshot.

## [0.9.926] - 2026-03-15
### Added
- Category AI defaults: categories can now define a default inference profile
  and agent template. New tasks created in the category automatically inherit
  the profile (for speech-to-text and image analysis) and get an agent
  auto-assigned from the template.
- Agent content-gating: auto-assigned agents enter a "waiting" state and only
  activate once the task has meaningful content (linked entries with non-empty
  text), preventing premature agent runs on blank tasks.
- Task-level profile fallback: when a task has no agent, the profile automation
  system falls back to the task's inherited profile for skill automation
  (transcription, image analysis).

## [0.9.925] - 2026-03-15
### Fixed
- Notifications: honor the notification config flag across all notification
  methods. Previously, the "tasks in progress" badge notification and
  general show notifications were sent even when notifications were disabled.

## [0.9.924] - 2026-03-15
### Added
- Cover art skill: image generation now runs as a background skill via the
  unified skill pipeline, with fire-and-forget workflow that auto-imports the
  generated image and assigns it as task cover art.
- Reference image selection: linked-task cover art images are now discovered
  automatically via bidirectional task graph traversal (with link icon overlay),
  and the selection limit has been increased from 3 to 5 images.
- Cover art modal: stays open after triggering generation with Siri waveform
  progress animation; dismissible without stopping background generation.
- Automatic image analysis: newly generated cover art images automatically
  trigger the image analysis skill, just like a manual photo drop.

## [0.9.923] - 2026-03-15
### Added
- Inference profiles: new "Thinking (High-End)" model slot for tasks where
  quality matters more than speed/cost (e.g. coding prompt generation). Falls
  back to the regular thinking model when not configured.

## [0.9.922] - 2026-03-15
### Changed
- AI popup menu: skills now appear in a dedicated top section above legacy
  prompts, with two-section layout and profile-based skill triggering.
- Automatic AI processing: only profile-driven automation runs automatically
  for audio transcription and image analysis; the legacy category-based
  automatic prompt fallback has been removed.
- Category details UI: removed the "Automatic Prompts" configuration section
  (data remains in DB for backward compatibility).
- Skill inference status: SkillInferenceRunner now updates
  InferenceStatusController so the Siri waveform animation shows during
  skill-driven inference.
- AI popup visibility: hasAvailablePromptsProvider now considers both skills
  and legacy prompts when deciding whether to show the AI assistant button.
- Preconfigured prompts: stopped seeding `audio_transcription` and
  `audio_transcription_task_context` legacy ASR prompts.

## [0.9.921] - 2026-03-14
### Changed
- Sync catch-up: reconnect recovery is now timestamp-first, paging backward
  until the stored timestamp boundary is visible, then replaying forward with
  bounded overlap. Local echo ids are no longer persisted as durable remote
  markers, and history requests now honor the configured page size.
- Sync reliability: backfill nudges wait for ordered replay batches to finish,
  and incomplete catch-up keeps live scans deferred instead of treating partial
  recovery as ready.
- Database diagnostics: all Drift-backed databases now log slow queries into
  daily `slow_queries-YYYY-MM-DD.log` files when the logging domain is enabled.
- Database indexes: new dedicated indexes for task due-dates, date-sorted task
  lists, journal browse, definition lists, linked-entry lookups, sync sequence
  scans, outbox queue scans, and agent database thread/saga/template queries.
  Index-adding migrations now safely recreate existing indexes to prevent
  startup failures.
- Journal query improvements: common browse queries use simplified fast-path
  SQL, task filters use `EXISTS` predicates instead of `CASE` branches,
  linked-child lookups use direct joins, and all-starred/all-private paths
  bypass redundant filters. Empty selections short-circuit before hitting
  SQLite, and bulk id-based fetches use an unsorted path when order is not
  needed.
- Task progress: task-card progress lookups now batch estimates and linked
  work time spans across visible task IDs through lightweight queries instead
  of loading full entities.
- Settings database: reads and writes now use a direct Drift executor instead
  of a background-isolate hop, and same-value saves return early. Settings-key
  lookups are cached in-process with concurrent cold reads coalesced.
- Config flags: `JournalDb` keeps a shared in-memory config-flag snapshot so
  per-flag consumers no longer re-query SQLite after bootstrap. Startup shell
  and navigation listeners watch only the flags they need.
- AI configs: type-based config watchers derive from a shared in-memory
  snapshot instead of re-querying `ai_config.sqlite`, and label-definition
  visibility checks use explicit private-status filters.
- Daily OS: the unified day view now ignores unrelated database notifications
  instead of reloading its full bundle on every update.

## [0.9.919] - 2026-03-12
### Changed
- Sync inbox: repeated replay of the exact same attachment event no longer
  re-runs attachment observe/download/write work unless the local file is
  missing or empty. This reduces sync log volume and unnecessary agent payload
  I/O during large catch-up waves.
- Sync logging: sync-family info logs are now routed into `sync-YYYY-MM-DD.log`
  instead of inflating the general `lotti-YYYY-MM-DD.log`. Sync errors remain
  visible in both logs.
- Sync diagnostics: receiver-side signal logging now emits burst/pass summaries
  with source breakdowns instead of one hot-path line per raw scheduler poke.
- Sync backfill follow-up: re-request paging now walks past already queued
  oldest rows, in-flight `sending` backfill requests suppress duplicates, and
  zombie-file cleanup rejects paths that resolve outside the docs directory.
- Sync reliability: marker-missing catch-up no longer replays a bounded recent
  tail as successful backlog, host progress now stays on the highest contiguous
  resolved counter, large gaps are fully materialized for backfill, and newly
  detected missing work nudges automatic backfill immediately.
- Sync convergence: reconnect catch-up now keeps paging until it either finds
  the stored Matrix marker or reaches the stored timestamp boundary, then
  replays that ordered historical slice instead of turning an ordinary offline
  backlog into redundant backfill requests.
- Agent sync startup: the app now keeps agent initialization alive from app
  startup when agents are enabled, so incoming agent backfill can resolve
  without waiting for the first entry or agent screen to be opened.
- Session rating: replaced the intrusive automatic rating modal (which popped
  up when a timer stopped) with a non-blocking pulsating star icon button next
  to the timer. The button pulses for ~10 seconds, then stays visible until a
  rating is saved. Rating remains accessible from the triple-dot menu.

### Fixed
- Fixed provider state mutation during widget tree build phase in timer
  session-ended detection by deferring to post-frame callbacks.
- Fixed RenderFlex overflow on the rate button row by replacing the outlined
  text button with a compact star icon button.
- Fixed race condition in realtime transcription stop: subscribe to the
  done-event stream before cleanup to avoid missing events on broadcast streams.

### Removed
- Label assignment snackbar/toaster — no longer needed since label assignments
  are now confirmed individually via change sets.
- Automatic rating modal trigger on timer stop — replaced by the pulsating
  rate button (see Changed above).

## [0.9.917] - 2026-03-12
### Added
- Task filter: filter by agent assignment (All / Has Agent / No Agent) in the
  Task Filter Modal. Enables efficient backfilling of agent assignments by
  showing only unassigned tasks. Zero performance overhead when filter is off.

### Fixed
- Sync backfill: exact `(hostId, counter)` hits are now validated against the
  payload's current vector clock before resend. Stale exact mappings no longer
  resend a payload and then declare the same counter unresolvable in the same
  handling pass.

### Improved
- Sync catch-up: when the stored marker cannot be found, catch-up now falls
  back to a bounded recent tail instead of replaying the entire visible room
  snapshot. This reduces repeated historical reprocessing during recovery.

## [0.9.915] - 2026-03-11
### Removed
- Legacy checklist updates prompt and task summary system — all conversation-
  based processing code, UI widgets, and associated tests have been removed.
  Task summaries are now handled exclusively by the agent system.
- SQLite logging database (`LoggingDb`) — replaced by the existing file-based
  logging in `LoggingService`. Log files are written to `{docs}/logs/lotti-YYYY-MM-DD.log`,
  easily viewable with Console.app or any text editor. The in-app log viewer
  page has been removed in favor of native log viewers.

### Improved
- Task summary resolution: a new `TaskSummaryResolver` provides unified
  fallback logic (agent report → legacy AI response) shared across prompt
  building, linked task context, and the chat summary tool.
- Agent report selection: when multiple agent-task links exist, the resolver
  now picks the most recently assigned agent instead of an arbitrary one.
- Recorder flow no longer blocks on transcription inference after recording.
- Category settings no longer offer legacy prompt types that can never run.

## [0.9.914] - 2026-03-10
### Fixed
- Local inference model display: conversation headers now show the actual
  model name (e.g. qwen3.5:9b) instead of the stale template default
  (gemini-3-flash-preview), even while a conversation is still running.
  Resolved by reading the agent instance's inference profile directly.
- Tool call count: deferred tools (set_task_title, update_task_priority, etc.)
  and locally-handled tools (update_report, record_observations) now correctly
  create action messages, so the conversation log shows accurate tool call
  counts instead of "0 tool calls".
- Ollama JSON parsing: added resilient argument parser that handles markdown
  code fences, trailing text, and brace extraction from malformed JSON that
  smaller local models sometimes produce.
- Ollama token usage: extract prompt_eval_count and eval_count from Ollama's
  final streaming chunk so token usage is recorded for local inference.

### Improved
- Local model tool loop prevention: non-batch deferred tools can now only be
  called once per wake. Repeat calls are rejected with an explicit error,
  preventing smaller models from burning all turns on the same tool.
- Guided tool responses: after a successful deferred tool call, the response
  lists remaining available tools, helping local models progress through
  title, priority, estimate, due date, etc. instead of repeating one tool.
- Raised default maxTurnsPerWake from 5 to 10, giving agents more room to
  call multiple different tools in a single wake cycle.
- Within-wake dedup for change set proposals: identical non-batch proposals
  are caught and skipped even before cross-wake dedup runs.
- Ollama logging: full response chunks are now logged for easier debugging.

## [0.9.913] - 2026-03-10
### Added
- 35 new category icons: cycling, hiking, camping, pets, gardening, cooking,
  coffee, email, chat, video call, movies, podcast, theater, coding, crafts,
  dance, laundry, repair, banking, investment, receipt, celebration, gift,
  birthday, language, science, presentation, prayer, gratitude, self-care,
  stretching, weather, nature, volunteering, and recycling.

### Fixed
- macOS crash on quit: replaced Dart `exit(0)` (which calls C `exit()` and
  triggers VM teardown/GC finalizers) with POSIX `_exit(0)` via FFI that
  terminates immediately. Also explicitly dispose media_kit Player before
  exiting so mpv's native core thread stops cleanly. Fixes SIGABRT from
  both mpv FFI callbacks and SQLite `NativeFinalizer` during VM teardown.
- Change set UI stability: resolved tiles now match pending tile height
  (added tool name subtitle and matched icon size) to prevent vertical
  jumpiness when items are confirmed or rejected.
- Label assignment: removed unnecessary rate limiter that blocked
  subsequent label confirmations in exploded change set batches.
- Follow-up task handler: removed `sourceAudioId` parameter that the LLM
  could not reliably provide, eliminating UNIQUE constraint errors from
  hallucinated IDs.
- Database: `upsertEntryLink` now guards against duplicate
  `(from_id, to_id, type)` links instead of crashing with UNIQUE constraint
  violation.

### Added
- Profile-driven skills: introduced Skills as model-agnostic AI capability
  definitions (transcription, image analysis, etc.) and skill assignments on
  inference profiles to control which skills auto-trigger when assets are added
  to a task. Seven preconfigured skills are seeded on first launch.
- Profile automation service: when an audio recording or image is added to a
  task whose agent's profile has the relevant skill with automation enabled,
  processing fires immediately via the profile's model slot — no legacy prompt
  lookup needed. Falls back to category-based automatic prompts when no
  profile-driven skill is configured.
- Profile skill assignments UI: the inference profile form now shows an
  "Automated Skills" section where users can toggle automation per skill,
  with validation that the required model slot is populated.
- Speech-recognition checkbox visibility: the opt-out checkbox now also
  appears when the task's agent profile has a transcription skill with
  automation enabled, not only when legacy category automatic prompts exist.

### Improved
- Category icon picker: replaced flat gray styling with Material 3 semantic
  colors, subtle shadows, and selected-state glow for a more polished,
  dark-mode-friendly appearance.
- Checklist dedup diagnostics: added logging of resolved title count
  in the change set builder for easier troubleshooting.

## [0.9.912] - 2026-03-09
### Added
- Qwen 3.5 local inference: added Qwen 3.5 9B and 27B models for local
  inference via Ollama with native multimodal, reasoning, and tool calling
  capabilities.
- New "Local Power (Ollama)" inference profile for higher-end devices
  using Qwen 3.5 27B for thinking and Gemma 3 12B for image recognition.

### Changed
- Updated "Local (Ollama)" inference profile to use Qwen 3.5 9B instead
  of Qwen3 8B.
- Removed superseded local models: DeepSeek R1 8B, GPT-OSS 20B/120B,
  Qwen3 8B, and Gemma 3 12B QAT.
- Default inference profiles now auto-update when upstream model IDs
  change, ensuring users always get the latest model assignments.
- New known models are automatically backfilled for existing inference
  providers on app startup.

### Fixed
- Ollama streaming tool call index: multiple tool calls streamed in
  separate chunks were merged into one malformed call because the loop
  index was used instead of the response's actual tool call index.
- Flicker on task details page.

## [0.9.911] - 2026-03-09
### Fixed
- macOS crash on close: skip SQLite database close entirely on macOS
  before calling `exit(0)`. The previous fix still crashed because the
  SIGABRT occurred during `db.close()` itself (`sqlite3_close_v2` →
  `functionDestroy` → `DLRT_GetFfiCallbackMetadata`). SQLite WAL mode
  guarantees data integrity without explicit close.

## [0.9.910] - 2026-03-08
### Added
- Task agent follow-up task creation with deferred confirmation: the agent
  can propose splitting a task by creating a follow-up task and migrating
  checklist items, all presented for user review before execution.
- Structured domain logging (DomainLogger) in the change set confirmation
  service, follow-up task handler, and checklist migration handler for
  better production diagnostics.

### Fixed
- Checklist migration: LLM-hallucinated placeholder IDs are now replaced
  with the real deterministic placeholder, fixing "Target task lookup
  failed" errors when confirming migration items.
- Checklist migration: copy is now created before archiving the source
  item, preventing data loss if the copy fails.
- Checklist migration: archival failure no longer blocks the entire
  migration — returns success with a warning instead.
- Follow-up task rejection now cascade-rejects sibling migration items
  that depend on the rejected task.
- Follow-up task handler validates priority and dueDate args, rejecting
  malformed values.
- Follow-up task handler checks createLink bool return value, surfacing
  link failure warnings.
- Change set UI now shows partial-failure warnings in snackbars instead
  of silently discarding them.

## [0.9.909] - 2026-03-08
### Added
- Vector search distance telemetry: search result cards now show a
  color-coded cosine distance badge during vector search mode, and
  distance distribution (min/median/max) is logged for threshold
  calibration.

## [0.9.908] - 2026-03-07
### Fixed
- Sync backfill: agent entities and links are now included in automatic
  sequence log population at startup (previously only journal entries and
  entry links were populated, leaving agent counters unrecorded).
- Sync backfill: added self-request guard to prevent hot-loop when echoed
  backfill requests arrive back from the Matrix room.
- Sync backfill: "Reset Unresolvable" action in sync diagnostics allows
  recovery of entries incorrectly marked as permanently unresolvable.

### Changed
- Sync performance: host activity cache (5-minute TTL) reduces redundant
  DB queries during incoming entry processing.
- Localization: added ICU plural forms for reset success messages across
  all supported languages.

## [0.9.907] - 2026-03-07
### Added
- Individually rejectable label suggestions: agent-proposed labels are now
  shown as separate confirmable/rejectable items instead of a single bundle.
- Rejecting a label automatically suppresses it so the agent does not
  re-propose it in future wakes.

## [0.9.906] - 2026-03-07
### Added
- Added an ObjectBox-backed embedding store POC for ANN search.

### Changed
- Switched the current vector backend toggle to the ObjectBox path for macOS
  benchmarking, including the required sandboxed macOS app-group
  configuration.

## [0.9.905] - 2026-03-06
### Added
- Unified embedding generation: select multiple categories at once instead of
  one at a time. Includes Select All / Unselect All toggle.
- Vector search now available on the journal tab (previously tasks-only).

### Changed
- Refactored the embedding pipeline behind a backend-neutral store interface to
  prepare alternate vector backends without another large call-site migration.

### Removed
- Removed "Re-index All Embeddings" maintenance action (superseded by
  multi-category generate).

## [0.9.904] - 2026-03-06
### Fixed
- Embedding backfill failing with "input length exceeds the context length" for
  entries containing code, URLs, or long unpunctuated text. The chunk target was
  lowered from 384 to 256 estimated tokens to leave sufficient headroom for
  content where the word-based heuristic undercounts.

### Added
- Sequence log backfill now includes agent entities and agent links alongside
  journal entries and entry links, closing sync gaps for agent data.

## [0.9.903] - 2026-03-06
### Fixed
- AI task agent no longer repeatedly proposes checklist items that already exist
  on the task, were previously confirmed, or were explicitly rejected.
- Pending change proposals are now included in the agent's LLM context so it
  avoids re-proposing items that are already queued for user review.

## [0.9.902] - 2026-03-06
### Added
- One-time backfill of vector clocks on agent entities and links created before
  the clock-stamping fix. Stamps oldest-to-newest, persists, and enqueues each
  for cross-device sync via the Sync Maintenance modal.

## [0.9.901] - 2026-03-05
### Fixed
- Task agent provider now reacts to sync notifications, so agents created on
  one device appear in the task detail view on other devices without a restart.
- Removed unused collapsible section wrapper from linked entries widget.

### Added
- Date-range re-sync for agent entities and links. The Maintenance re-sync
  action now includes agent data within the selected time interval instead of
  requiring a full sync of all agent records.

## [0.9.899] - 2026-03-04
### Fixed
- Break backfill amplification loop: superseded outbox entries now respond with
  hints (carrying the payload ID) instead of "unresolvable" flags, preventing
  the requester from re-requesting the same counter indefinitely.
- Agent entities and links now record their vector clock counters in the sync
  sequence log on both send and receive paths. Previously, agent payloads
  consumed counters but never logged them, creating permanent phantom gaps that
  triggered unresolvable backfill requests and contributed to outbox spikes.

## [0.9.898] - 2026-03-04
### Added
- Overlapping document chunking for vector search embeddings. Long transcripts
  and agent reports are now split into overlapping chunks so every part of a
  long recording is semantically searchable, not just the first ~400 words.
- Composite embedding index (entity_id + chunk_index) supporting multiple
  vectors per source document.
- Re-index All Embeddings maintenance action to rebuild all embeddings with
  the new chunking strategy.

## [0.9.897] - 2026-03-03
### Added
- Enhanced agent observations with priority and category fields. Task agents
  can now flag observations as critical grievances or excellence notes, enabling
  targeted self-correction across wakes and prominent surfacing in 1-on-1
  ritual sessions.
- High-priority feedback card (GenUI): dedicated widget rendering grievances
  (red accent) and excellence notes (green accent) inline in evolution chat.
- Ritual context builder injects a HIGH-PRIORITY FEEDBACK section before
  general feedback so improver agents address critical items first.
- Task agents review their own prior critical observations at the start of
  each wake for self-correction.

## [0.9.896] - 2026-03-03
### Added
- Outbox priority queue: user-initiated actions (journal entries, entry links)
  now sync before bulk operations (entity definitions, tags, AI config). Three
  priority levels (high/normal/low) ensure responsive UX during large resyncs.
- Sync health reporter: periodic health summary (every 5 min) logs outbox and
  sequence log counters when sync domain logging is enabled.
- Domain-filtered sync logging in outbox send path via DomainLogger.

## [0.9.895] - 2026-03-03
### Changed
- Simplified audio recording modal: removed Checklist Updates and Task Summary
  checkboxes. These prompts now always use category defaults when configured,
  with no per-recording user toggle.
- New system FTUE setup no longer populates automatic checklist update and task
  summary prompts on categories. Existing categories are unaffected.
- Removed automatic task summary infrastructure (scheduled refreshes, smart
  triggers, countdown UI). Task summaries are now generated on demand by agents.
  Existing summaries remain viewable and deletable.

## [0.9.894] - 2026-03-02
### Added
- Vector search testing UI: toggle between full-text (FTS5) and vector
  (Ollama embedding) search on the tasks page. Shows timing and result
  count for evaluating search quality. Controlled by a new feature flag
  in Settings > Flags.

### Improved
- Agent template settings tab UX: the 1-on-1 review button is now prominently
  placed in the sticky bottom bar when no edits have been made. Save/Cancel
  buttons only appear when the form has unsaved changes.
- Directive text areas expand to full height instead of capping at 12 lines.
- Profile selector label changed from "Inference Profiles" to
  "Default inference profile" for clarity.
- Delete action moved from bottom bar to Stats tab to reduce clutter.

### Fixed
- Evolution 1-on-1 review flow: restored the chat entry FAB so the interactive
  conversation can always be opened from the review page.

## [0.9.893] - 2026-03-02
### Added
- Voice transcription in evolution chat: mic button with batch and realtime
  recording modes, matching the existing AI chat transcription flow.
  Transcript populates the text field for editing before sending.

## [0.9.892] - 2026-03-02
### Added
- Split agent template directives into separate general directive (persona,
  tools, objectives) and report directive (output structure, formatting) fields.
  Existing templates are automatically seeded with purpose-built defaults.
- Agent reports now support a structured TLDR field alongside the full report
  content. The TLDR is always visible with the full report expandable below.
- Template edit page shows two distinct text areas for general and report
  directives instead of a single combined field.
- Evolution proposals now present both directive fields independently with
  separate diff views.

## [0.9.890] - 2026-03-01
### Added
- Meta-improver agent: recursive self-improvement layer that evaluates and
  improves the template-improver agents themselves. The meta-improver runs
  monthly rituals focused on improver effectiveness, directive churn stability,
  proposal acceptance rates, and session outcome trends.
- Seeded meta-improver template with meta-level directives for evaluating the
  improvement process rather than task-level performance.
- Evolution session feedback extraction: the feedback pipeline now includes
  signals from evolution session outcomes (ratings, completion, abandonment)
  and directive churn detection for improver templates.
- Recursion depth policy enforcement: improver agent creation validates against
  the maximum recursion depth (capped at 2 per ADR 0012).

## [0.9.889] - 2026-03-01
### Fixed
- Agent no longer proposes redundant changes that match the current state.
  Checklist items already checked/unchecked, estimates, priorities, due dates,
  statuses, and titles are now filtered at proposal time instead of cluttering
  the confirmation UI. The agent receives corrective feedback so it adjusts its
  reasoning.
- Cross-device sync of confirmed/rejected change sets now works reliably.
  Agent entity payloads are fetched from the attachment descriptor before
  falling back to disk, preventing stale reads when the file download hasn't
  completed. Agent links are kept inline in text events for immediate
  availability.

## [0.9.888] - 2026-02-28
### Added
- Inference Profiles: named configuration bundles that group model assignments
  per capability slot (thinking, image recognition, transcription, image
  generation). Profiles replace direct model references on agent templates and
  instances, enabling intent-based selection like "keep data local" or
  "use EU infrastructure".
- Profile management UI accessible from AI settings, with CRUD operations,
  deletion guards, and six seeded default profiles.
- Two-page agent creation modal (template + profile selection) replaces
  the former single-step template picker.
- Profile selector on both template detail and agent detail pages.

## [0.9.887] - 2026-02-28
### Added
- Agent now learns from past user decisions: confirmed, rejected, and deferred
  proposals are fed back into the agent's wake context so it avoids repeating
  rejected suggestions and builds on confirmed preferences.

### Fixed
- Agent no longer proposes redundant label assignments when a task already has
  3 or more labels. The available labels context is now omitted for fully-labeled
  tasks, preventing unnecessary change set proposals in the confirmation UI.

## [0.9.885] - 2026-02-28
### Changed
- Agent sync now uses file-attachment pattern (same as journal entities),
  preventing failures when agent payloads exceed Matrix's 60KB text event
  limit. Existing inline messages remain backward-compatible.

## [0.9.884] - 2026-02-28
### Added
- Domain-specific logging infrastructure with PII-safe sanitization
  and per-domain toggles (agent runtime, agent workflow, sync) in
  Settings > Advanced > Logging Domains.
- Defensive fixes for agent wake orchestrator: synchronous timer
  scheduling before async DB write, drain timeout guard to prevent
  stuck locks, and error-level logging for wake run insert failures.

### Changed
- Agent settings navigation now uses Beamer-native back navigation,
  fixing double-back-press and bottom-transition bugs in the
  Settings > Agents flow.
- Agent report section on task detail: refresh icon replaces play icon
  when idle, play-now + countdown pill + cancel button during countdown,
  stable robot icon on the left with no layout jumps.
- Responsive token usage table: vertical card layout on narrow screens
  (<600 px), standard table on wide screens.
- Template detail page hides bottom bar on non-editable tabs (Stats,
  Reports).
- Shortened "Save as New Version" button labels across all locales to
  prevent truncation on narrow screens.
- Agent report section positioned above legacy AI summary in task form.

## [0.9.883] - 2026-02-28
### Added
- Checklist user sovereignty: track who last toggled each checklist item
  (user or agent) and prevent the AI agent from overriding user-set states
  without a substantive reason citing post-dated evidence.

## [0.9.882] - 2026-02-28
### Added
- Aggregate token usage tracking per template with tabbed detail page
  (Settings / Stats / Reports) showing per-model summaries across all
  instances and per-instance breakdowns with lifecycle badges.

## [0.9.881] - 2026-02-28
### Added
- Token usage section on agent detail page showing aggregated input, output,
  thinking, and cached token counts per model with grand totals.

## [0.9.880] - 2026-02-27
### Added
- Bulk-delete button for old AI task summaries, with confirmation dialog
  showing the count of summaries to be deleted.

## [0.9.879] - 2026-02-27
### Changed
- Task-agent linked task context now uses latest linked task-agent reports
  instead of legacy linked task summaries.
- Agent state refresh for persisted throttle updates now routes via
  `UpdateNotifications` (removing the dedicated orchestrator state stream).
- Template MTTR chart data loading now de-duplicates linked task lookups and
  resolves agent/task queries concurrently.

## [0.9.878] - 2026-02-27
### Added
- Settings > Agents page with Templates and Instances tabs, replacing the
  standalone Agent Templates page.
- Agent instances list with kind filter (All / Task Agent / Evolution) and
  lifecycle filter (All / Active / Dormant / Destroyed).
- Expandable TLDR agent report section on task detail page, shown when an
  agent has produced a report.
- Agent report format aligned with task summary structure (TLDR, Achieved,
  Remaining, Learnings).

### Changed
- Agent default model changed from Gemini 3.1 Pro to Gemini 3 Flash.
- Agent report section uses expandable TLDR pattern instead of plain markdown.
- Agent report tool description now references system prompt structure and
  encourages agents to express their personality.

## [0.9.877] - 2026-02-27
### Added
- Alibaba Cloud (Qwen) as AI inference provider with 5 models including text,
  vision, reasoning, audio, and image generation variants via DashScope API.
- Qwen3 Omni Flash for audio transcription via Alibaba provider.

## [0.9.876] - 2026-02-27
### Added
- Outbox payload size tracking: records total payload size (JSON + file attachment)
  for each outbox item and displays it in the outbox monitor list.
- Daily outbox volume aggregation query with configurable time window.
- Database migration (sync DB schema v5) adding `payload_size` column to outbox table.
- Daily sync volume bar chart on the Outbox Monitor page showing 30 days of
  outbox throughput in KB.
- `headerSliver` slot on `SyncListScaffold` for inserting content between the
  filter header and the list.

## [0.9.875] - 2026-02-27
### Fixed
- Task agent automatic trigger broken after throttle optimization: fixed
  `_scheduleDeferredDrain` silently dropping drain when deadline already expired,
  added periodic safety-net timer to recover stuck queue jobs, and fixed startup
  hydration race that could cancel just-scheduled deferred drain timers.
- Agent template model selection not persisted when editing: changing the AI model
  in edit mode now correctly saves the updated model ID to the template entity.

## [0.9.874] - 2026-02-27
### Added
- Evolution chat: multi-turn GenUI conversation for reviewing agent template
  performance, providing structured feedback, and approving LLM-rewritten
  directives.
- Evolution dashboard with 2x2 mini chart grid: success rate sparkline, wake
  history bar chart, version performance comparison, and MTTR trend.
- MTTR chart now measures true task resolution time (agent creation to task
  DONE/REJECTED) instead of individual wake run execution duration.
- GenUI catalog integration for evolution workflow: proposal cards with
  approve/reject actions, note confirmation cards with expand/collapse, and
  version comparison diffs.
- Labels included in agent task summary reports.

### Fixed
- `assign_task_labels` tool crash due to `LabelsRepository` not being available
  outside Riverpod context.
- Countdown timer digit "breathing" fixed with tabular figures font feature.

## [0.9.873] - 2026-02-27
### Added
- Agent tools: `set_task_language`, `set_task_status`, and `assign_task_labels`
  for automated task metadata management.
- Correction examples context injection: agent receives per-category
  transcription correction patterns for improved checklist editing.
- Label context injection: agent receives assigned, suppressed, and available
  labels for informed label assignment.
- Defer-first throttle: initial agent wake deferred by 120 seconds to coalesce
  bursty edits, down from 300-second post-execution cooldown.
- Standardized agent report structure with TLDR, Achieved, What's left, and
  Learnings sections.
- ASR re-trigger: audio entry updates now notify the parent task, enabling
  agent wakes when transcription arrives.

## [0.9.872] - 2026-02-26
### Added
- Agent throttle gate: 5-minute cooldown between automatic subscription-triggered
  agent wakes to reduce token consumption during rapid task mutations.
- "Run Now" button on task agent chip to bypass throttle and trigger immediate
  agent execution.
- Countdown timer on task agent chip showing remaining throttle cooldown time.
- Throttle deadline persistence via `nextWakeAt` field, surviving app restarts
  and backgrounding.

## [0.9.871] - 2026-02-26
### Fixed
- Reference image selection not rendering in cover art generation modal due to
  unbounded height constraints from the modal's scrollable content area.

## [0.9.870] - 2026-02-24
### Added
- Agent templates: full-stack feature for creating, editing, and managing
  reusable agent templates. Includes database schema, repository, service layer,
  Riverpod providers, and UI (list page, detail page with model selector).
- Template evolution workflow: LLM-assisted 1-on-1 page for reviewing agent
  performance metrics, providing structured feedback, and having the LLM rewrite
  template directives for approval.
- Template performance metrics: track token usage, execution counts, and success
  rates per template.
- Inference provider resolver for selecting AI models per template.
- Settings navigation for agent templates (list, create, edit).

## [0.9.869] - 2026-02-23
### Added
- Provider filter for category prompt selection: when multiple AI providers
  exist, filter chips let users narrow the prompt list by provider.
- Collapsible text entries in linked-entry context: text notes can now be
  collapsed/expanded like images and audio entries.
- Agent cross-device sync: agent entities and links are now synchronized via
  Matrix using `SyncAgentEntity` and `SyncAgentLink` message variants. Incoming
  agents restore wake subscriptions so task agents resume monitoring on the
  receiving device.
- Sync maintenance support for agents: the maintenance UI includes
  "Agent Entities" and "Agent Links" re-sync steps that broadcast all local
  agent data to peer devices.
- Zone-based transaction isolation in `AgentSyncService`: outbox messages are
  buffered during transactions and flushed only on successful commit. Nested
  transactions are supported via a depth counter; rollback discards all buffered
  messages.

### Fixed
- Desktop app no longer crashes on exit: `WindowService` now disposes
  `OutboxService` and `MatrixService` before destroying the window.
- Reference image selection: the "Continue" button is no longer hidden when
  many images are available. The image grid now scrolls independently while
  the button stays pinned at the bottom.

## [0.9.868] - 2026-02-22
### Added
- Agent cross-device sync via Matrix: agent entities and links synchronize
  across devices with wake subscription restoration.
- Sync maintenance UI supports agent re-sync steps.
- Zone-based transaction isolation: outbox messages are buffered until commit,
  with nested transaction and rollback support.

## [0.9.867] - 2026-02-22
### Added
- Agent running-state feedback: reactive spinner indicators on the task page
  agent chip and agent detail page app bar show when an agent is actively
  executing.
- Agent inspectability: tool call arguments and results are now persisted as
  message payloads and viewable in expandable activity log cards with monospace
  formatting. User messages sent to the LLM are also persisted.
- Conversation view: agent detail page now has tabbed Activity/Conversations
  views, with the conversation tab grouping messages by wake cycle (thread).
- Post-execution signal drain: signals arriving while an agent is running are
  no longer lost — a 30-second drain timer picks up deferred work after
  execution completes.

## [0.9.866] - 2026-02-21
### Added
- Task Agent: persistent AI agents that maintain task summary reports and
  perform incremental metadata updates via tool calls (estimates, due dates,
  priorities, checklist items, titles). Gated behind the `enableAgents` config
  flag with a dedicated `agent.sqlite` database, wake orchestration with
  self-notification suppression, fail-closed category enforcement, and an
  agent detail inspection page with activity log, report viewer, and lifecycle
  controls (pause/resume/destroy).

## [0.9.865] - 2026-02-18
### Added
- Real-time transcription via Mistral Voxtral WebSocket API with live subtitles
  during recording (~2s latency). Available in both AI chat and the journal
  audio recording modal via a mode toggle.
- Native WAV-to-M4A audio conversion via platform channels on iOS and macOS.

## [0.9.864] - 2026-02-18
### Improved
- Checklist swipe backgrounds now extend edge-to-edge, filling the full card
  width when swiping to archive or delete.

### Added
- Archived checklist items are now marked as such in AI prompt context,
  with clear instructions that they are not active work — handled elsewhere,
  no longer relevant, or kept for reference only.

## [0.9.863] - 2026-02-17
### Added
- Archive swipe gesture for checklist items: swipe right to archive, preserving
  historical context without marking items as completed. Archived items are
  excluded from completion metrics and hidden in "Open" filter mode.

## [0.9.861] - 2026-02-16
### Changed
- Upgraded Flutter to 3.41.1 (Dart 3.11.0).
- Removed legacy `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` from iOS Podfile, fixing simulator builds on Xcode 26+.
- Added `iphonesimulator` to `SUPPORTED_PLATFORMS` in Xcode project settings, restoring simulator destination discovery.

## [0.9.860] - 2026-02-13
### Changed
- Enabled SQLite WAL mode, busy_timeout (5s), and synchronous=NORMAL for all databases via setup callback. Prevents "Database is Locked" errors when multiple isolates access the same file.
- Added read pool of 4 isolates to JournalDb for offloading heavy reads from the UI thread.
- Added `background` and `readPool` parameters to `openDbConnection()` and forwarded directory providers to JournalDb, SettingsDb, and SyncDatabase constructors, preparing for actor-based sync isolate.

## [0.9.859] - 2026-02-13
### Changed
- Removed artificial 200ms delay from sync outbox message enqueueing, improving outbox throughput.
- Reduced user-activity idle threshold from 3s to 1.2s so the outbox resumes sending sooner after user interaction.

## [0.9.858] - 2026-02-13
### Changed
- Replaced Drift table-watcher streams with notification-driven streams for categories, habits, dashboards, measurables, labels, tags, and settings. Eliminates redundant DB polling and prepares for isolate-based sync.
- Deduplicated notification-driven stream helpers into a single generic implementation.

### Fixed
- Sync deserialization: unknown enum values from newer devices (e.g., new AI provider types) no longer cause infinite retry loops; unrecoverable `ArgumentError`/`FormatException` errors are logged and skipped.
- Config flag init order: `initConfigFlags` now runs before `EntitiesCacheService.init()` so the private-entries flag reads its seeded default (`true`) on fresh installs instead of `false`.
- Tags late-subscriber replay: `TagsService.watchTags()` now emits cached tags immediately for late subscribers instead of waiting for the next notification.
- Theming sync race: `ThemingController` subscribes to setting notifications before the initial async load, preventing sync theme updates from being dropped during the init window.

## [0.9.857] - 2026-02-12
### Changed
- Removed M4A-to-WAV audio conversion for Mistral — all providers now accept M4A natively. Eliminates FFmpeg dependency and file size quota issues.
- Updated Voxtral model description to reflect Voxtral Transcribe 2 capabilities with support for 13 languages and up to 1 GB / 3 hours per file.

## [0.9.856] - 2026-02-11
### Fixed
- Emoji Verification Flow: SAS verification now reacts to SDK `onUpdate`/`isDone` state changes, triggers a post-verification device-key refresh, and forces a sync rescan so sync resumes without restarting desktop or mobile.
- Verification UX: Both outgoing and incoming verification modals now provide clearer "waiting for other device" feedback during confirmation and transition more reliably to the success state.
- Verification Status Refresh: After SAS verification completes, the app now retries unverified-device refresh for a short window so the stale "unverified" badge clears without manual refresh, and desktop provisioning auto-advances from the QR step to the final status page once trust state is updated.
- Provisioned Sync Disconnect: Disconnect now uses an explicit confirmation dialog (`Cancel` + destructive confirm) and closes the status modal after successful deletion.
- Logging Performance: Sync-related logging no longer forces a disk flush for every non-test log line. File writes are now buffered and batched, with forced flush reserved for error-level paths.

### Changed
- Sync Onboarding: The legacy manual Matrix setup wizard was removed from Settings, leaving provisioning as the single onboarding path while keeping emoji/SAS verification available from the provisioned flow.

## [0.9.855] - 2026-02-10
### Added
- Matrix Provisioning Wizard: New sync onboarding flow that lets a desktop device paste or scan a Base64-encoded provisioning bundle (homeserver, user, password, room ID), log in, join the sync room, rotate the password, and display a QR code with updated credentials for a mobile device to scan and complete setup. Includes full validation, step-by-step progress UI, error handling with retry, and a status page showing the connected account.

### Changed
- Flexible Ratings Model: Session ratings are now driven by a catalog registry instead of hardcoded questions. Each rating dimension snapshots its question metadata (question text, input type, option labels) at save time, making stored ratings fully self-describing. Unknown catalogs (e.g. received via sync from a newer client) render in read-only mode with a graceful fallback chain: stored metadata, catalog lookup, then dimension key.
- Matrix Sync Room Creation: Sync rooms are now created with encryption state in the initial room creation request (instead of relying on a later room snapshot), and room names now include the creating username for easier server-side identification.


## [0.9.852] - 2026-02-09
### Fixed
- Calendar Navigation: Tapping a time recording in the calendar view could navigate to a session rating instead of the parent task. The calendar link resolver now filters out RatingLinks, so only the Task-to-TimeRecording relationship is used for navigation.
- Session Rating Category: Newly created session ratings inherit the category of the time entry they rate, so they display the correct task icon instead of a generic one.
- Timer Entry Category: Starting a timer from a task now forwards the task's category to the new time recording, ensuring it is explicitly stored rather than left blank.
- DailyOS Migration: The old Calendar tab was removed and replaced by the DailyOS tab. The classic calendar day view was removed and `/calendar` now always opens DailyOS. The old calendar and DailyOS feature flags were replaced by a single `enable_daily_os_page` flag.

## [0.9.851] - 2026-02-09
### Fixed
- Task Time Summation: Overlapping linked entries (e.g., a gym trip containing a fitness workout) are no longer double-counted when calculating time spent on a task. The task progress view now uses the same union-of-time-ranges algorithm that already powered the accurate Time Budget view, so both display consistent durations.

## [0.9.850] - 2026-02-08
### Added
- Collapsible Linked Entries: Image and audio entries linked to a task can now be individually collapsed and expanded with a chevron toggle. When collapsed, a compact preview shows a thumbnail (for images) or mic icon with duration (for audio) alongside the date, so you can identify entries at a glance without scrolling past large media. Collapse state is saved per link and synced across devices.
- Collapsible Section Header: The "Linked Entries" section header now has a collapse chevron to hide the entire section at once, with smooth animated expand/collapse transitions.

## [0.9.849] - 2026-02-08
### Added
- Session Ratings: After stopping a timer that ran for at least one minute, a quick-rating modal prompts you to rate the session across four dimensions — productivity, energy, focus, and challenge-skill balance. Ratings are stored as journal entities linked to the time entry, with full sync support.
- Session Ratings Config Flag: A new "Enable Session Ratings" toggle in Settings controls whether the rating prompt appears. Disabled by default.

### Fixed
- Linked Entries Deserialization: Adding a new EntryLink variant (RatingLink) broke deserialization of all pre-existing links in the database, causing linked entries to disappear entirely from task detail pages. Fixed by using a freezed fallback union.

## [0.9.848] - 2026-02-08
### Added
- Czech Language: Full Czech (čeština) localization with ~1360 translated strings covering the entire app UI.
- Platform Locale Registration: Added missing locale entries for iOS, macOS, and Windows so that all supported languages (cs, es, fr) are properly declared on every platform.

## [0.9.847] - 2026-02-07
### Fixed
- Audio Transcription: Single-speaker recordings no longer include an unnecessary "Speaker 1:" prefix. Speaker labels now only appear when multiple distinct voices are detected.
- Checklist Creation: AI-powered checklist generation is now snappy regardless of the model used. Multiple individual function calls from the model are coalesced into a single batch database write, eliminating incremental UI updates.
- Checklist Prompt: Strengthened instructions to enforce single-call batch creation, preventing models like Gemini Flash from splitting items across multiple function calls.
- Deprecated Handler: The legacy `add_checklist_item` function is no longer processed; models that hallucinate this function name receive a redirect to the batch API.
- Image Analysis: URLs extracted from screenshots are now always returned as proper Markdown links. URLs lacking a protocol (e.g., browser address bars showing `github.com/pulls`) are automatically prefixed with `https://`.

## [0.9.846] - 2026-02-07
### Fixed
- Automatic Image Analysis: Images imported via the photo library/camera roll now trigger automatic AI image analysis when configured on the category. Previously only paste and drag & drop triggered analysis; photo library imports required manually opening each image.
- Automatic Image Analysis: Screenshots now also trigger automatic AI image analysis when configured on the category.

## [0.9.845] - 2026-02-06
### Added
- Gamey Design System: A complete vibrant visual theme with playful gradients, glow effects, and animations
  - Gamey color palette with feature-specific colors (journal teal, habit green, task blue, mood lavender, AI cyan, etc.)
  - Gradient system with feature gradients, reward tiers (gold/silver/bronze), neon, shimmer, and background gradients
  - Glow effects system with subtle/medium/strong/intense intensity levels and feature-specific glows
  - Animation utilities with spring curves, durations, and staggered animation support
  - `GameyThemeBuilder.apply()` integrates the gamey theme without modifying existing FlexColorScheme infrastructure
- Gamey Widgets: Full set of themed UI components
  - `GameyCard` and `GameySubtleCard` with gradient borders, glow effects, and tap animations
  - `GameyFab` with custom character image and press animation for the gamey theme
  - `GameyJournalCard` and `GameyTaskCard` for themed list items
  - `GameySettingsCard`, `GameyToggleCard`, and `GameySettingsSection` for settings pages
  - `GameyIconBadge` with gradient background and optional glow
  - `GameyProgressBar` with animated gradient fill and shimmer effect
  - `AdaptiveSettingsCard` that auto-selects gamey or standard styling based on active theme
- Theme Selection: Theme picker dropdowns now include the Gamey theme option with localized labels

### Fixed
- Theme Selection: Replaced `TextEditingController` with `InputDecorator` in `SelectTheme` for proper dropdown behavior
- Card Wrapper: Fixed `getIt.reset()` usage in test teardown for reliable test isolation
- Gamey FAB: Prevented double invocation of `onPressed` callback
- Gamey Task Card: Localized task status labels and added null-safety for `coverArtId`
- Gamey Settings Card: Honored `accentColor` parameter, passed `showChevron` and `iconGradient` correctly
- Gamey Card Animation: Handled `animateOnChange=false` in `didUpdateWidget` to avoid unnecessary animations

## [0.9.844] - 2026-02-05
### Added
- Cover Art Reference Images: Select up to 3 images linked to a task to guide the AI's visual style when generating cover art
  - New reference image selection step appears before cover art generation
  - Images are processed (resized to max 2000px, compressed to JPEG) before sending to Gemini
  - AI prompt updated to incorporate reference image style, materials, and atmosphere
  - Skip option available if no reference images are desired
  - Auto-skips if the task has no linked images
- Journal Repository: New `getLinkedImagesForTask()` method for retrieving images linked to a task
- Cover Art Cleanup: Deleting an image that's used as task cover art now automatically clears the `coverArtId` reference

### Fixed
- Image Generation Modal: Button overflow issues on smaller screens resolved with flexible layout
- Compact Task Progress: `showTimeText` parameter now defaults to platform-appropriate behavior (desktop shows time, mobile hides)

## [0.9.843] - 2026-02-05
### Changed
- Daily OS Time Budgets: Optimized UI for tasks with no budgeted time
  - Scenario A (no budget, no time recorded): Shows compact "No time budgeted" badge instead of cluttered "0m / 0m" + "0m left" + warning banner
  - Scenario B (no budget, time recorded): Shows "Xm / 0m" with "No time budgeted" badge instead of confusing negative time remaining
  - All badges now consistently right-aligned across all budget cards
  - Bordered badge styling with warning icon for clear visibility

## [0.9.842] - 2026-02-04
### Added
- Daily OS Timeline: Drag-and-drop support for planned time blocks
  - Long-press a block to initiate drag mode with haptic feedback
  - Move mode: drag the block body to reschedule the entire block
  - Resize mode: drag top/bottom edges to adjust start/end times
  - Section-bounded: blocks stay within their visible timeline section
  - Visual feedback: elevated styling, time labels, and duration indicator during drag
  - Small blocks (under 48px) use move-only mode to avoid cramped resize handles
  - 5-minute snap grid for precise scheduling
  - Disabled for blocks overlapping compressed timeline regions (expand first)

## [0.9.839] - 2026-02-03
### Fixed
- Audio Transcription: Prevent speaker name hallucinations in multi-speaker recordings
  - AI prompts now explicitly require "Speaker 1:", "Speaker 2:", etc. labels
  - Prohibits guessing speaker identities from voice characteristics or context
  - Speech dictionary terms are now only used for spelling corrections, not speaker identification

## [0.9.838] - 2026-02-03
### Changed
- Daily OS Time History Header: Refined visual design for a cleaner, more polished look
  - Selected day indicator now compactly wraps weekday and day number instead of extending over chart
  - Weekend days also use compact indicator styling for visual consistency
  - Removed vertical dividers between days for a cleaner appearance
  - Repositioned chart to sit below day labels with better visual separation
  - Wider selection boxes for improved touch targets and visual balance

## [0.9.837] - 2026-02-02
### Added
- Daily OS Time Budgets: Quick task creation button on each budget row
  - Tap the "+" button to instantly create a task with the category pre-assigned
  - Due date automatically set to the selected day
  - Navigates directly to task detail screen for immediate editing
  - Reduces friction when planning tasks during daily review

## [0.9.836] - 2026-01-31
### Added
- Daily OS Time History Header: New horizontally scrollable day navigation header
  - Replaces arrow-based navigation with tap-to-select day segments
  - Sticky month label shows the currently visible month(s)
  - Selected day highlighted with primary color border
  - Infinite scroll loads more history (14 days at a time)
  - Today button appears when not viewing current day
  - Displays day label chip and budget status indicator
- Daily OS Time History Header: Stream chart visualization showing time-by-category
  distribution across days with symmetric stacked areas using the graphic library
### Changed
- Daily OS Time History Header: Avoid full stacked-height recomputation when loading
  more history unless the scale changes
- Daily OS Time History Header: Scale the stream chart to the maximum daily total
  with a 6-hour minimum
- Daily OS Time History Header: Removed 180-day history cap for continuous exploration;
  users can scroll through unbounded history while memory remains efficient through
  lazy loading and viewport-based chart rendering

## [0.9.835] - 2026-01-31
### Changed
- Daily OS Time Budgets: Tasks completed on a different day now show a faded checkmark (45% opacity)
  - When viewing a past date where a task was scheduled but completed later, shows faded checkmark instead of hollow circle
  - Tasks completed on the viewed day still show full-opacity checkmark
  - Removes italic text styling for completed tasks for cleaner appearance
- Daily OS Time Budgets: P2 (Medium) priority badges now visible alongside other priorities
  - Previously only P0, P1, P3 badges were shown; P2 was hidden as the default

## [0.9.834] - 2026-01-31
### Changed
- Daily OS Time Budgets: Redesigned with slim two-row header for reduced vertical space
  - Row 1: Category name, task completion indicator (count + circular progress ring), expand/collapse toggle
  - Row 2: Time recorded/planned, fixed-width progress bar, status text
  - Progress bar uses consistent green/red coloring (not category colors) and aligns in columns
  - Simplified typography with fewer font size/weight variants
- Daily OS Focus Mode: Time budget cards auto-collapse based on active time block
  - When inside a planned block, the matching category stays expanded while others collapse
  - Helps focus attention on the current activity without manual toggling
  - Manual expand/collapse still available for any category

### Fixed
- Daily OS Focus Provider: Fixed Riverpod violation where ref.watch was called inside async loop
  - Moved dependency watches before async operations to comply with Riverpod rules
  - Stream properly recreates when selected date or unified data changes
- Daily OS Timer Updates: Added error handling when refetching data after timer stops
  - Errors during refetch are now logged instead of being silently swallowed
  - Matches error handling pattern used elsewhere in the controller

## [0.9.833] - 2026-01-30
### Added
- Voice Task Priority: Set task priority via voice during audio recordings
  - Say "priority P1", "this is urgent", or "low priority" to set task priority
  - AI maps spoken terms to priority levels: urgent/critical→P0, high/important→P1, medium/normal→P2, low/minor→P3
  - Only sets priority when not already explicitly set, preserving manual edits
  - Follows the same pattern as voice-controlled time estimates and due dates

## [0.9.832] - 2026-01-30
### Added
- Daily OS Timeline: Double-tap planned blocks to edit start/end times
  - More intuitive alternative to the existing long-press gesture
  - Opens the same edit modal for adjusting time range, category, and notes

## [0.9.831] - 2026-01-29
### Added
- Daily OS Smart Timeline Folding: Timeline now intelligently compresses inactive periods
  - Gaps larger than 4 hours between entry clusters are automatically folded
  - Compressed regions display at 8px per hour (vs 40px normal) with a zigzag edge pattern
  - Tap any compressed region to expand it to full height
  - Hours before 6 AM and after 10 PM are folded by default when no entries exist
  - ±1 hour buffer around each entry keeps context visible
  - Dramatically reduces vertical scrolling on days with sparse activity

## [0.9.830] - 2026-01-29
### Fixed
- Daily OS Time Calculation: Overlapping time entries within the same category no longer double-count
  - A 1.5h "Gym Trip" containing a 45m "Fitness Entry" now correctly reports 1.5h total (not 2.25h)
  - Uses time range union algorithm to calculate actual time coverage without overlap inflation
  - Applies to all budget progress calculations and time summaries

### Changed
- Daily OS Timeline: Same-category entries that fully contain another now nest visually
  - Child entries (e.g., the workout) render inset inside their parent block (e.g., the gym trip)
  - Reduces visual clutter by not using separate lanes for related entries
  - Different-category entries still display in separate lanes when overlapping

## [0.9.829] - 2026-01-29
### Added
- Daily OS Priority Indicators: Tasks now display priority badges (P0, P1, P3) styled like Linear
  - Compact color-coded badges: red for P0 (Urgent), orange for P1 (High), gray for P3 (Low)
  - P2 (Medium) badges are hidden to reduce visual noise since it's the default priority
  - Priority badges appear in both list and grid views

### Changed
- Daily OS Future Date Filtering: Viewing future dates now shows only tasks due on that specific day
  - Overdue tasks no longer pollute future day planning views
  - Today's view continues to show both due-today and overdue tasks for review/rescheduling
- Daily OS Priority Sorting: Tasks without tracked time are now sorted by priority first
  - Sort order: time spent (desc) → priority (P0→P1→P2→P3) → urgency → alphabetical
- Daily OS Timeline: Entry heights now reflect actual duration based on calendar scaling
  - Removed 20dp minimum height constraint from planned and actual blocks
  - Very short entries appear as thin colored lines proportional to their duration

## [0.9.828] - 2026-01-28
### Added
- Daily OS Due Task Visibility: Tasks due today or overdue now appear in time budget cards
  - Due tasks show even without tracked time, ensuring nothing falls through the cracks
  - Visual badges indicate urgency: red "Overdue" / "Late" and orange "Due today" / "Due"
  - Categories with due tasks but no planned budget show a warning banner
  - Intelligent deduplication: tasks with both tracked time and due dates merge properly
  - Smart sorting: tasks with time first (by duration), then due tasks, then alphabetical

### Changed
- Task view mode preference (list/grid) now persists per category
  - Stored in settings database, survives app restarts
  - Default changed from grid to list view for better readability

## [0.9.827] - 2026-01-27
### Added
- Daily OS Time Budgets: Task visualization with time tracking
  - Shows tasks that contributed time to each budget category
  - Displays per-task time spent and completion status (checkmark for tasks completed today)
  - Switchable list/grid view with toggle button
  - Grid view shows task thumbnails (cover art) with time badge and title overlay
  - List view shows compact rows with status indicator, title, and time
  - Collapsible task section with header showing task count and total time
  - Tasks sorted by time spent (descending), zero-time completed tasks at end

## [0.9.826] - 2026-01-27
### Added
- Daily OS Timeline: Overlapping entries now display in separate lanes
  - Uses greedy lane assignment algorithm to prevent visual overlap
  - Entries that don't overlap share the same lane (full width)
  - Overlapping entries are placed in adjacent lanes with equal widths
  - Small gap between lanes for visual separation

## [0.9.825] - 2026-01-27
### Changed
- Daily OS Architecture: Unified data controller for consistent real-time updates
  - Consolidated day plan, timeline data, and budget progress into single atomic state
  - Uses `ref.keepAlive()` + manual `StreamSubscription` to prevent Riverpod 3's automatic pausing
  - All UI components (timeline, budget progress bars, summary) now update together
  - Fixes auto-update failure when time entries are created or synced

### Removed
- Deprecated controllers: `TimelineDataController` and `TimeBudgetProgressController` classes
  - Data types (`TimelineSlot`, `TimeBudgetProgress`, etc.) preserved in existing files
  - All functionality now handled by `UnifiedDailyOsDataController`

## [0.9.824] - 2026-01-27
### Fixed
- Day Plan Timeline: Fixed crash when entries cross midnight (e.g., 23:00 to 01:00 next day)
  - Entries ending after midnight are now correctly treated as ending at 24:00 for display purposes
  - Added defensive bounds checking to prevent RangeError in List.generate
  - Resolves blank/grey screen issue on days with late-night or overnight entries

## [0.9.823] - 2026-01-24 (WIP)
### Added
- Daily Operating System: New time management feature for planning and tracking your day (WIP)

## [0.9.822] - 2026-01-24
### Fixed
- Task Time Tracking: Audio recording duration no longer counts toward time spent
  - Prevents double-counting when recording meetings (e.g., 1-hour recording + 1-hour time entry)
  - Only actual logged work entries contribute to task progress calculations

### Changed
- Added missing translations to German, Spanish, French, and Romanian localization files

## [0.9.821] - 2026-01-24
### Added
- OpenAI Onboarding FTUE: First-time user experience for OpenAI providers with one-click setup
  - Auto-creates 4 models: GPT-5.2 (reasoning), GPT-5 Nano (flash), GPT-4o Transcribe (audio), GPT Image 1.5 (image)
  - Configures 9 optimized prompts with appropriate model assignments
  - Creates a test category with all prompts enabled and auto-selection configured
  - Follows the same streamlined pattern as Gemini FTUE

### Changed
- Audio format handling simplified: M4A files now sent as-is labeled as mp3 for most providers
  - Only Mistral requires actual WAV conversion
  - Reduces processing overhead for OpenAI and Gemini transcription

## [0.9.820] - 2026-01-23
### Changed
- Upgraded dependencies

## [0.9.819] - 2026-01-23
### Changed
- Code Modularity Refactor: Extracted focused services from large modules for better testability and maintainability
  - `MetadataService`: Handles metadata creation with vector clock integration (from PersistenceLogic)
  - `GeolocationService`: Manages geolocation addition with race condition prevention (from PersistenceLogic)
  - `ExifDataExtractor`: Pure functions for EXIF timestamp and GPS coordinate extraction (from image_import)
  - `AudioMetadataExtractor`: Audio file metadata parsing and duration extraction via MediaKit (from image_import)
  - Media import separation: `audio_import.dart`, `media_import.dart`, and `image_import.dart` now have single responsibilities

## [0.9.818] - 2026-01-19
### Changed
- Voxtral Token Streaming: Upgraded from chunk-level to true token-by-token streaming
  - Text now appears progressively as it's generated, not waiting for full chunks
  - Tokens batched in groups of 6 for smooth display without excessive overhead
  - Configurable via Settings → Flags → "Enable AI streaming responses"
  - Non-streaming mode available for ~20% faster processing when progress display isn't needed

## [0.9.817] - 2026-01-18
### Added
- Mistral Cloud Provider: New cloud transcription option using Mistral's Voxtral API
  - Supports the `voxtral-small-2507` model for high-accuracy cloud transcription
  - Automatic audio format conversion from M4A to WAV (8kHz mono) for API compatibility
  - Uses FFmpegKit on iOS/Android/macOS, system FFmpeg on Linux/Windows
  - Auto-creates the Voxtral model when adding a Mistral provider

### Changed
- Audio Transcription Prompts: Improved context handling to prevent transcript bleed
  - Now uses task summary instead of full task JSON for cleaner context
  - Added explicit instructions that context is for terminology only, not to be included in output
  - Transcriptions now include paragraph breaks on small pauses or topic changes

## [0.9.816] - 2026-01-18
### Changed
- Voxtral Streaming Transcription: Audio transcription now streams progressively as each 60-second chunk completes
  - Each chunk's transcription is sent as an SSE event, providing real-time visual feedback
  - No more waiting for the entire audio to process before seeing results
  - Particularly useful for longer recordings (2+ minutes) where chunk-level progress is meaningful
- AI Streaming Enabled by Default: The `enableAiStreamingFlag` now defaults to `true` for new installations
  - Streaming responses provide better visual feedback during AI inference
  - Existing users can enable in Settings → Flags → "Enable AI streaming responses"

## [0.9.815] - 2026-01-16
### Added
- Voxtral Local Transcription: New local AI transcription service using Mistral's Voxtral model
  - Supports up to 30 minutes of audio transcription (vs 5 minutes for Gemma 3N)
  - 9 languages with automatic detection (English, Spanish, French, Portuguese, Hindi, German, Dutch, Italian, Arabic)
  - Context-aware transcription with speech dictionary support for improved accuracy
  - Two model options: Voxtral Mini 3B (~9.5GB VRAM) and Voxtral Small 24B (~55GB VRAM)
  - Runs locally on Apple Silicon (MPS) or NVIDIA GPUs (CUDA)
  - OpenAI-compatible API with full Flutter integration
  - New Python service at `services/voxtral-local/` on port 11344

## [0.9.814] - 2026-01-12
### Fixed
- Gemini Setup Dialog Reset: Fixed reset not working properly
  - Migrated storage from SharedPreferences to SettingsDb (SQLite) for reliability
  - Reset now takes effect immediately without requiring app restart
  - Maintenance page now properly invalidates the provider state

### Changed
- Localized the Gemini setup dialog reset strings in maintenance settings

## [0.9.813] - 2026-01-12
### Changed
- What's New Modal: Added "Done" button on the last page for clearer completion
  - "Skip" button hidden on last page, replaced with "Done" on the right
  - Button labels now use localization (l10n) for proper internationalization
- Cover Art Display: Reverted to `BoxFit.cover` for better mobile display

### Fixed
- Gemini Setup Dialogs: Fixed dialogs disappearing when resizing the app window
  - Added `useRootNavigator: true` to ensure dialogs survive widget tree rebuilds
  - Affects both the Gemini setup prompt modal and FTUE setup dialog

## [0.9.812] - 2026-01-12
### Fixed
- Task Estimate Field: Fixed estimate field not appearing on Linux (and fresh installs)
  - The estimate chip was incorrectly hidden when no labels were defined in the app
  - Now the estimate and "Add Label" controls always appear, regardless of label state

## [0.9.811] - 2026-01-11
### Changed
- Gemini FTUE Streamlined: Reduced default prompts from 18 to 9 with optimized model assignments
  - Gemini Pro: Checklists, Coding Prompts, Image Prompts (complex reasoning tasks)
  - Gemini Flash: Audio Transcription, Task Summary, Image Analysis (fast processing)
  - Nano Banana Pro: Cover Art generation (with reasoning mode enabled for reliable image output)
- Gemini Setup Modal: Now dismissible by tapping outside (temporary skip)
  - Tapping outside closes the modal but doesn't permanently dismiss it
  - Modal will reappear on next app start, allowing users to set up later
  - "Don't Show Again" button still permanently dismisses the prompt

## [0.9.810] - 2026-01-11
### Fixed
- Flatpak: Fixed keyring access error by adding D-Bus permission for org.freedesktop.secrets
- Flatpak: Fixed cursor theme warning by exposing host cursor theme paths via XCURSOR_PATH
- Flatpak: Fixed fontconfig error by removing invalid FONTCONFIG_PATH/FONTCONFIG_FILE overrides from wrapper script
- Flatpak: Fixed application icon warning by adding Flatpak-specific icon path to the icon search paths

## [0.9.809] - 2026-01-11
### Fixed
- Cover Art Display: Fixed image cropping on mobile devices where sides were cut off
  - Changed from BoxFit.cover to BoxFit.fitWidth with top alignment
  - Ensures full 16:9 cover art is visible without side cropping
- Cover Art Set/Unset: Fixed cover art changes not persisting after database sync
  - Vector clock counter could fall behind synced data, causing updates to be rejected
  - Added auto-catch-up logic to detect stale counters and recover automatically

## [0.9.808] - 2026-01-11
### Added
- Voice-Controlled Task Properties: Set time estimates and due dates via voice during audio recordings
  - `update_task_estimate`: Converts natural language durations ("2 hours", "half a day") to task estimates
  - `update_task_due_date`: Resolves relative dates ("Friday", "next week") to absolute due dates
  - Current date injected into AI prompt for accurate relative date resolution
  - Only sets values when not already set (preserves manual edits)
  - Treats zero-duration estimates as "not set" for intuitive behavior

## [0.9.807] - 2026-01-10
### Added
- Gemini Quick Start: Automatic setup prompt for new users without AI providers configured
  - Modal appears after What's New is dismissed (no overlapping dialogs)
  - One-click Gemini setup with pre-configured models and prompts
  - Explains available AI features: audio transcription, image analysis, smart checklists, task summaries
  - "Don't Show Again" option persists dismissal permanently
  - Notes that other providers like Ollama for local inference are available in Settings > AI

## [0.9.806] - 2026-01-10
### Changed
- Upgraded to Flutter 3.38.6

## [0.9.805] - 2026-01-09
### Added
- What's New Modal: Editorial magazine-style release notes viewer
  - 21:9 hero banner images with glassmorphism version badge
  - Multi-release navigation with animated indicator dots
  - Version filtering: only shows releases matching or older than installed app version
  - Smart "seen" tracking: only marks releases you actually viewed as seen
  - Image precaching for smooth page transitions (banners + markdown images)
  - "Skip" button to dismiss all remaining releases at once
  - "View past releases" option in empty state to review previous updates
  - Responsive design: bottom sheet on mobile, centered dialog on desktop
  - Markdown content support with images resolved from remote content repository

## [0.9.804] - 2026-01-08
### Added
- Linked Tasks Section: New dedicated UI section for viewing and managing task-to-task links
  - Displays bidirectional links with directional indicators (↳ LINKED FROM, ↗ LINKED TO)
  - Minimal, Linear-style text links with status circles (open/completed)
  - "Link existing task..." modal with searchable task list (FTS5-powered)
  - "Create new linked task..." creates a subtask inheriting current task's category
  - "Manage links..." mode shows unlink buttons for each linked task
  - Tasks filtered out from generic "Linked Entries" section to avoid duplication
  - Location: Between AI Task Summary and Checklists sections in task details

## [0.9.803] - 2026-01-08
### Fixed
- Calendar Auto-Refresh: Fixed calendar not updating when returning from creating a time recording
  - Improved `onVisibilityChanged` to track visibility transitions (invisible → visible)
  - Uses `ref.invalidateSelf()` on transition instead of direct fetch to ensure full provider rebuild
  - Added missing `ref.mounted` guard to `DayViewController.onVisibilityChanged`
  - More efficient than the removed `onResume` approach (no CPU overhead when staying on page)

## [0.9.802] - 2026-01-07
### Changed
- Scroll Performance Optimizations: Significant improvements to reduce jank during scrolling
  - Added `cacheExtent` to key scrollable views (Entry Details: 4000px, Tasks List: 1500px)
  - Labels Modal converted to sliver-based architecture with `SliverList.builder` for lazy loading
  - Added `RepaintBoundary` isolation for task cards, linked entries, and checklist items
  - Fixed memory leaks in EditorWidget and TextViewerWidget (ScrollController/FocusNode now properly managed)
  - These optimizations target smooth 60/120fps scrolling, especially for tasks with many checklist items

### Fixed
- High CPU Usage on Calendar Page (#2578): Removed `ref.onResume(() => ref.invalidateSelf())` from calendar controllers
  - The pattern caused an infinite rebuild loop (160%+ CPU when idle)
  - Root cause: `invalidateSelf` on resume triggered rebuild → pause → resume → invalidateSelf cycle
  - Calendar updates are already handled by existing `onVisibilityChanged()` and stream listeners

## [0.9.801] - 2026-01-06
### Changed
- Entry Actions Menu Redesign: Restyled to match the FAB addition menu with Nano Banana Pro styling
  - Unified list design with subtle horizontal dividers (removed card-based layout)
  - Clean icons without gradient containers
  - Consistent with FAB menu visual language
  - Conditional item visibility handled at parent level to prevent double dividers

## [0.9.800] - 2026-01-06
### Fixed
- Calendar View Stale Data: Fixed calendar not updating after adding or modifying entries
  - Root cause: Riverpod 3's auto-pause feature pauses providers when widgets are not visible
  - Added `ref.onResume()` callbacks to `DayViewController` and `TimeByCategoryController`
  - Providers now invalidate themselves when resuming, ensuring fresh data is fetched
  - Uses `Future.microtask()` to defer invalidation per Riverpod 3 lifecycle callback restrictions

## [0.9.799] - 2026-01-05
### Changed
- FAB Addition Menu Redesign: Modernized the add entry bottom sheet with Nano Banana Pro styling
  - Unified container with single dark background (removed separate card backgrounds)
  - Clean list items with white icons (removed rounded gradient containers)
  - Subtle horizontal dividers between menu items
  - Consistent icon, text, and plus (+) trailing icon layout
  - Edge-to-edge tap effects for better visual feedback

### Fixed
- OpenAI Compatible Provider: API Key field now visible when adding or editing providers (#2570)
  - Removed `genericOpenAi` from `noApiKeyRequired` set as most OpenAI-compatible endpoints require Bearer Token authentication
  - Authentication section now displays for OpenAI Compatible provider type

## [0.9.798] - 2026-01-04
### Added
- AI Cover Art Generation: Generate task cover art directly from audio descriptions using Gemini's image generation model (Nano Banana Pro)
  - Trigger from audio entry action menu when linked to a task
  - Full task context included in prompt (title, checklists, labels, linked task summaries)
  - `{{current_task_summary}}` placeholder provides learnings and annoyances for visual metaphors
  - Review modal with accept, edit prompt, and regenerate options
  - Accepted images automatically set as task cover art

### Changed
- Cover Art Display: Updated from 2:1 to 16:9 aspect ratio for consistency with generated images
  - Task expandable app bar now uses 16:9 aspect ratio
  - Cover art background displays at full resolution (removed cacheHeight constraint)
- Image Generation: Uses 2K resolution for Full HD quality output (1920x1080 at 16:9)

## [0.9.797] - 2026-01-04
### Fixed
- Cross-Checklist Drag-and-Drop: Restored ability to move items between checklists
  - Fixed regression from checklist redesign PR where `ReorderableDragStartListener` blocked `super_drag_and_drop` gestures
  - Moved `DropRegion` to wrap entire checklist card for proper drop target area
  - Added item-level `DropRegion` for position-aware drops enabling within-list reordering
  - Unified drag system: long-press anywhere on item initiates drag for both reordering and cross-checklist moves

## [0.9.796] - 2026-01-03
### Changed
- Nano Banana Checklist Redesign: Major UI rewrite with card-based architecture
  - Modular widget structure: extracted `ChecklistCardHeader`, `ChecklistCardBody`, `ChecklistFilterTabs` into separate files
  - Animated chevron rotation (90°) between expanded/collapsed states
  - Filter tabs with underline indicator (replaced SegmentedButton)
  - Progress ring hidden when empty (expanded mode), always shown (collapsed)
  - Add input moved to bottom of checklist body
  - Click-to-edit title functionality
  - Three display modes: expanded, collapsed, sorting
- Comprehensive test coverage for all extracted components (32 new tests)

## [0.9.795] - 2026-01-03
### Changed
- Image Card Thumbnails: Now display as uniform squares with center crop
  - Portrait images cropped from vertical center
  - Landscape images cropped from horizontal center
  - Consistent 160x160 thumbnail size for visual uniformity
- Updated Gemini AI models to latest versions

## [0.9.794] - 2026-01-02
### Changed
- Due Date Visibility Refinements: Improved UX for completed and rejected tasks
  - Due dates are now hidden on task cards for completed and rejected tasks
  - Due dates in entry details view show grayed-out styling for completed/rejected tasks (no red/orange urgency colors)
- Updated README and Flatpak metainfo to reference the launched "Meet Lotti" blog series

### Added
- Tests for due date visibility behavior based on task status

## [0.9.793] - 2025-12-31
### Added
- Visual Mnemonics: Tasks can now have cover art images for memorable visual representation
  - Set any linked image as a task's cover art via the image action menu
  - Cover art thumbnails displayed on task cards (toggle in filter modal)
  - Cinematic 2:1 collapsible SliverAppBar with cover art in task details
  - Glass effect icon containers for overlay buttons on cover art
  - Horizontal crop adjustment for cover art positioning

### Changed
- Task detail app bar adapts between compact (no cover) and expandable (with cover) modes
- Added comprehensive test coverage for cover art widgets

## [0.9.792] - 2025-12-31
### Changed
- Upgraded to Riverpod 3.x with comprehensive codebase migration
  - Updated all providers to use new Riverpod 3 syntax and patterns
  - Added `ref.mounted` checks after async gaps to prevent disposed ref access
  - Converted family providers to use constructor-based parameter passing
  - Updated notifier classes from `AutoDisposeFamilyAsyncNotifier` to `AsyncNotifier` pattern
  - Changed callbacks in widgets to use closures for fresh notifier instances at invocation time
  - Made `MatrixStats` class immutable with `@immutable` annotation and `final` fields
  - Added `ref.onDispose` cleanup handlers for resource management

### Fixed
- Fixed "Cannot use Ref after disposed" errors in autoDispose providers
- Fixed checklist item resolution to properly await async futures instead of reading sync values
- Fixed provider override conflicts in tests by detecting duplicate overrides

## [0.9.790] - 2025-12-31
### Added
- Task Due Dates: Tasks now support due date assignment and display
  - Due date picker in task details header with Cancel/Clear/Done actions
  - Color-coded status indicators: red for overdue, orange for due today
  - Due date display on task cards with toggle in filter modal
  - Tappable due date text toggles between absolute ("Dec 24, 2025") and relative ("Due in 5 days") formats
  - Proper localization with ICU plural support for English, Spanish, and French
  - Shared `getDueDateStatus` utility for consistent status calculations
  - Uses `clock` package for testable time-dependent logic

### Changed
- Task card layout: creation date on LEFT, due date on RIGHT
- Task details header: improved styling with restyled filter modal
- Added comprehensive test coverage for due date widgets and utilities

## [0.9.788] - 2025-12-30
### Changed
- Migrated journal/tasks page state management from Bloc to Riverpod
  - Replaced `JournalPageCubit` with `JournalPageController` notifier using `@Riverpod(keepAlive: true)`
  - Uses family provider pattern with `showTasks` boolean for journal vs tasks page state
  - Created `journalPageScopeProvider` for scoped access to `showTasks` value in widget tree
  - Updated `InfiniteJournalPage`, `JournalSliverAppBar`, filter widgets to use Riverpod
  - Fixed modal state sharing in `JournalFilterIcon` and `AiChatIcon` using `UncontrolledProviderScope`
  - Added comprehensive test coverage for controller, state, and widget interactions

## [0.9.787] - 2025-12-30
### Fixed
- Fixed habit settings page opening empty for existing habits
  - Changed `ref.watch()` to `ref.read()` for `habitByIdProvider` in controller build
  - Prevents controller rebuilds when stream data changes, preserving form state
  - Edit flow now loads cached habit data synchronously from `EditHabitPage`

## [0.9.786] - 2025-12-30
### Changed
- Migrated habits page state management from Bloc to Riverpod
  - Replaced `HabitsCubit` with `HabitsController` notifier using `@Riverpod(keepAlive: true)`
  - Created Freezed-based `HabitsState` with helper functions for chart calculations
  - Updated `HabitsTabPage`, `HabitsSliverAppBar`, `HabitStreaksCounter`, `HabitsFilter`,
    `HabitsSearchWidget`, and `HabitCompletionRateChart` to use Riverpod
  - Fixed TextEditingController lifecycle in search widget (proper init/dispose/sync)
  - Fixed chart touch handling to defer state modification via `addPostFrameCallback`
  - Added comprehensive test coverage for controller, state helpers, and widgets

## [0.9.785] - 2025-12-30
### Changed
- Migrated audio player state management from Bloc to Riverpod
  - Replaced `AudioPlayerCubit` with `AudioPlayerController` notifier
  - Uses `@Riverpod(keepAlive: true)` for app-wide audio state persistence
  - Updated `AudioPlayerWidget` to use Consumer pattern
  - Updated `RecorderController` to use ProviderContainer injection
  - Removed BlocProvider wrapper from app initialization

## [0.9.784] - 2025-12-30
### Changed
- Migrated habit settings state management from Bloc to Riverpod
  - Replaced `HabitSettingsCubit` with `HabitSettingsController` notifier
  - Uses family provider pattern with `habitId` as key for per-habit state management
  - Added `habitByIdProvider` for watching habit by ID from database
  - Added `habitDashboardsProvider` for dashboards in habit settings
  - Updated `HabitDetailsPage`, `CreateHabitPage`, `EditHabitPage` to use Riverpod
  - Updated category and dashboard selection widgets to use Riverpod providers

## [0.9.783] - 2025-12-30
### Changed
- Migrated theming state management from Bloc to Riverpod
  - Replaced `ThemingCubit` with `ThemingController` notifier and `enableTooltipsProvider`
  - Theme state now managed via `themingControllerProvider` with keepAlive for app-wide persistence
  - Moved theme definitions (`themes` map, `LightModeSurfaces`) to `lib/features/theming/model/`
  - Updated `MyBeamerApp` to use `ConsumerStatefulWidget` with Riverpod providers
  - Updated `ThemingPage` to use `ConsumerWidget` pattern

## [0.9.782] - 2025-12-30
### Changed
- Migrated sync outbox state management from Bloc to Riverpod
  - Replaced `OutboxCubit` with `outboxConnectionStateProvider` and `outboxPendingCountProvider`
  - Updated `OutboxBadgeIcon` to use Riverpod providers for consistency
  - Removed BlocProvider wrapper from app initialization
  - Moved `OutboxStatus` enum to new provider file

## [0.9.781] - 2025-12-29
### Added
- Task Sorting Options: Tasks can now be sorted by date (newest first) or by priority
  - New segmented button in task filter modal to toggle between sort modes
  - Priority sort (default): Orders by priority rank (P0→P1→P2→P3), then by date within same priority
  - Date sort: Orders by creation date descending, regardless of priority
  - Sort preference persists across sessions
- Creation Date Display: Optional creation date shown on task cards
  - Toggle in filter modal to show/hide creation date on task list cards
  - Date displayed in bottom-right corner with subtle styling (small font, low contrast)
  - Uses locale-aware date format (e.g., "Dec 29, 2024")
  - Preference persists across sessions

### Changed
- Improved accessibility for task filter toggle (now uses SwitchListTile)
- Optimized date display toggle to not trigger unnecessary query refreshes

## [0.9.780] - 2025-12-29
### Changed
- Migrated dashboard list state management from Bloc to Riverpod
  - Replaced `DashboardsPageCubit` with Riverpod providers for consistency with codebase
  - Dashboard filtering and sorting now uses `filteredSortedDashboardsProvider`
  - Category filter selection uses `selectedCategoryIdsProvider`
  - Improved sorting to be case-insensitive for better UX

## [0.9.779] - 2025-12-29
### Added
- Labels for All Entry Types: Labels can now be assigned to any journal entry, not just tasks
  - Labels display on journal list cards (alphabetically sorted, privacy-filtered)
  - Labels display in entry detail views with edit capability
  - New "Labels" action in the triple-dot menu for quick label assignment
  - Unified label selection modal with search, create, and apply functionality
  - Consistent UX across all entry types (text, audio, image, event entries)

### Changed
- Refactored label selection modal code into shared utility for better maintainability
  - Extracted `LabelSelectionModalUtils` for centralized modal handling
  - Fixed memory leak in label selector (proper disposal of controllers)
  - Apply button now correctly disables when no changes are pending

## [0.9.778] - 2025-12-28
### Added
- Twi Language Support: Added Twi (Akan) as a supported language for task summarization
  - Twi is spoken by approximately 9 million people, primarily in Ghana
  - Enables AI-generated task summaries in Twi
  - Includes Ghana flag in language selection UI

## [0.9.777] - 2025-12-28
### Added
- Image Prompt Generation: New AI response type for generating image prompts from task context
  - Transforms audio recording + task context into detailed prompts for AI image generators
  - Triggered from audio entries linked to tasks (same pattern as Coding Prompt)
  - Includes visual metaphor guidelines (debugging = bugs, progress = paths, etc.)
  - Style options: infographic, cartoon, artistic, photorealistic, retro, minimalist, isometric
  - Output format with Summary and Prompt sections for easy copy-paste
  - Designed for Midjourney, DALL-E 3, Stable Diffusion, Gemini Imagen
  - Uses GeneratedPromptCard UI with prominent copy button
  - Full localization support (EN, DE, ES, FR, RO)

## [0.9.776] - 2025-12-28
### Added
- Task Summary Goal Section: AI task summaries now include a succinct Goal section after the TLDR
  - Describes the desired outcome or essential purpose of the task (1-3 sentences)
  - Helps maintain focus on the "why" behind the work
  - Displayed in the expanded summary view alongside Achieved Results and Remaining Steps
- Entry Labels Support: Labels can now be assigned to all entry types, not just tasks
  - Labels display on journal list cards (alphabetically sorted, privacy-filtered)
  - Labels display in entry detail views with edit capability
  - New "Labels" action in the triple-dot menu for quick label assignment
  - Consistent Wolt-style modal UX for label selection across all entry types

## [0.9.775] - 2025-12-27
### Added
- Single-User Multi-Device Sync: New room discovery feature for simplified sync setup
  - Device B can now discover and join existing sync rooms without invitation from Device A
  - Room Discovery page shows potential sync rooms with confidence indicators
  - Rooms are evaluated based on encryption status, Lotti state markers, and message content
  - Smart navigation skips discovery when a room is already configured
  - Bounded concurrency (5 parallel evaluations) for faster discovery with many rooms
- Full localization support for room discovery (EN, DE, ES, FR, RO)

### Fixed
- QR scanner now restarts properly after invite failure, allowing retry without navigation

## [0.9.774] - 2025-12-26
### Added
- Calendar Privacy Filtering: Calendar view now respects category visibility settings from Tasks page
  - Selected categories display colored box with text (title and description)
  - Unselected categories display colored box only (text hidden for privacy)
  - Unassigned entries can be shown/hidden using the unassigned filter marker
  - Visibility state is shared with Tasks page via settings persistence

## [0.9.773] - 2025-12-25
### Changed
- Checklist Correction UX: Corrections now use a delayed-save pattern with cancel option
  - When editing a checklist item triggers a correction, a snackbar appears with a 5-second countdown
  - Users can tap "CANCEL" to discard the correction before it's saved
  - If the countdown completes without cancellation, the correction is saved to the database
  - Prevents accidental one-time fixes from being permanently saved as AI learning examples

## [0.9.772] - 2025-12-24
### Added
- AI Linked Task Context: AI prompts now include context from related tasks
  - `{{linked_tasks}}` placeholder provides parent/child task relationships
  - Includes task metadata (status, priority, time spent, labels) for each linked task
  - Includes latest AI summary for linked tasks (with GitHub/external link awareness)
  - Batched database queries avoid N+1 performance issues
  - Labels resolved via O(1) cache lookup

### Changed
- AI Repository: Decoupled prompt semantics from data construction
  - Note about web search for external links moved from repository to prompt builder
  - Repository now returns pure data; prompt builder adds contextual instructions

## [0.9.771] - 2025-12-23
### Added
- Task Summary Link Extraction: AI-generated task summaries now include a "Links" section
  - AI is instructed to scan log entries and extract unique URLs (http://, https://, etc.)
  - Generates succinct, descriptive titles for each link (e.g., "Linear: APP-123", "Lotti PR #456")
  - Formats as clickable Markdown links
  - Links section omitted when no URLs are found (prompt-driven, best-effort)

## [0.9.770] - 2025-12-23
### Changed
- Upgraded to Flutter 3.38.5 and updated dependencies
- Sync: Refactored `OutboxService.enqueueMessage()` for improved maintainability
  - Converted from if-else chains to Dart 3 pattern matching with exhaustive switch
  - Extracted `_enqueueSimple` shared helper to reduce code duplication across 7 simple message handlers
  - Extracted per-type handler methods (`_enqueueJournalEntity`, `_enqueueEntryLink`, etc.)
  - Added preparation methods (`_prepareJournalEntity`, `_prepareEntryLink`) for message pre-processing
  - Improved test coverage: 60 → 77 tests with edge case coverage for null values and error handling

### Fixed
- Tests: Fixed resource leak in OutboxService tests where auxiliary service instances were not disposed

## [0.9.768] - 2025-12-23
### Added
- Gemini Thinking Support: All Gemini 2.5+ models (including Flash) now support thinking/reasoning
  - Thoughts are displayed in the AI Response Summary Modal's "Thoughts" tab
  - Removed incorrect suppression of thinking for Flash models
- Usage Statistics: Track and display AI inference metrics
  - Input tokens, output tokens, and thoughts tokens from providers
  - Processing duration measurement in milliseconds
  - Statistics displayed in AI Response Summary Modal
- Conversation Manager: Added thought signature storage for future multi-turn function calling support

### Changed
- Standardized thinking block format from `<thinking>` to `<think>` tags for consistency across providers

## [0.9.765] - 2025-12-21
### Fixed
- Sync: Remove live-scan look-behind tail logic and the `enable_matrix_lookbehind_tail` flag so live scans always process strictly-after slices only.

## [0.9.764] - 2025-12-21
### Fixed
- Checklist Deletion: Fix persistent empty card after checklist deletion
  - When deleting a checklist, the checklist ID is now removed from the parent task's `checklistIds` list
  - Added defensive UI filtering to handle existing stale checklist references
  - Empty card containers no longer appear after checklist deletion

## [0.9.762] - 2025-12-19
### Fixed
- Sync Catch-Up: Prevent concurrent catch-up execution
  - Added `_forceRescanInFlight` guard to serialize concurrent `forceRescan()` calls
    (e.g., connectivity + startup handlers firing simultaneously)
  - Added `_catchUpInFlight` check in `forceRescan()` to skip catch-up when another
    is already running from `_runGuardedCatchUp()` or `_scheduleInitialCatchUpRetry()`
  - Fixes issue where catch-up from external triggers could run concurrently with
    internal retry-driven catch-ups, causing `processOrdered` timeout failures
  - `bypassCatchUpInFlightCheck` parameter allows internal callers like `_startCatchupNow()`
    to bypass the check when they've intentionally set the flag

## [0.9.761] - 2025-12-18
### Fixed
- Sync Catch-Up: Wait for SDK sync completion before running catch-up
  - All catch-up paths (startup, app resume, wake, reconnect) now wait up to
    30 seconds for the Matrix SDK to complete its `/sync` with the server
  - Fixes issue where catch-up after extended offline periods would only
    retrieve a few entries instead of the full backlog
  - If timeout occurs on slow networks, a follow-up catch-up automatically
    triggers when sync eventually completes
  - Tuning: `SyncTuning.catchupSyncWaitTimeout` (default 30s)

## [0.9.758] - 2025-12-18
### Fixed
- Sync Gap Detection: Prevent false positives during reconnection
  - Covered vector clocks now processed BEFORE gap detection, preventing
    intermediate counters from being incorrectly marked as missing
  - Live scan signals are deferred while catch-up is processing older events,
    ensuring in-order ingest and preventing newer events from triggering
    false gaps before older events are recorded

## [0.9.755] - 2025-12-16
### Added
- Nested AI Responses: Display generated prompts directly under audio entries
  - AI responses linked from audio entries now appear in an expandable section
  - Collapsible UI with smooth animation to show/hide nested responses
  - Swipe-to-delete with confirmation dialog for removing AI responses
  - Error feedback when deletion fails

## [0.9.754] - 2025-12-15
### Added
- Sync Backfill Improvements: EntryLink support and ghost entry resolution
  - EntryLink messages now tracked in sequence log alongside journal entities
  - New `SyncSequencePayloadType` enum distinguishes `journalEntity` vs `entryLink`
  - Ghost missing entry resolution: when different payload types share the same
    sequence counter, receiving one resolves the other (e.g., EntryLink at `(alice:5)`
    resolves a missing JournalEntity counter)
  - `populateFromEntryLinks` method populates sequence log from existing entry links
  - Extracted `SequenceLogPopulateProgress` widget for testable progress UI
  - Comprehensive test coverage for backfill response handler, sync event processor,
    sync database, and outbox service

## [0.9.752] - 2025-12-06
### Added
- Sync Backfill: Request missing journal entries from connected devices during sync
  - Automatically detects gaps in local journal entries based on sync status
  - Requests missing entries from peers to ensure complete synchronization
  - Integration tests verify backfill functionality

### Fixed
- Sync: Treat missing attachment fetches as retryable failures so markers do not advance past incomplete entries, serialize `forceRescan` with a completer to avoid overlapping runs, and include Matrix stream consumer instance IDs in sync logs to track concurrent pipelines.
- Sync: Avoid redundant descriptor catch-up retries by running catch-up only on pending changes, triggering retryNow only when new descriptors are discovered, and skipping stale descriptor errors when the local entry already supersedes the incoming vector clock.
- Sync: Skip no-op entry link updates so vector clocks only advance when link state changes.
- Sync: Preserve sequence log `createdAt` when resolving covered counters to avoid upsert validation errors.
- Sync: Wait for in-flight ordered processing to finish instead of timing out catch-up batches during long attachment downloads.
- Sync: Queue attachment downloads asynchronously (bounded concurrency) so ordered processing does not block on large media.
- Sync: Skip duplicate journal entity messages with the same vector clock to reduce redundant older-or-equal applies.
- Sync: Send descriptor JSON from a single snapshot so the message vector clock matches uploaded bytes, avoiding stale vector-clock retries.
- Sync: Mark superseded own counters as unresolvable during backfill so requested entries can clear.
- Sync: Always include the current vector clock in `coveredVectorClocks` for journal entries and entry links while ignoring the current clock for pre-marking to preserve gap detection.
- Sync: Fill missing `originatingHostId` on outgoing journal entities and entry links so sequence logs always update.
- Outbox: Respect retry backoff across triggers to prevent rapid retry storms under flaky networks.
- Tests: Stabilize Matrix stream consumer signal coverage around live scan timing and stubs.
### Changed
- Sync: Split the Matrix stream consumer into catch-up, live-scan, processing, and signal components, and split the pipeline tests into smaller files for maintainability.
### Added
- Automatic Image Analysis: Images added to tasks are now analyzed automatically
  - When dropping, pasting, or importing images to a task with image analysis enabled, analysis runs in background
  - Uses category's `automaticPrompts[imageAnalysis]` configuration
  - Fire-and-forget pattern ensures image import is never blocked
  - Platform-aware: automatically selects available prompts for current platform
  - New `AutomaticImageAnalysisTrigger` helper class with `onCreated` callback in `JournalRepository.createImageEntry()`
  - Tests: 10 unit tests with 100% coverage
  - See: `docs/implementation_plans/2025-12-01_automatic_image_analysis_and_task_summary_triggers.md`
- Smart Task Summary Triggers: Simplified and unified task summary creation
  - First summary created immediately when meaningful content is added (if auto-summary enabled)
  - Subsequent updates use existing 5-minute countdown mechanism
  - Triggers on: image analysis completion, audio transcription completion, manual text save (non-empty)
  - Avoids "lame" first summaries by requiring meaningful content before triggering
  - New `SmartTaskSummaryTrigger` helper class with dual-path logic
  - Integrated into `UnifiedAiInferenceRepository._handlePostProcessing()` and `EntryController.save()`
  - Tests: 9 unit tests with 100% coverage + 5 entry controller tests
  - See: `docs/implementation_plans/2025-12-01_automatic_image_analysis_and_task_summary_triggers.md`
- Checklist Correction Examples: Learn from manual corrections to improve AI accuracy
  - When users manually correct a checklist item title, the before/after pair is captured
  - Examples are stored per-category and injected into AI prompts via `{{correction_examples}}`
  - Supports both checklist update prompts and audio transcription prompts
  - New `CategoryCorrectionExamples` widget in category settings with swipe-to-delete
  - Smart filtering: ignores no-change, trivial case-only, and duplicate corrections
  - Warning banner when approaching token budget (400+ examples, max 500 injected)
  - Auto-dismissing snackbar confirms successful correction capture
  - Fire-and-forget capture via `unawaited()` for zero UI latency
  - Syncs across devices via existing category sync infrastructure
  - See: `docs/implementation_plans/2025-11-30_checklist_item_correction_examples.md`
- Speech Dictionary per Category: Improve transcription accuracy with domain-specific terms
  - Categories can now store a speech dictionary of correct spellings for names, places, and technical terms
  - Dictionary terms are injected into AI transcription prompts via `{{speech_dictionary}}` placeholder
  - New `CategorySpeechDictionary` widget in category settings (semicolon-separated text field)
  - Context menu in QuillEditor: select corrected text and "Add to Speech Dictionary"
  - Works for tasks, linked audio entries, and linked image entries
  - `SpeechDictionaryService` handles term addition with validation (max 50 chars, trimming)
  - Terms sync across devices via existing category sync infrastructure
  - Tests: 22 service tests, 16 widget tests, 14 prompt builder tests
  - See: `docs/implementation_plans/2025-11-30_speech_dictionary_per_category.md`
- AI Task Summary: Scheduled refresh with countdown UX
  - Changed from 500ms debounce to 5-minute scheduled delay
  - UI shows countdown "Summary in 4:32" when refresh is scheduled
  - Cancel button (✕) to stop scheduled refresh
  - Trigger Now button (▶) to bypass countdown and generate immediately
  - Additional checklist changes batch into existing countdown (no timer reset)
  - Reduces API costs while actively working on a task
  - Implementation: `DirectTaskSummaryRefreshController` returns `ScheduledRefreshState`
  - Efficient countdown updates via `StreamBuilder` in `_HeaderText` widget
  - Tests: 15 unit tests + 7 widget tests for scheduled refresh behavior
- AI – Checklist Updates improvements
  - Current Entry hint: recording modal and entry-level AI popup now pass the focused entry ID so prompts prioritize the user-edited transcript/text before falling back to the full task log.
  - Deleted items context: prompt builder injects every soft-deleted checklist title (with deletion timestamps) so the LLM can avoid recreating them.
  - `update_checklist_items` tool: unified update path for existing checklist items, supporting:
    - Mark items as checked/unchecked (e.g., "I did X" → item marked complete)
    - Fix transcription errors in titles (e.g., "mac OS" → "macOS", "i Phone" → "iPhone")
    - Combined updates: status and title correction in a single call
    - Semantic matching: AI matches user references to items by meaning, not exact text
  - Popup parity: running Checklist Updates from a linked audio/image entry now threads that entry as `linkedEntityId`; task-level runs keep the parameter unset for whole-task analysis.
- Checklists: Ergonomics improvements
  - TitleTextField: Cmd/Ctrl+S saves; add-item field retains focus after save for rapid entry
  - Filter: default “Open only” with header toggle and completed count (N/M done)
  - Accessibility: keyboard toggle (Cmd+Shift+H / Ctrl+H) + screen reader announcements
  - Persistence: per‑checklist filter mode is remembered
  - Empty state: “All items completed!” message when open‑only has no items

- Checklists: Completion feedback animation
  - Checking off an item now plays a subtle green-tinted border/glow “fanfare”.
  - In “Open only” view, completed items fade out and collapse over a short duration instead of disappearing instantly.
  - In “All” view, items keep the highlight but remain visible so users can still see what was just completed.

- Journal/Tasks: Active timer highlight — linked entries that match the running timer now render with a persistent red glow for quick visual identification.
- Journal/Tasks: Temporary scroll highlight — after auto-scrolling to a linked entry, the target briefly glows to confirm focus.
- AI label assignment: Category-scoped label suggestions (Phase 1 guardrails)
  - AI only suggests labels applicable to the task's category (global ∪ scoped labels)
  - Prompt includes category-filtered labels; ingestion enforces category scope
  - Telemetry tracks `out_of_scope` skip reason with full structured payload
  - TaskContext parameter reduces DB lookups when category is already available
- Tasks: Priority (P0–P3) end-to-end support
  - New TaskPriority field with compact P0–P3 chips and colors
  - Header picker + detail chip; selection modal uses the chip visuals
  - Task list filtering by priorities and ordering by priority rank, then date
  - Persistence: priority filter stored per-tab with other task filters
  - Migration v29: adds `task_priority` (TEXT) and `task_priority_rank` (INTEGER)
    with backfill to P2/2 for legacy tasks and updated composite index
  - i18n: English keys for labels, picker title and descriptions
  - Tests: database ordering/filtering, UI wrappers, filter UX
- Checklists (Open-only filter): Newly completed items no longer disappear instantly or flicker when toggling between “All” and “Open only”; rows now remain visible briefly with a completion animation before smoothly fading out.

### Fixed
- **Sync: Entry link atomicity** — Calendar entries no longer appear grey due to missing category information
  - Entry links now embedded within journal entity sync messages, ensuring atomic processing
  - Links only processed after successful entry persistence, preventing orphaned references
  - Backward compatible: standalone entry link messages still supported for link updates
  - Reduces sync message count from N+1 to 1 per entry with links
  - Comprehensive logging: `enqueueMessage.attachedLinks` and `apply.entryLink.embedded` events
  - Implementation: `lib/features/sync/model/sync_message.dart`, `lib/features/sync/outbox/outbox_service.dart`, `lib/features/sync/matrix/sync_event_processor.dart`
  - Tests: 3 new tests in `test/features/sync/outbox/outbox_service_test.dart`
  - See: `docs/implementation_plans/2025-11-16_entry_link_sync_atomicity.md`
- Tasks page: Active label filters are now visible below the search header (no longer clipped in the app bar).
- AI label assignment: Prevented out-of-category labels from being assigned by AI
- Task label selector: Now shows currently assigned out-of-scope labels to allow unassigning
  - List is strictly A–Z (case-insensitive); selection does not change ordering
  - Out-of-category assigned labels are included with an "Out of category" note when applicable
  - Solves issue where out-of-scope labels were hidden and couldn't be removed
- Label creation UX: "Create label" option now available with substring matches
  - Previously hidden when typing "CI" while "dependencies" existed (substring match)
  - Now shows "Create 'CI' label" button below filtered results when no exact match exists
  - Only hides create option when exact match (case-insensitive) is found
  - Improves discoverability for short label names that appear as substrings

- Sync maintenance now supports Labels in the manual definition sync flow:
  - Sync page → Sync Entities modal includes a "Labels" checkbox alongside Tags, Measurables,
    Categories, Dashboards, Habits, and AI Settings.
  - Each step reports per-step progress and totals; selections can be run together.
- tests(labels/ai):
  - Max-volume labels selection (500+) with performance and ordering checks
  - Prompt injection protection for label names
  - Conversation retry and interruption coverage for `assign_task_labels`
  - TaskLabelsWrapper toast + undo + rapid assignment behavior
  - LabelValidator validity/concurrency tests
  - Summary note test when labels exceed the prompt cap
- AI label assignment with function-calling (see PR #2365):
  - Prompt label injection (capped to 100, usage + alphabetical) with optional private filtering.
  - `assign_task_labels` tool (add-only) with max 5 labels per call.
  - Shared rate limiter (5-minute window) and shadow mode.
 - Flatpak packaging: install desktop and AppStream metadata from the upstream repo and use a `type: script` wrapper instead of inline `cat` heredocs in the manifest.
  - User feedback: SnackBar in Task Details listing assigned labels with Undo to remove them.
  - Event stream for UI notifications and comprehensive unit/feature tests.
- Settings header widget tests now cover multiple text scale factors (1.0, 1.2, 1.5, 2.0) and common screen widths to guard layout across devices.
- Label chips now surface tooltips/long-press descriptions, Task label sheets show inline "Create
  label" CTAs, and the journal header includes a quick label filter row for active selections.
- Labels settings list displays usage counts sourced from a new `watchLabelUsageCounts` stream plus
  widget coverage for the editor sheet, list page, assignment sheet/wrapper, and filter chips.
- Added integration (`label_workflow_test.dart`), accessibility, repository edge-case, and
  performance tests (1k+ tasks + reconciliation benchmarks) for the labels system.
- AI prompt selection modal now visually highlights default automatic prompts with gold accent (border and icon background).
- Platform-aware AI prompt filtering automatically hides local-only models (Whisper, Ollama, Gemini 3N) on mobile platforms.
- Fallback logic ensures default automatic prompts gracefully switch to available alternatives when local-only models are filtered on mobile.
- Comprehensive test coverage added for platform filtering, isDefault prompt highlighting, and ModalCard border/animation behavior.
- Outbox: Pause processing while logged out and surface a one-time red toast ("Sync is not logged in") when sync is enabled but not authenticated. Prevents wasted retries and clarifies state to the user.
- Labels: Applicable categories (scoped labels)
  - New optional `applicableCategoryIds` on `LabelDefinition` (backward compatible JSON only)
  - Reactive provider for category-scoped availability using cache + streams
  - EntitiesCacheService builds `global` and per-category buckets with pruning on category changes
  - Label editor adds an "Applicable categories" section (chips + add/remove)
  - Task label picker filters to union of global + current category
  - Repository validates category IDs, de-dupes and sorts by category name for stable diffs
  - Tests: service unit tests and widget tests updated; i18n keys added with missing translations noted

### Changed
- AI: Task-related prompts default to non-streaming, with a new `enable_ai_streaming` flag controlling streaming for those actions (chat remains streaming).
- Flatpak: AppStream metadata version/date now come directly from the checked-in `com.matthiasn.lotti.metainfo.xml`; the manifest tool no longer rewrites them during Flathub prep.
- Flatpak: Fail fast when flatpak-flutter or cargo source generation fails (no fallback paths), keep tool PATHs via append-path (including `/usr/bin:/bin`), and keep downloaded Cargo.lock files only in the working directory (not in submission artifacts) for reproducible builds.
- Journal/Tasks: Refactored scroll-to-entry and highlight logic into `HighlightScrollMixin` with configurable durations and a small retry backoff; `LinkedEntriesWithTimer` scopes rebuilds to the linked entries section only. Focus intent is cleared early (next frame) for responsiveness and also on success/terminal failure for robustness.
- Tasks UI: Checklist item vertical spacing reduced (outer padding 2px; content padding vertical 2px) for a more compact list.
- UI/Tasks: Redesigned the active label filters header below the search bar
  - Compact card-style container (rounded, `surfaceContainerHighest`) with smooth `AnimatedSize`
  - Header shows a subtle filter icon and “Active label filters (n)”
  - Clear action uses compact `TextButton.icon` (smaller text) and chips use compact density
  - Renders only when filters are active; no empty container state
- Sync (Outbox): enforce a strict idle window (3s) with no forced 2s deadline; pause drains mid-burst when activity resumes and reschedule via the standard retry delay.
- Sync (Matrix): Client stream is now signal-driven and always triggers a catch-up via
  `forceRescan(includeCatchUp=true)` with an in-flight guard to prevent overlaps. Timeline callbacks
  continue to schedule debounced live scans and fall back to `forceRescan()` on scheduling errors.
- Sync (Matrix): Documentation refreshed to reflect signal-driven ingestion and backlog completion
  behavior (`lib/features/sync/README.md`, `docs/sync/sync_summary.md`).
 - Sync (Matrix): Coalescing and throttling refinements
   - Catch-up coalesces signals with a 1s minimum gap and runs exactly one trailing pass after bursts; logs `catchup.start` once and `catchup.done events=…` once per burst.
   - Live-scan never overlaps; signals during a scan defer as a single trailing pass. Base debounce ~120ms is extended to honor a 1s min gap; logs `signal.liveScan.coalesce` and `trailing.liveScan.scheduled`.
   - Double-scan for attachments now awaits the immediate second pass; a delayed pass runs at +200ms.
   - Historical windows reduced: catch-up `preContext=80`, `maxLookback=1000`; live-scan steady tail=30; audit tails 50/80/100.
   - Log volume reduced under `collectMetrics`; condensed `marker.local` to id+ts.
- feat(ai/labels): Append a summary note after the labels JSON in prompts when the
  number of available labels exceeds the cap, e.g. `(Note: showing 100 of 150 labels)`.
- Matrix Sync Stats page now uses the modern SettingsPageHeader with collapsing sliver layout and subtitle, aligning with the new settings header UX.
- Extracted header spacing and breakpoints into `lib/widgets/app_bar/settings_header_dimensions.dart` for maintainability and consistency.
- Settings header filter card now hugs the count summary by trimming the extra padding underneath it.
- Tasks and journal tabs now persist category filter selections independently, restoring their own state after app restart.
- Category filter storage migrated from shared `TASK_FILTERS` key to per-tab keys (`TASKS_CATEGORY_FILTERS` and `JOURNAL_CATEGORY_FILTERS`).
- Task status filters (Open, In Progress, Done, etc.) remain scoped exclusively to the tasks tab.
- AI prompt availability now respects platform capabilities, preventing confusion from unusable model options on mobile.

### Fixed
- Labels: description clearing when deleting the last character
  - Controller sanitizes input (trim + remove NBSP/ZWSP/BOM) and stores `null` in state when empty.
  - On update, the controller signals a clear by sending `''` (empty string) instead of `null`.
  - Repository update semantics: `null` = unchanged, empty string → clear (persist as `null`), non‑empty → trimmed.
  - Prevents the last stray character from reappearing after Save when the field was cleared.
  - Tests added for repository clearing and Label Details UI (keyboard shortcuts, cancel, error rendering, privacy toggle, category chip removal, controller reseed behavior). Codecov patch coverage improved for `label_details_page.dart` and `labels_list_page.dart`.
- AI: Hardened checklist item parsing to avoid accidental splitting when items contain commas or grouped text:
  - `add_multiple_checklist_items` now accepts a JSON array of strings (preferred) or a robustly parsed string.
  - Escaped commas (`\,`), quoted items ("..." / '...'), and commas inside parentheses/brackets/braces no longer split into separate items.
  - Updated prompt guidance to prefer arrays; fallback string format documented with escaping.
  - Added unit tests for parser and batch handler; analyzer warnings resolved.
- Sync Outbox: The red "Sync is not logged in" toast now triggers only when an outbox send is attempted while logged out, not on app startup. Prevents noisy startup toasts when users haven’t logged in yet.
- Sync (Matrix): Catch-up now continues escalating snapshot size until it’s not full (or lookback
  cap reached), ensuring the entire backlog after the read marker is retrieved. This eliminates
  missing EntryLinks after offline windows and prevents gray boxes on return to online.
 - Sync (Matrix): Fixed overlapping live-scans by guarding `_scanInFlight` with a depth counter and awaiting the immediate pass in attachment double-scans.
 - Sync Outbox: Eliminated "stuck after reconnect" cases by adding a watchdog (10s), DB nudge on outbox count changes (50ms), send timeout (20s) with `timedOut=true` logging, and pass-cap continuation; ClientRunner now catches callback errors and LoggingService DB failures are best-effort.
- Stabilized labels/task widget tests by awaiting `getIt.reset()`, providing scoped service mocks,
  and giving sheet/editor hosts real `MediaQuery` sizes so chips, toggles, and CTAs are tappable
  during automation.
- Waveform: show visualization for recordings longer than 3 minutes by removing the duration gate
  and introducing dynamic zoom scaling for long clips; updated tests and docs accordingly.
- Tasks: aligned task header date/progress typography and ensured mobile task list cards hide HH:MM progress text.

### Changed
- AI (checklist): Unified to array‑only batch creation. The single‑item tool is no longer used in
  conversations; tests and prompts now require `{ "items": [{"title": "...", "isChecked"?: bool}] }`.
- AI (tests): Stabilized checklist conversation tests by stubbing `ConversationRepository.sendMessage`
  to invoke `LottiChecklistStrategy.processToolCalls(...)` with predefined tool calls, avoiding
  brittle streaming mocks.
- AI (tests): Removed legacy skipped tests in
  `test/features/ai/functions/lotti_conversation_processor_test.dart` in favor of repo‑wired cases in
  `test/features/ai/functions/lotti_conversation_processor_via_repo_test.dart`.

### Tests
- Added deterministic scenarios: non‑GPT‑OSS batch, single via batch, 3‑item batch, GPT‑OSS batch,
  and language detection → create. All pass reliably.
- Hardened `lotti_batch_checklist_handler_test.dart`: assert non‑null item creation when appending
  to existing checklists; verify callback and payload; analyzer clean.

### Documentation
- Updated `lib/features/ai/README.md` with deterministic conversation testing guidance and file
  references.
- Expanded inline docs in `lib/features/ai/conversation/conversation_repository.dart` and
  `lib/features/ai/functions/lotti_conversation_processor.dart` to document streaming expectations
  and deterministic testing.

## [0.9.704] - 2025-10-24
### Added
- Comprehensive Fts5Db coverage with insert and search stream tests to guarantee new database behaviour.
- Added extensive database test coverage for purge flows, conversion utilities, sync outbox edge cases, logging safeguards, and settings persistence.

### Changed
- Retired the legacy Matrix sync V1 pipeline in favour of the stream-first implementation.

## [0.9.703] - 2025-10-24
### Added
- Timer indicator now auto-scrolls to the running entry when tapped from task details page.
- Task focus controller for managing scroll-to-entry intent across navigation events.

### Changed
- Expanded speech waveform coverage with scrubber interaction tests, painter edge cases, cache I/O failure guards, and path sanitisation scenarios.

### Fixed
- Stabilised waveform cache pruning tests by clearing mock interactions between scenarios.

## [0.9.702] - 2025-10-23
### Changed
- Matrix sync now tracks locally emitted Matrix event IDs in a shared sent-event registry, short-circuiting echo events during ingestion and recording suppression metrics to cut redundant network and database work.

## [0.9.701] - 2025-10-23
### Added
- Support Markdown divider insertion from the journal editor toolbar.

## [0.9.700] - 2025-10-23
### Changed
- Split the smart journal loader into dedicated `DescriptorDownloader` and `VectorClockValidator` components so caching, purging, and vector-clock logic are independently testable.

### Fixed
- Matrix V2 catch-up now advances markers after offline sessions by correcting journal update result semantics, eliminating false "missing base" retries, and trimming duplicate backlog processing.
- Matrix outbox refreshes journal JSON before enqueueing and Matrix sender re-syncs vector clocks with descriptor payloads, preventing stale checklist descriptors from being uploaded.
- Added a circuit breaker so stale descriptor downloads bail out after repeated refresh attempts instead of looping forever.
- Bumped patch version to 0.9.700+3390 to ship the sync catch-up contract fix without breaking APIs.

## [0.9.699] - 2025-10-22
### Changed
- Sync filter chips now hide non-informational zero badges, emphasise pending/error/unresolved totals with tinted badges, trim their height slightly, and keep empty-state cards constrained on the conflicts page.

## [0.9.698] - 2025-10-22
### Changed
- Audio player progress bar now matches the play/pause ring by using `ColorScheme.primary` for both the scrub fill and contrast-adjusted playhead, softens the playback card shadow, and removes the glow to avoid black playheads in high-contrast themes. Light mode swaps the gradient background for a flat surface tint to keep the card crisp.

## [0.9.697] - 2025-10-22
### Changed
- Speech audio playback card now ships with glassmorphism styling, streamlined controls, custom progress bar, and dedicated widget coverage for play/pause and speed interactions.

## [0.9.696] - 2025-10-21
### Changed
- Moved Matrix sync maintenance actions (delete sync database, re-sync definitions/messages) to the new Matrix Sync Maintenance page under Sync Settings.
- Sync Outbox and Sync Conflicts list pages now use modern cards with segmented filters, inline counts, and polished empty states via the shared sync list scaffold.
- Added dedicated widget tests for `ConflictListItem` and `SyncListScaffold` covering filters, semantics, and interaction paths.

### Fixed
- Matrix Stats `Last updated` label now stays stable when metrics payloads are unchanged, eliminating refresh jitter.
- Guarded sync list filters against invalid persisted enum indexes on conflicts/outbox pages to prevent `RangeError`.

## [0.9.695] - 2025-10-21
### Changed
- Matrix Stats now keeps per-type "Sent" counts stable while the page stays flicker-free on mobile and desktop.
- Read markers no longer spam `M_UNKNOWN` errors—local-only IDs are skipped and expected misses are logged once.

## [0.9.694] - 2025-10-21
### Changed
- Sync UX overhaul:
  - Promote Sync to a top-level Settings entry (hidden when Matrix sync flag is off)
  - Move Outbox Monitor under `/settings/sync/outbox` and remove redundant toggle
  - Surface Matrix Stats as a full page under `/settings/sync/stats` with improved loading state
  - Clean up Advanced: remove Matrix/Outbox/Conflicts tiles; keep Logs, Health Import (mobile), Maintenance, About
  - Route matching for Sync pages now uses exact path matching for robustness
  - Localize new user-facing strings (tile subtitles and error text)

## [0.9.693] - 2025-10-21
### Changed
- Hid pre-release features when their corresponding tabs are disabled, tightening entry-type gating and extending localisation coverage.

## [0.9.692] - 2025-10-20
### Changed:
- Enforce tabular monospace style for tasks timers (monoTabularStyle) to eliminate width jitter.

## [0.9.691] - 2025-10-20
### Changed:
- Audio recorder: improve prompt checkbox visibility for better contrast and readability

## [0.9.690] - 2025-10-20
### Added:
- Export checklist as Markdown from the checklist view (#2331)
- Share checklist via the iOS/macOS share sheet (#2331)

## [0.9.689] - 2025-10-19
### Changed:
- Upgraded dependencies across the project (#2330)

## [0.9.688] - 2025-10-19
### Changed:
- Improve initial synchronization reliability and speed at app start (#2329)

## [0.9.687] - 2025-10-17
### Changed:
- Harden v2 sync with stronger error handling and state management (#2327)

## [0.9.686] - 2025-10-14
### Fixed:
- Clamp bottom navigation index to a valid range to avoid out-of-bounds selection (#2323)

## [0.9.685] - 2025-10-14
### Added:
- Drag and drop audio to quickly add or import audio content (#2322)

## [0.9.684] - 2025-10-13
### Changed:
- Refined sync stats UI for clearer labels and improved readability (#2321)

## [0.9.682] - 2025-10-12
### Added:
- Copy as plain text from supported views (#2319)
- Copy as Markdown with formatting preserved (#2319)

## [0.9.680] - 2025-10-12
### Changed:
- Improve sync reliability with better retry and state handling (#2317)

## [0.9.679] - 2025-10-12
### Changed:
- Upgraded Matrix SDK to 3.0.0 and adapted usage where necessary (#2316)

## [0.9.678] - 2025-10-12
### Added:
- Emoji input and rendering support on Linux (#2318)

## [0.9.677] - 2025-10-10
### Fixed:
- Issue where sync could lag one event behind (#2313)

## [0.9.676] - 2025-10-09
### Changed:
- Internal sync code cleanup and refactoring to reduce complexity (#2308)

## [0.9.675] - 2025-10-07
### Changed:
- Extract session, room, and timeline managers into dedicated components (#2304)
### Fixed:
- Auto-join bug in Matrix integration (M6) (#2304)

## [0.9.674] - 2025-10-06
### Added:
- Exponential backoff for sync retry strategy to improve stability on flaky networks (#2299)

## [0.9.673] - 2025-10-06
### Changed:
- Sync maintenance refactor and tidy-up of helpers and lifecycles (#2300)

## [0.9.672] - 2025-10-06
### Changed:
- Improve sync login resilience with better recovery from transient errors (#2298)

## [0.9.671] - 2025-10-05
### Fixed:
- Clipped text in editor (#2293)

## [0.9.670] - 2025-10-04
### Changed:
- Update task summaries when changing the app language to keep content in sync (#2291)

## [0.9.669] - 2025-09-27

### Changed:
- Upgraded dependencies

## [0.9.668] - 2025-09-23

### Added:
- Gemma 3n local AI provider support for audio transcription and text generation
- Streaming support for Gemma 3n text generation with OpenAI-compatible API
- Internationalization for Gemma 3n provider strings

### Changed:
- Refactored provider configuration to centralize API key requirement logic
- Improved JSON response validation in Gemma 3n repository with try-catch error handling
- Hide API key field for local providers (Ollama, Whisper, Gemma 3n)

## [0.9.667] - 2025-09-22

### Added:
- Gemma 3N audio transcription service with Docker and local Python support
- Self-contained Flatpak build system with automated submission scripts
- Improved screenshot portal service for Flatpak environments

### Changed:
- Updated app identifier from com.matthiasnehlsen.lotti to com.matthiasn.lotti across all platforms
- Enhanced Gemma service with improved error handling and streaming capabilities
- Upgraded Flutter to version 3.35.4
- Upgraded dependencies

### Fixed:
- Gemma service transcription improvements with better audio processing
- Flatpak build process streamlining and reliability enhancements

## [0.9.665] - 2025-09-17
### Changed:
- Update app identifier to use with different Apple developer account

## [0.9.664] - 2025-09-17
### Changed:
- Upgraded Flutter to version 3.35.4
- Upgraded dependencies (minor versions)

## [0.9.663] - 2025-09-14
### Changed:
- const factories
- Upgraded Matrix SDK to version 2.0.1
- Improved `deleteDevice` method with proper validation and error handling

### Fixed:
- Replaced deprecated `loginState` with `client.isLogged()` method
- Added proper password authentication for device deletion
- Added user feedback for device deletion operations with success/error messages

### Added:
- Validation for device ownership before deletion attempts
- Clear error messages when device deletion fails
- TODO for future SSO/token authentication support in device deletion

## [0.8.393] - 2023-06-29
### Changed:
- Consistent microphone icon across app
- Upgraded dependencies

### Fixed:
- Sort categories
- Bottom sheet heights

## [0.8.392] - 2023-06-24
### Changed:
- Hide measurement suggestions when input dirty
- Upgraded dependencies

## [0.8.391] - 2023-06-24
### Changed:
- Keyboard dismiss behavior

## [0.8.390] - 2023-06-23
### Added:
- Log sync email subject for debugging

## [0.8.389] - 2023-06-23
### Changed:
- Smoother scrolling infinite journal page

## [0.8.388] - 2023-06-23
### Changed:
- Upgraded dependencies

### Fixed:
- Text color on tag and task status chips

## [0.8.387] - 2023-06-22
### Changed:
- Unfocus keyboard on entry/task save

## [0.8.386] - 2023-06-22
### Fixed:
- Habits search field style

## [0.8.385] - 2023-06-22
### Changed
- Delete icon style
- Start new tag dialog with search field content
- Whitespace on entity detail pages

## [0.8.384] - 2023-06-21
### Changed
- Audio recorder and player icons and style

## [0.8.383] - 2023-06-21
### Changed:
- Upgraded dependencies

## [0.8.382] - 2023-06-19
### Added:
- Shimmer animation on habit success button

### Changed:
- Upgraded dependencies
- Choice chip styles
- Habit skip button saturation
- Smoother transitions on navigate

## [0.8.381] - 2023-06-17
### Changed:
- Typography in DateTime modal
- Selected color in editor toolbar

### Fixed:
- Survey next button text color

## [0.8.380] - 2023-06-16
### Fixed:
- Border in search widget

## [0.8.379] - 2023-06-16
### Changed:
- Update tasks page when task created

## [0.8.378] - 2023-06-16
### Fixed:
- Update whisper model size after completed download

## [0.8.377] - 2023-06-15
### Changed:
- Upgraded icons
- Consistent text style in input fields
- Prominent name fields in entity definitions
- New Flutter version
- Upgraded dependencies

### Fixed:
- Text weight and whitespace in entry card footer
- Form field text color in light mode
- Flaky test
- Habit skip and completion colors
- Clipped habit bottom sheet corners

## [0.8.376] - 2023-06-12
### Changed:
- Text weight and whitespace in entry card footer
- Splash screen

### Fixed:
- Filter choice chip text color
- Short display of black screen at startup
- Missing routes
- Not found error on tasks page

## [0.8.375] - 2023-06-10
### Fixed:
- App data folders on Linux

### Changed:
- Upgraded dependencies

## [0.8.374] - 2023-06-09
### Changed:
- Refactoring: remove ThemesService
- Settings page for light and dark color themes

## [0.8.373] - 2023-06-08
### Fixed:
- BP chart header

## [0.8.372] - 2023-06-08
### Changed:
- Improved dashboards page header
- New Flutter version

## [0.8.371] - 2023-06-08
### Changed:
- Colors in measurables dialog
- Borders in bottom sheets and dialogs
- Upgraded dependencies

## [0.8.370] - 2023-06-07
### Changed:
- Upgraded dependencies
- Non-persistent title sliver app bar on dashboards page
- Spacing in habits search header
- Habit completion card typography & whitespace

### Fixed:
- Keyboard brightness when following system dark/light modes

## [0.8.369] - 2023-06-06
### Changed:
- Improve habit completion chart colors

## [0.8.368] - 2023-06-06
### Added:
- Config flag for following system brightness

## [0.8.367] - 2023-06-05
### Changed:
- Color schemes from flex_color_scheme
- Styling
- Style fixes & refactoring
- Styles refactoring
- Text editor border
- Editor toolbar elevation
- Habit completion bottom sheet background styling

### Fixed:
- Task duration estimate bottom sheet
- Font colors on survey bottom sheet
- Color issues
- Charts layout
- Colors in dashboard chart selector
- Colors in entry delete bottom sheet
- Colors in measurables definition page
- Tag search text color

## [0.8.366] - 2023-06-03
### Changed:
- Adapt filter chips to match Material 3 design
- Upgraded dependencies & Flutter upgrade
- Use segmented button with icons for filtering journal

## [0.8.365] - 2023-06-02
### Fixed:
- Display of Whisper model sizes

## [0.8.364] - 2023-06-01
### Changed:
- Use habit completion card as habit chart in dashboard

## [0.8.363] - 2023-06-01
### Changed:
- Upgraded dependencies
- Time span segmented controls style to match habit statuses

## [0.8.362] - 2023-05-31
### Fixed:
- Category opacity

### Changed:
- License: GPL
- Upgraded dependencies

## [0.8.361] - 2023-05-31
### Changed:
- Habit status segmented control style
- Upgraded dependencies

## [0.8.360] - 2023-05-30
### Changed:
- Upgraded dependencies
- Health import in transaction

### Fixed:
- Locked db when importing from health

## [0.8.359] - 2023-05-26
### Fixed:
- Default language English instead of German (first in alphabetical order)

### Changed:
- Flutter upgraded to 3.10.2 & upgraded dependencies

## [0.8.358] - 2023-05-23
### Fixed:
- Crashes when attempting simultaneous transcriptions

## [0.8.357] - 2023-05-22
### Changed:
- Upgraded dependencies
- Larger map with interaction

### Added:
- Display size of downloaded whisper models

## [0.8.356] - 2023-05-21
### Changed:
- Improve header style on settings page using Slivers
- Improve header style on advanced settings page using Slivers
- Health import styling
- Hide health import page on all platforms but iOS
- Upgraded dependencies
- Add back button on advanced settings page
- Sliver app bar in entity definitions
- Sliver app bar in speech settings
- Sliver app bar in config flags page
- Sliver app bar on maintenance page
- Sliver app bar on about page
- Sliver app bar on health import page
- Sliver app bar on dashboard page
- Sliver app bar on logging page

### Added:
- Tests for category settings page
- Tests for habit filters
- Tests for dashboards page

## [0.8.355] - 2023-05-19
### Added:
- Delete individual transcripts

## [0.8.354] - 2023-05-18
### Changed:
- Refactoring in ASR code on macOS
- Refactoring in ASR code on iOS
- Consolidate ASR code, maintained in macOS
- Upgrade whisper.cpp to v1.4.2

## [0.8.353] - 2023-05-18
### Added:
- Pass filter when navigating from habits to habit settings

## [0.8.352] - 2023-05-18
### Changed:
- Outbox item style
- Upgrade dependencies

### Fixed:
- Remove print_special output in transcription on macOS

## [0.8.351] - 2023-05-18
### Added:
- Speech recognition in any language supported by Whisper

## [0.8.350] - 2023-05-17
### Added:
- Config flag for task management
- Conditionally show add task action icon

### Changed:
- Tasks moved to separate tasks tab
- Upgraded dependencies (major versions)
- Use new SearchBar widget
- Use new SearchBar widget on Habits page

### Fixed:
- Navigation after recording audio

## [0.8.349] - 2023-05-16
### Changed:
- Journal tab renamed to Logbook

## [0.8.348] - 2023-05-14
### Changed:
- Remove `adaptive_dialog` library
- Upgraded dependencies & removing unused
- Upgraded Flutter to 3.10
- Upgraded Fluttium

### Fixed:
- Flutter 3.10 warnings & errors
- Android build issues after Flutter upgrade

## [0.8.347] - 2023-05-13
### Added:
- Settings page for downloading and activating whisper models
- Download whisper.cpp models from Hugging Face
- Detect downloaded models
- Speech recognition on iOS
- Background modes on iOS for fetch and processing
- Select whisper model
- Delete downloaded model

### Changed:
- Only show speech settings on macOS and iOS for now
- Hide large whisper models
- Upgraded dependencies
- Preparation for Flutter 3.10
- Only detect audio language when non-english model is selected

### Fixed:
- Model download on iOS
- Update model status after deleting model

## [0.8.346] - 2023-05-11
### Added:
- Automatically transcribe audio on macOS

## [0.8.345] - 2023-05-10
### Added:
- Transcription icon in audio player on macOS
- Audio conversion from aac to wav with ffmpeg_kit_flutter
- whisper.cpp library for speech recognition
- English speech recognition, with the result logged
- Transcript data structure
- Add transcriptions to audio entries
- Capture duration of generating transcript
- Faster transcripts via compiler flag
- Compiler flags -O3 -DNDEBUG
- Update whisper.cpp to v1.4.0
- Compiler flags -O3 -DNDEBUG in debug/dev mode (transcription time for 1m test audio down from 27s to 4s)
- Display audio duration in journal card
- Language detection (logging only)
- Indicator for existing transcriptions
- Set entry text from transcript & update

### Changed:
- Toggle for showing individual transcripts
- Chore: upgraded dependencies

### Fixed:
- Set entry text from transcript
- Update entry text after adding transcript

## [0.8.344] - 2023-05-05
### Changed:
- Upgraded dependencies
- Refactoring: BloC for state management on dashboards page

### Added:
- Filter dashboards by categories
- Tests for dashboards page

## [0.8.343] - 2023-05-04
### Fixed:
- Margin below habit completion dialog
- Awaiting in getIt init

### Changed:
- Upgraded dependencies

## [0.8.341] - 2023-05-02
### Changed:
- Upgraded dependencies
- Show config flag for invalid cert
- App documents folder on Windows

### Fixed:
- App ID on Windows and Linux

### Added:
- Save and restore window position on Windows and Linux
- HotKey support on Windows and Linux

## [0.8.340] - 2023-04-29
### Fixed:
- Habit completion bottom sheet height

## [0.8.339] - 2023-04-28
### Fixed:
- Missing `libmpv.so` on Android preventing startup

## [0.8.338] - 2023-04-28
### Fixed:
- Screenshots of habit completion dialog in Fluttium flow

## [0.8.337] - 2023-04-28
### Changed:
- Improved habit completion bottom sheet
- Upgraded dependencies

### Fixed:
- Keyboard hiding habit completion bottom sheet

## [0.8.336] - 2023-04-28
### Changed:
- Smaller APK sizes (thanks @alexmercerind)
- Upgraded dependencies
- Faster CI runs on Buildkite

## [0.8.334] - 2023-04-27
### Changed:
- Dashboard in habit completion now above the dialog, leaving the dialog always in the same position

## [0.8.333] - 2023-04-26
### Fixed:
- Editor losing focus after interacting with the editor toolbar

## [0.8.333] - 2023-04-26
### Changed:
- Reduced APK size

## [0.8.332] - 2023-04-26
### Fixed:
- Location on Linux

## [0.8.331] - 2023-04-25
### Added:
- Audio playback on Linux

### Changed:
- Upgraded dependencies

## [0.8.330] - 2023-04-24
### Changed:
- Sync assistant styling
- Upgraded dependencies

### Fixed:
- Sync getting stuck after generating new sync key and on reading sync message encrypted with old key

## [0.8.329] - 2023-04-23
### Changed:
- Upgrade flutter_quill lib

## [0.8.328] - 2023-04-23
### Changed:
- Show audio player inline in linked entries

## [0.8.327] - 2023-04-22
### Fixed:
- Navigation after delete (not when displayed as a linked entry)

### Changed:
- Updated provisioning profile (was expired)
- Automatically managed signing on iOS

## [0.8.326] - 2023-04-21
### Added:
- GitHub Action for running Fluttium tests on Windows

## [0.8.325] - 2023-04-20
### Added:
- Semantic labels in measurable data type setting
- Screenshot of creating measurable data types for manual

### Changed:
- Colors and whitespace
- Upgraded dependencies
- Initial height of chart selector bottom sheet
- Slightly less saturated card color

### Fixed:
- Test flows

## [0.8.324] - 2023-04-19
### Fixed:
- Image card background

## [0.8.323] - 2023-04-18
### Changed:
- Updated manual
- Less verbose logging
- App icon with gradient

## [0.8.322] - 2023-04-16
### Changed:
- Fluttium screenshots are pushed to lotti-docs repository

## [0.8.321] - 2023-04-15
### Changed:
- App icon on Android
- App icon on macOS
- App icon on Windows

## [0.8.320] - 2023-04-15
### Changed:
- App icon on Windows
- Upgraded dependencies
- Improved color picker

### Added:
- Category color text field for HEX color, with ColorPicker moved to bottom sheet

### Fixed:
- Update color HEX field after picking new color

## [0.8.319] - 2023-04-13
### Changed:
- Measurable setting page layout

## [0.8.318] - 2023-04-13
### Changed:
- New app icon

## [0.8.317] - 2023-04-12
### Added:
- Settings icon on Habits page

### Fixed:
- SafeArea around Dashboards page

## [0.8.316] - 2023-04-12
### Fixed:
- Clear categories filter visibility
- Text overflow for long habit titles

## [0.8.315] - 2023-04-12
### Added:
- Category selection for dashboards

### Changed:
- Improved search field
- Improved dashboards page header

## [0.8.314] - 2023-04-11
### Changed:
- Material icons in bottom nav
- Material icons in audio recorder
- Remove unused code
- Upgraded dependencies

## [0.8.313] - 2023-04-11
### Changed:
- Updated README

## [0.8.312] - 2023-04-10
### Changed:
- Upgraded dependencies
- Refactoring on Journal page
- Improved habits page header

### Fixed:
- SafeArea around Habit page

## [0.8.311] - 2023-04-09
### Changed:
- Initial window size on macOS

## [0.8.310] - 2023-04-09
### Added:
- Integration tests using Fluttium
- Config flag for recording geolocation
- Category color icons for habit completion card and entry detail view
- Fluttium test in Buildkite

### Changed:
- Reordered fields in habit config
- Default story removed from habits

### Fixed:
- Entry DateTime field width

## [0.8.309] - 2023-04-08
### Changed:
- Refactoring in audio recording

## [0.8.308] - 2023-04-07
### Changed:
- Data capture dialog style

## [0.8.307] - 2023-04-07
### Changed:
- Upgraded dependencies
- App icon for windows msix
- Removed chart animation
- Whitespace in habit completion bottom sheet

## [0.8.306] - 2023-04-06
### Added:
- Windows build

## [0.8.305] - 2023-04-05
### Changed:
- Carousel in dashboards removed

### Fixed:
- Data capture from dashboard line chart
- Style consistency in dialog input fields

## [0.8.304] - 2023-04-05
### Added:
- Android release

## [0.8.303] - 2023-04-04
### Changed:
- Habit completion in modal bottom sheet instead of dialog
- Measurement dialog without beamer page
- Habit completion dialog without beamer page

### Added:
- Select dashboard to display during habit completion
- Show dashboard associated with habit in habit completion modal bottom sheet

### Fixed:
- Sort & filter dashboards in habit definition
- Complete habits for prior days

## [0.8.302] - 2023-04-03
### Fixed:
- Suggested previous values in measurement capture dialog cannot be selected

## [0.8.301] - 2023-04-03
### Fixed:
- Permission for notifications

### Changed:
- Postponed request for geolocation in first-time user experience

## [0.8.300] - 2023-04-02
### Fixed:
- Picking multiple images only picking one image

## [0.8.299] - 2023-04-02
### Changed:
- Upgraded Flutter
- Change habit active status to archived status

### Fixed:
- DateTime form field width

## [0.8.298] - 2023-04-01
### Changed:
- Categories filter applies to all sections, not only currently due habits

## [0.8.297] - 2023-04-01
### Changed:
- Upgrade dependencies
- Whitespace on entry detail page

### Fixed:
- Styling of DateTime modal bottom sheet

## [0.8.296] - 2023-03-30
### Fixed:
- Habit completion chart display range issue

## [0.8.295] - 2023-03-29
### Changed:
- Upgraded dependencies
- Improved naming in habit definition

### Fixed:
- Habit Start Date field appeared filled when it was not

## [0.8.294] - 2023-03-28
### Fixed:
- Show save button upon category color change

## [0.8.293] - 2023-03-28
### Changed:
- Fill survey page removed

## [0.8.292] - 2023-03-27
### Changed:
- FormBuilderCupertinoDateTimePicker replaced in task estimate
- FormBuilderCupertinoDateTimePicker replaced in habit completion dialog
- Removed opacity in bottom sheets
- FormBuilderCupertinoDateTimePicker replaced in new measurement dialog
- New measurement page removed
- flutter_datetime_picker removed from entry datetime modal
- Simpler display of habit completion count
- FormBuilderCupertinoDateTimePicker replaced in habit definition
- FormBuilderCupertinoDateTimePicker code removed
- Upgraded dependencies

## [0.8.291] - 2023-03-27
### Fixed:
- Missing day in habits after switching to DST

## [0.8.290] - 2023-03-26
### Added:
- Display time spent on task

## [0.8.289] - 2023-03-26
### Fixed:
- Category save duplicate warning
- Disable category save icon when form invalid
- Recreate category with the same name as previously deleted category
- Scroll in setting when window is small

### Changed:
- Upgraded dependencies

## [0.8.288] - 2023-03-25
### Added:
- Visualization for categories of open habits
- Category name validation checking for duplicates
- Categories filter bottom sheet with categories toggle
- Filtered habits view by selected category

### Changed:
- Upgraded dependencies

### Fixed:
- Delete category question and confirmation label
- Scroll in category bottom sheet
- Prevent duplicate categories
- Categories filter not visible when no open habits displayed
- 180 days in habit completion rate chart

## [0.8.287] - 2023-03-22
### Changed:
- Habit completion card layout

## [0.8.286] - 2023-03-21
### Added:
- Category entity type
- Categories list page
- Categories details page
- Set category color
- Priority switch in habit, for more prominent display
- Priority icon in habit settings list card
- Priority icon in habits list card
- Category selection in habit definition
- Category color in habit settings card
- Habits sorted by priority first
- Habit color in habit completion card

### Changed:
- Whitespace in settings
- Upgraded dependencies

### Fixed:
- Focus issue in habit category selection

## [0.8.285] - 2023-03-19
### Added:
- Segmented control for filtering which habits are shown (due, later today, complete, all)
- Search field for habits

### Changed:
- Selectable habit time spans
- More obvious habit completion state with strike-trough text and subtle opacity
- Upgraded dependencies
- Toggle display of habits time span

## [0.8.284] - 2023-03-19
### Changed:
- Habit completion icon

### Fixed:
- CI pipeline

## [0.8.283] - 2023-03-18
### Changed:
- Refactor: remove unused code
- Line in header removed
- Upgraded dependencies

## [0.8.282] - 2023-03-17
### Added:
- Placeholder text in editor (English and German)

### Changed:
- Improved journal filters

## [0.8.281] - 2023-03-16
### Changed:
- Habit cards
- Task status styling
- Whitespace around cards
- Task card whitespace
- Refactoring: extracted theme

## [0.8.280] - 2023-03-16
### Changed:
- Use Material Design icons

## [0.8.279] - 2023-03-15
### Changed:
- Using Cards from Material Design 3 throughout where appropriate
- Upgraded dependencies
- Material Cards in Tag, Habit, and Dashboard definition pages

### Fixed:
- Outbox color by status

## [0.8.278] - 2023-03-13
### Changed:
- Unused code removed
- Upgraded dependencies

## [0.8.277] - 2023-03-03
### Changed:
- Upgraded dependencies

### Fixed:
- Entry DateTime modal layout

## [0.8.276] - 2023-02-28
### Changed:
- more consistent bottom sheet modals
- remove limit in tag search results
- replace monospace font with main font & tabularFigures font feature

## [0.8.275] - 2023-02-26
### Changed:
- Refactor: use showModalBottomSheet for managing tags
- CI: retry on exit status 2
- Upgrade fl_chart library

## [0.8.274] - 2023-02-26
### Changed:
- More consistent app bar
- Reduce clutter in tasks header by moving count stats
- Upgraded dependencies
- Improved styling of about page

## [0.8.273] - 2023-02-24
### Changed:
- Upgraded dependencies
- Progress bar height and opacity
- Remove entry duration in journal card

## [0.8.272] - 2023-02-24
### Changed:
- Replace task progress indicator with material widget
- Editor toolbar styling

## [0.8.271] - 2023-02-23
### Fixed:
- Background color at the top of the survey bottom sheet
- Background color of survey dismiss dialog

## [0.8.270] - 2023-02-22
### Changed:
- Reduce clutter in entry card
- Upgraded dependencies

## [0.8.269] - 2023-02-20
### Changed:
- Replace modal_bottom_sheet lib with Flutter's own implementation
- Replace badges lib with Flutter's own implementation

## [0.8.268] - 2023-02-19
### Fixed:
- Habit fail button color
- Save button color
- Clipped save button on measurement page

## [0.8.267] - 2023-02-19
### Changed:
- Upgraded dependencies

## [0.8.266] - 2023-02-13
### Changed:
- Upgraded dependencies

### Fixed:
- Data capture dialog jumpiness
- Prevent dialog resize when save button becomes visible

## [0.8.265] - 2023-02-13
### Fixed:
- Navigate back icon on task page
- Unordered list color in editor
- Editor menu background color
- Chip style
- Primary material color

### Changed:
- Improved task input fields layout
- Improved chip layout
- Tweak spacing in journal filters
- Improved styling in settings
- Upgraded dependencies
- Tweak bottom navigation bar styling
- Darker link and success icon color in habits completion

## [0.8.264] - 2023-02-11
### Fixed:
- Audio playback restart on navigate to audio entry

### Changed:
- Improved input field layout

## [0.8.263] - 2023-02-10
### Changed:
- Refactoring: set main font in theme in one place
- Material Design 3 enabled

## [0.8.262] - 2023-02-10
### Fixed:
- Display of null title when completing habit

### Changed:
- Upgrade Flutter and dependencies

## [0.8.261] - 2023-02-09
### Fixed:
- Sleep data import
- Flights of stairs data import
- Total distance in interval data import
- Jumpy badge animation

## [0.8.260] - 2023-02-08
### Changed:
- Upgraded very_good_analysis lib

## [0.8.259] - 2023-02-08
### Changed:
- Use Flutter 3.7.1
- Latest health lib (breaks flights of stairs and sleep types)

## [0.8.258] - 2023-02-07
### Changed:
- Replace read-only flutter_quill with flutter_markdown for better scroll performance

### Fixed:
- Journal card text color when using bright theme

## [0.8.257] - 2023-02-06
### Fixed:
- Locking issue in sync

### Added:
- Settings DB

### Changed:
- Window manager persistence moved to settings database
- Routing persistence moved to settings database
- Last read UID persistence moved to settings database
- Improved logging

## [0.8.255] - 2023-02-02
### Changed:
- Upgrade dependencies

### Fixed:
- Keychain locking issue

## [0.8.254] - 2023-01-27
### Changed:
- Improved workout labels

### Fixed:
- Remove broken workout time health chart (workouts are a separate category now)

## [0.8.253] - 2023-01-25
### Changed:
- Upgrade dependencies - major versions

## [0.8.252] - 2023-01-25
### Fixed:
- Repeat tapping of mic overwrote old audio file
- Pop audio recorder as expected

Added:
- Pause icon in audio recorder functionality

## [0.8.251] - 2023-01-24
### Changed:
- Remove unused theme config widget
- Hide config flag: allow_invalid_cert

## [0.8.250] - 2023-01-24
### Changed:
- Remove redundant config flag: enable_beamer_nav
- Remove redundant config flag: listen_to_global_screenshot_hotkey
- Remove redundant config flag: show_tasks_tab
- Remove redundant config flag: hide_for_screenshot
- Remove redundant config flag: notify_exceptions

## [0.8.249] - 2023-01-23
### Changed:
- Differentiate between failed and missing habit completion
- Upgraded dependencies

## [0.8.248] - 2023-01-22
### Changed:
- Upgraded dependencies

### Fixed:
- Fix updating habit completion type

## [0.8.247] - 2023-01-20
### Changed:
- Audio recording lib replaced

### Added:
- Audio recording on macOS

## [0.8.246] - 2023-01-19
### Changed:
- Chore: redundant dependencies removed
- Chore: upgraded dependencies

## [0.8.243] - 2023-01-18
### Changed:
- Adaptive minY value in habit completion chart
- Toggle between zero-based and adaptive charts
- Upgraded dependencies

### Fixed:
- Habit completion percentages
- Show toggle for adaptive charts only when leading to discernible differences

## [0.8.242] - 2023-01-16
### Fixed:
- AppStore Connect warning

## [0.8.241] - 2023-01-15
### Fixed:
- Record audio note as comment to other entry types

## [0.8.240] - 2023-01-14
### Fixed:
- Text color for entry duration when timer running
- Fix possibility of accidentally overwriting task title, estimate, and status

## [0.8.239] - 2023-01-14
### Changed:
- Long press on entry type filter to select only one type
- Select all entry types toggle button
- Long press on task status filter to select only one status
- Select all task statuses toggle button

### Fixed:
- Add missing habit completion summary in entry detail view

## [0.8.238] - 2023-01-14
### Fixed:
- Code font color in text editor
- Consolidate monospace text styles

## [0.8.237] - 2023-01-14
### Fixed:
- Navigate back after entry deletion

## [0.8.236] - 2023-01-14
### Fixed:
- Unlinking entries

## [0.8.235] - 2023-01-13
### Added:
- Remove habit streaks section - not useful, streaks are apparent without
- Chore: upgraded dependencies

## [0.8.234] - 2023-01-13
### Changed:
- Journal card styling
- Entry type filter styling
- Task filter styling

## [0.8.233] - 2023-01-13
### Changed:
- Decluttered task view: only show editor toolbar on first focus
- Decluttered task view: only show tags in task comments when not equal to parent tags
- Show total time spent on a task
- Show task stats
- Task search header styling

## [0.8.232] - 2023-01-13
### Changed:
- Tasks by status can now be found in the journal tab
- Full-text search in tasks
- Tasks tab removed
- Task card navigation adapted
- CMD-R for reloading journal page
- Flagged entries count badge move into search header
- In-progress tasks count badge move into search header

### Fixed:
- Assigning tags to tasks

## [0.8.231] - 2023-01-12
- Fix keyboard dismissal in search field by always showing the X icon
- Fix clearing story selection in habit definition

## [0.8.230] - 2023-01-11
### Changed:
- Simplify settings by removing irrelevant favorite status switch in measurables (not used)
- Story time chart selections removed, will need to be simplified and/or rethought
- Dashboard notification time removed, will be handled better by notifications on habits, such as the habit of looking at a particular dashboard

## [0.8.229] - 2023-01-11
### Fixed:
- Update of JournalImage after change

## [0.8.229] - 2023-01-10
### Changed:
- Show popular values in capture dialog for past dates

## [0.8.228] - 2023-01-10
### Added:
- Full-text search database using FTS5
- Wire full-text database search (no refresh yet)
- Add tags in full-text search
- Add entities cache for faster lookup of measurable data types
- Use entities cache in measurement summary
- Refactor: move fetch logic to cubit
- Refresh results when typing in full-text search field
- Add new and updated text to full-text index
- Fix index creation maintenance task
- Remove previous entry in FTS5 index when updated
- One-step index recreation

### Fixed:
- Update JournalCard in infinite scroll automatically on change, e.g. after navigating back
- Clear query

### Changed:
- Upgraded dependencies

## [0.8.227] - 2023-01-07
### Changed:
- New search header in journal
- Upgraded dependencies

## [0.8.226] - 2023-01-07
### Changed:
- Declutter task form
- Simplified editor toolbar
- Unified searchable list
- Hide task title label when task defined
- Floating search bar replaced in settings
- Floating search bar replaced in journal

## [0.8.225] - 2023-01-06
### Changed:
- Improved text editor layout

## [0.8.224] - 2023-01-05
### Fixed:
- Disappearing keyboard on mobile
- Color theme in tag search

## [0.8.223] - 2023-01-04
### Changed:
- Consistently use light and dark keyboard types
- Upgraded dependencies

## [0.8.222] - 2022-12-31
### Changed:
- Limit editor height so that editor toolbar always stays visible

## [0.8.221] - 2022-12-30
### Changed:
- Fix completion rate by taking into account from when on to count a habit

## [0.8.220] - 2022-12-29
### Fixed:
- Screenshot delay
- Reduce allocations in sync

## [0.8.219] - 2022-12-28
### Changed:
- Disable smooth curved lines in habits chart: sharp lines are not overshooting
- Improved chart layout and CTA (tap chart for daily breakdown)

## [0.8.218] - 2022-12-27
### Changed:
- Journal page with infinite scroll

## [0.8.217] - 2022-12-26
### Changed:
- Improved blood pressure chart

## [0.8.216] - 2022-12-26
### Changed:
- Improved whitespace in habit page header
- Habit chart grid: lines at 20, 40, 60, 80, 100%
- Emphasized 80%-line (sensible minimum target)

## [0.8.215] - 2022-12-25
### Changed:
- Improved habit chart info on tap
- Clear habit chart info within 15 seconds

## [0.8.214] - 2022-12-24
### Added:
- Stacked habit success chart, with success, skipped, explicitly failed, implicitly failed

## [0.8.213] - 2022-12-23
### Added:
- Throttle habits success scoring
- Habit completions via click on habits success indicator

### Fixed:
- Condition where sync inbox could fail during processing and be skipped
- Performance issues when syncing health-related entries

## [0.8.212] - 2022-12-19
### Changed:
- Remove useless entry text toggle icon

## [0.8.211] - 2022-12-18
### Changed:
- Header position on image entries

### Fixed:
- Duplicate display issue
- Tag display issue in JournalCard

## [0.8.210] - 2022-12-17
### Changed:
- Improve line charts by using fl_chart library
- Improve blood pressure chart by using fl_chart library

## [0.8.209] - 2022-12-16
### Fixed:
- Habit completion percentage when private habits not shown

## [0.8.208] - 2022-12-15
### Added:
- Charts for habit skip and explicit habit success

## [0.8.207] - 2022-12-13
### Changed:
- Unlink icon in editor toolbar instead of using Dismissable

## [0.8.206] - 2022-12-11
### Added:
- Tooltips for habit completions, showing date

### Changed:
- Show habit streaks count at bottom of habits page, with labels
- Extract habit streak lists & use adaptive header
- Remove autofocus on measurement value field
- Unify segmented time span controls on dashboard and habit pages
- Increase analyzed habit completion time span to 90 days
- Show date in habit completion rate chart tooltip

## [0.8.205] - 2022-12-09
### Added:
- Chart for habit completion rate over time

### Changed:
- Improved whitespace in habit success indicators
- Improved habit completion rate tooltips

## [0.8.204] - 2022-12-07
### Added:
- Progress bar for habit progress for the current day

## [0.8.203] - 2022-12-05
### Added:
- Suggest last used value in measurable
- Upgrade dependencies
- More responsiveness in measurement creation

## [0.8.202] - 2022-12-01
### Added:
- Habit autocomplete rules editor experiments

## [0.8.201] - 2022-11-22
### Added:
- Show habit description during completion

## [0.8.200] - 2022-11-21
### Changed:
- Refactoring in habit definition page: move logic to cubit

## [0.8.199] - 2022-11-20
### Fixed:
- Show expected habit success from when defined

## [0.8.198] - 2022-11-20
### Added:
- Editor display toggle

## [0.8.197] - 2022-11-20
### Added:
- Habit autocomplete definition refinements
- Optional titles in habit rules
- Habit autocompletion type other habit rule

### Changed:
- New Flutter version & dependencies
- Habits displayed for last 30 days by default on both mobile and desktop

## [0.8.196] - 2022-11-10
### Changed:
- Define default story for habit completion entry

## [0.8.195] - 2022-11-08
### Changed:
- Record duration between opening habit and completing habit (unless date in the past is selected)

## [0.8.194] - 2022-11-08
### Changed:
- Audio playback speed toggle instead of individual icon button

## [0.8.193] - 2022-11-07
### Changed:
- Upgraded dependencies
- Error handling in editor

### Added:
- CMD-S in task title field

## [0.8.192] - 2022-11-07
### Changed:
- Multiline comments and max width in habit capture dialog

## [0.8.191] - 2022-11-05
### Changed:
- Allow setting habit active or inactive
- Rename "active from" to "expect success from"

## [0.8.190] - 2022-11-04
- Flutter upgrade
- Upgraded dependencies

## [0.8.189] - 2022-10-30
### Fixed:
- Flicker in entry & task tag selection

## [0.8.188] - 2022-10-29
### Fixed
- Flickering keyboard issue when creating habit on mobile
- Flickering keyboard issue when creating measurable data type on mobile
- Flickering keyboard issue when creating dashboard data type on mobile

## [0.8.187] - 2022-10-29
### Changed:
- Flutter upgrade to 3.3.6

## [0.8.186] - 2022-10-29
### Changed:
- Improved habit completion add icon

## [0.8.185] - 2022-10-28
### Changed:
- Simplify sync outbox, remove faulty network connected check
- Add sync inbox tests for decrypting and writing image and audio files

## [0.8.184] - 2022-10-28
### Fixed:
- Update habits range after midnight

## [0.8.183] - 2022-10-27
### Added:
- Autocomplete habits data structure
- Skipping habit doesn't break the chain

## [0.8.182] - 2022-10-24
### Changed:
- Screenshot exception logging
- Retry IMAP actions with exponential backoff

## [0.8.181] - 2022-10-23
### Changed:
- Styling: entry icons
- Styling: colors

## [0.8.180] - 2022-10-23
### Changed:
- Move Sync inbox to separate isolate

## [0.8.179] - 2022-10-22
### Changed:
- Simplify sync by reusing IMAP client in one place
- Restart outbox client isolate on network reconnect

## [0.8.178] - 2022-10-21
### Changed:
- Upgraded dependencies
- Count habits total and finished today
- Count habit streaks of three days (up until yesterday)
- Count habit streaks of one week (up until yesterday)
- Sections for longer and shorter streaks

## [0.8.177] - 2022-10-17
### Fixed:
- Bring back index creation in journal database
- Fix habit success indicator width

## [0.8.176] - 2022-10-16
### Fixed:
- "Task not found" when task still loading
- Spacing between habit success indicators

## [0.8.175] - 2022-10-16
### Added:
- Habit completion types success, skip, fail

## [0.8.174] - 2022-10-16
### Changed:
- Removed index creation in JournalDb for now

## [0.8.173] - 2022-10-16
### Changed:
- Improved photo view

## [0.8.172] - 2022-10-16
### Changed:
- Upgraded dependencies
- JournalDb moved to a separate isolate, freeing up CPU resources on the main thread/isolate

## [0.8.171] - 2022-10-13
### Changed:
- Sort habits by show from time, then a-z

### Fixed:
- Time chart didn't include today

## [0.8.170] - 2022-10-12
### Changed:
- Enable isolate support in JournalDb, SyncDb, LoggingDb
- Run SyncDb and LoggingDb in separate isolate (thread)
- Run Sync outbox in isolate to avoid jank

## [0.8.169] - 2022-10-11
### Changed:
- Upgrade Flutter to 3.3.4
- Upgrade dependencies

## [0.8.168] - 2022-10-10
### Changed:
- Entry details header icons

## [0.8.167] - 2022-10-08
### Changed:
- Delayed health import to improve scroll performance

## [0.8.166] - 2022-10-06
### Added:
- Health import for DISTANCE_WALKING_RUNNING

## [0.8.165] - 2022-10-06
### Changed:
- Increase measurement line chart height

### Fixed:
- Alignment of time axis between different types

## [0.8.164] - 2022-10-04
### Added
- Habits definition in Settings
- Add habit chart in dashboard
- Habits tab
- Habits grouped by open/completed
- Localize open/closed headers
- Add show from field

## [0.8.163] - 2022-10-01
### Changed:
- Audio recorder icons in dark mode

## [0.8.162] - 2022-10-01
### Changed:
- Active icons in surveys

## [0.8.161] - 2022-10-01
### Changed:
- Launch background color

## [0.8.160] - 2022-09-30
### Fixed:
- Sleep import on iOS

## [0.8.159] - 2022-09-29
### Added:
- Aggregation by hour in measurables charts

## [0.8.158] - 2022-09-29
### Changed:
- Colors adapted for dark mode
- VU meter in audio recording indicator removed

## [0.8.157] - 2022-09-29
### Changed:
- Segmented control for dashboard time span
- Style: dark mode
- Style: improved segmented control for dashboard time span

## [0.8.156] - 2022-09-26
### Changed:
- Charts hidden in journal cards
- New bottom navigation
- Measurement capture dialog style
- AppBar style with leading text
- Splash screen color
- Improved add icons in tasks, dashboards, measurables
- Hide audio recording indicator when on recorder page

### Fixed:
- Chart header cut off

## [0.8.155] - 2022-09-25
### Changed:
- Improve filling surveys by using modal_bottom_sheet lib
- Use showCupertinoModalBottomSheet instead of showModalBottomSheet

## [0.8.153] - 2022-09-25
### Fixed:
- Story assignment on mobile

## [0.8.152] - 2022-09-24
### Changed:
- DefinitionCard design
- Design: Settings > Tags
- Design: Settings > Dashboard Management
- Design: Settings > Measurables
- Consolidated settings cards

### Fixed:
- Health chart legend on select

## [0.8.151] - 2022-09-22
### Changed:
- Style: Inconsolata as monospace font
- New color theme in journal and tasks list
- New color theme in entry details

## [0.8.150] - 2022-09-20
### Fix:
- Bar overlapping domain axis

### Changed:
- Design tweaks in measurement capture
- Design tweaks survey capture
- Replace Lato font
- Empty dashboards page with how to use button
- Bar chart style

## [0.8.149] - 2022-09-18
### Added:
- Detect when desktop app is resumed in Sync

## [0.8.148] - 2022-09-18
### Changed:
- Dashboard chart header tweaks
- No hover color on IconButton elements on desktop
- Chart colors

## [0.8.147] - 2022-09-18
### Changed:
- Sync Conflicts layout
- Sync Conflicts resolution UI

## [0.8.146] - 2022-09-17
### Changed:
- Style: Icon alignment in Settings > Advanced
- Debug logging for Sync
- Style: barrier color in new measurement modal
- Style: add measurement icon
- Style: floating action button color
- Style: white app bar in dashboards
- Style: app bar redesign
- Style: remaining charts

## [0.8.145] - 2022-09-15
### Changed:
- Styling: Settings layout
- Styling: hover in Settings
- Styling: measurables chart
- Styling: survey chart
- Styling: health chart
- Styling: BP chart
- Styling: BMI chart

## [0.8.144] - 2022-09-13
### Changed:
- Move version and entry count to about page

## [0.8.143] - 2022-09-13
### Changed:
- Typography: use PlusJakartaSans in Settings
- Typography: use PlusJakartaSans in Settings > Tags
- Typography: use PlusJakartaSans in Settings > Dashboards
- Typography: use PlusJakartaSans in Settings > Advanced
- Typography: use PlusJakartaSans in Settings > Advanced > Maintenance
- Typography: use PlusJakartaSans in Settings > Config Flags
- Typography: use PlusJakartaSans in app bar
- Typography: use PlusJakartaSans in bottom navigation
- Hide icons in Settings
- White background in Settings
- White background in Dashboards List
- White background in Dashboards
- Chart title in black
- Move app version to Settings > About

## [0.8.142] - 2022-09-13
### Changed:
- Upgraded dependencies
- Assign story tag to comment entries as well

### Added:
- More tests for persistence logic

## [0.8.141] - 2022-09-12
### Changed:
- Flutter version upgrade
- Upgraded dependencies
- Sync reliability improvements

## [0.8.140] - 2022-09-08
### Fixed:
- Bottom sheet for tag selection overlaying the bottom nav bar

## [0.8.139] - 2022-09-07
### Changed:
- Upgrade dependencies

## [0.8.138] - 2022-09-06
### Added:
- Tests for surveys

## [0.8.137] - 2022-09-06
### Changed:
- Navigation: tap on open tab navigates to tab root

## [0.8.136] - 2022-09-05
### Changed:
- Upgraded dependencies
- Added tests for Audio Player widget
- Added tests for Audio Recorder widget

## [0.8.134] - 2022-09-02
### Changed:
- Upgraded dependencies
- Capture text with adding a measurement

## [0.8.133] - 2022-08-29
### Changed:
- Allow adding text in measurable entries
- Allow adding text in survey entries

## [0.8.132] - 2022-08-26
### Changed:
- Measurements captured in alert dialog, not modal
- Cross-tab navigation
- Navigate to dashboard from settings

## [0.8.131] - 2022-08-24
### Changed:
- Plus icon for adding measurement from dashboard instead of double tab
- Plus icon for filling survey from dashboard instead of double tab

## [0.8.130] - 2022-08-23
### Added:
- New navigation using beamer (in progress, available via config flag)
- Navigation in Settings > Tags using beamer
- Navigation in Settings > Dashboards using beamer
- Navigation in Settings > Measurables using beamer
- Navigation in Settings > Config Flags using beamer
- Navigation in Settings > Health Import using beamer
- Navigation in Settings > Advanced using beamer
- Navigation in Journal using beamer
- Navigation in Tasks using beamer
- Navigation in Dashboards using beamer

## [0.8.129] - 2022-08-17
### Changed:
- Copy SyncConfig to clipboard, encrypted with random one-time password
- Paste encrypted SyncConfig from clipboard & decrypt with one-time password

## [0.8.128] - 2022-08-11
### Fixed:
- Text wrap in config flags on small screen (e.g. iPhone 12 mini)

## [0.8.127] - 2022-08-11
### Changed:
- Navbar changed to Salomon style

### Fixed:
- Navigation glitch where the bottom nav bar was moving
- Error handling when page does not exist

## [0.8.126] - 2022-08-08
### Changed:
- Updated dependencies
- Inline code style in editor

## [0.8.124] - 2022-08-08
### Changed:
- Move dashboards page to left
- Change dashboards header
- Whitespace tweaks

## [0.8.124] - 2022-08-06
### Changed:
- Add toggle icon button for map visibility in entry header
- Remove map toggle in entry footer

## [0.8.123] - 2022-08-05
### Changed:
- Save running timer progress

## [0.8.122] - 2022-08-02
### Changed:
- Entry details layout

## [0.8.120] - 2022-08-02
### Fixed
- Crash in tags modal due to wrong context

## [0.8.120] - 2022-08-01
### Changed:
- Time record icon only on text entries

## [0.8.119] - 2022-07-30
### Changed:
- Decoupling of PersistenceLogic and widgets
- Decoupling of JournalDb and widgets

## [0.8.117] - 2022-07-28
### Changed:
- Show unsaved state after changing task title
- Save entries when navigating away
- Number format for selected measurement in chart
- Only show dashboard slideshow icon when multiple dashboards are defined
- Display more obvious entry save button
- Spacing in entry header

## [0.8.116] - 2022-07-26
### Fix:
- Build errors

## [0.8.115] - 2022-07-25
### Fixed:
- Sync resetting its own offset
- Polling

## [0.8.114] - 2022-07-21
### Added:
- Slideshow for dashboards

## [0.8.113] - 2022-07-20
### Added:
- Count duration for entries spanning multiple days for each individual day
- Weekly aggregation in story time charts

## [0.8.112] - 2022-07-19
### Changed:
- Improved query for substring matched stories

## [0.8.111] - 2022-07-17
### Changed:
- Time format hh:mm:ss in time charts for aggregate of selected day
- Time format hh:mm:ss in workout charts for aggregate of selected day

## [0.8.110] - 2022-07-15
### Added:
- Logging in sync

## [0.8.109] - 2022-07-15
### Changed:
- Improved whitespace in DateTime modal on mobile

## [0.8.108] - 2022-07-15
### Added:
- Wildcard matches in story charts

## [0.8.107] - 2022-07-14
### Fixed:
- Close photo button closes fullscreen photo

### Changed:
- Better close photo icon, in white with black shadow

## [0.8.106] - 2022-07-14
### Fixed:
- Duration display as absolute value

## [0.8.105] - 2022-07-14
### Added:
- Confirmation dialog when unlinking entry

## [0.8.104] - 2022-07-13
### Changed:
- Improved logging in sync

## [0.8.103] - 2022-07-13
### Changed:
- Improved time chart

## [0.8.102] - 2022-07-12
### Changed:
- Simplified & cleaner Inbox Service

## [0.8.101] - 2022-07-11
### Changed:
- Show duration

## [0.8.100] - 2022-07-10
### Changed:
- Show single dashboard directly without dashboards list page

## [0.8.99] - 2022-07-10
### Changed:
- Show bottom navigation bar in dashboard page

## [0.8.98] - 2022-07-10
### Fixed:
- Dashboard save button not appearing after reordering items

## [0.8.97] - 2022-07-10
### Changed:
- Simplified & cleaner Outbox Service

## [0.8.96] - 2022-07-08
### Changed:
- Longer IMAP timeouts for better support of flaky connections
- Fix toggle outbound sync in outbox monitor
- Config flags for enabling inbox and outbox
- Config flag for allowing invalid certificate (useful for testing, e.g. with [Toxiproxy](https://github.com/Shopify/toxiproxy))

### Added:
- Tests for measurement in journal
- Tests for health entry in journal
- Tests for dashboards measurement charts
- Tests for dashboards health charts
- Tests for dashboards workout charts
- Tests for logging page

## [0.8.95] - 2022-07-07
### Changed:
- Refactoring (no UI changes)

## [0.8.94] - 2022-07-07
### Changed:
- Upgraded dependencies

## [0.8.93] - 2022-07-06
### Added:
- Tests for journal page
- Tests for tasks page

## [0.8.92] - 2022-07-06
### Added:
- Tests for database and persistence logic

## [0.8.91] - 2022-07-05
### Added:
- Persistence of themes as JSON

## [0.8.90] - 2022-07-04
### Changed:
-Dependencies (no UI changes)

## [0.8.89] - 2022-07-04
### Added:
- Refactor theme management for color picker
- Config flag for color picker on desktop
- Basic theming config with color pickers on desktop
- Show previews and tap to expand/show picker in theme config
- Toggle theme config display via menu

## [0.8.88] - 2022-07-01
### Fixed:
- Hex color strings now parsed like CSS colors

## [0.8.87] - 2022-07-01
### Fixed:
- Timezone for notification

## [0.8.86] - 2022-07-01
### Added:
- Support for inline code in editor
- Support for strikethrough inline style in editor

## [0.8.85] - 2022-06-30
### Changed:
- FadeIn animation on new measurement page

### Fixed:
- Navigation pop after changing entry date
- Navigation pop after adding measurement
- Entry text color in for creating measurable

## [0.8.83] - 2022-06-30
### Fixed:
- Remove notifications for deleted dashboards

## [0.8.82] - 2022-06-29
### Added:
- Bright ☀️ color scheme with config flag
- Change️ color scheme from menu on desktop
- Add loading screen for dashboards, with animation

## [0.8.80] - 2022-06-27
### Changed:
- Use AppRouter mock in tests (no UI changes)

## [0.8.79] - 2022-06-27
### Changed:
- Dependency injection for SecureStorage (no UI changes)

## [0.8.78] - 2022-06-25
### Changed:
- Improve dashboards search width on desktop

## [0.8.78] - 2022-06-24
### Changed:
- Theme colors
- Whitespace in task card

## [0.8.77] - 2022-06-24
### Added:
- Tests for Settings (no UI changes)

## [0.8.76] - 2022-06-24
### Changed:
- Apple developer account for debug mode, for reasons ( ͡ಠ ʖ̯ ͡ಠ)
- Should not affect the build pipeline, current version simply tests the pipeline

## [0.8.75] - 2022-06-24
### Added:
- Tests for measurables detail page

## [0.8.74] - 2022-06-24
### Added:
- Faster measurement entry on desktop with autofocus and Cmd-S hotkey
- Widget tests for new measurement page (no UI changes)

## [0.8.73] - 2022-06-23
### Added:
- Widget tests for dashboard definition page (no UI changes)

## [0.8.72] - 2022-06-23
### Added:
- Link from new measurement page to respective measurable definition

## [0.8.71] - 2022-06-23
### Fixed:
- Line wrap for long title and description in dashboard definition card
- Line wrap for long description in dashboard page
- Line wrap for long title and description in measurement card
- Line wrap for long title in dashboard chart header

## [0.8.70] - 2022-06-23
### Changed:
- Show private status in dashboard card
- Show daily review time in dashboard card

## [0.8.69] - 2022-06-23
### Changed:
- Show unit name in measurement type card
- Show aggregation type in measurement type card

## [0.8.68] - 2022-06-23
### Changed:
- Leading insights icon in measurement card removed

## [0.8.67] - 2022-06-23
### Changed:
- Outbox monitor layout
- Outbox badge now displays larger counts

## [0.8.66] - 2022-06-21
### Added:
- Tests for Sync assistant widgets (no UI changes)
- Tests for OutboxCubit (no UI changes)

## [0.8.65] - 2022-06-20
### Changed:
- Remove aggregation label in chart when aggregation none
- Use aggregation none as default

## [0.8.64] - 2022-06-19
### Added:
- Tests for Sync assistant logic (no UI changes)
- Tests for Sync assistant widgets (no UI changes)

## [0.8.62] - 2022-06-18
### Changed:
- Guard Save button in new measurement by validation

## [0.8.61] - 2022-06-17
### Fixed:
- Saving tags and other form data

## [0.8.60] - 2022-06-17
### Changed:
- Fill survey directly from dashboard

## [0.8.59] - 2022-06-17
### Fixed:
- Save dashboard without daily review time filled out

## [0.8.58] - 2022-06-17
### Added:
- Workout type swimming

## [0.8.57] - 2022-06-16
### Fixed:
- Grey boxes in flagged entries that do not have text yet
- Header margin on mobile

## [0.8.56] - 2022-06-16
### Fixed:
- App bar when creating new entries

## [0.8.55] - 2022-06-16
### Changed:
- Improvements in Sync Assistant
- Prevent progression in Sync Assistant when not allowed

## [0.8.54] - 2022-06-14
### Added:
- Check valid mail account in sync assistant
- Check saved IMAP config in sync assistant

## [0.8.53] - 2022-06-13
### Added:
- App bar with save button in new measurement page
- Ignore chart interaction on journal card

## [0.8.52] - 2022-06-13
### Changed:
- Dev playground removed, not useful

## [0.8.51] - 2022-06-13
### Added:
- Search field for tasks in full width
- Search field for measurables in full width

## [0.8.50] - 2022-06-13
### Changed:
- Indicate unsaved changes on tag edit page
- Indicate unsaved changes on measurable data type edit page
- Indicate unsaved changes on dashboard edit page

## [0.8.49] - 2022-06-13
### Fixed:
- Timezone name on Linux

## [0.8.48] - 2022-06-13
### Fixed:
- Location on Linux

## [0.8.47] - 2022-06-12
### Changed:
- Improve first-time user experience for measurables

## [0.8.46] - 2022-06-12
### Changed:
- Improve layout of health data entry
- Improve layout of measurable data entry

## [0.8.45] - 2022-06-12
### Fixed:
- Sync of entities without vector clock
- Dashboards sorted alphabetically

### Changed:
- Optional description field in dashboard definitions
- Optional description and unit fields in measurable definitions

### Added:
- Maintenance task for reprocessing messages

## [0.8.44] - 2022-06-12
### Changed:
- Layout improvements in empty dashboards page

## [0.8.43] - 2022-06-12
### Changed:
- Allow dashboards with the same name
- Add maintenance task for purging deleted items

## [0.8.42] - 2022-06-11
### Changed:
- Auto-sizing text in Sync Assistant

## [0.8.41] - 2022-06-10
### Changed:
- Default IMAP folder for sync

## [0.8.40] - 2022-06-09
### Fixed:
- No health import on desktop

## [0.8.39] - 2022-06-09
### Changed:
- Ignore foreign messages in IMAP folder

## [0.8.38] - 2022-06-09
### Fixed:
- Romanian language support in forms

## [0.8.37] - 2022-06-09
### Changed
- Improved icons

## [0.8.36] - 2022-06-08
### Added:
- Screenshot from desktop menu

## [0.8.35] - 2022-06-08
### Changed:
- Save screenshots on desktop as JPG
- Improved icons

## [0.8.34] - 2022-06-08
### Added:
- French translation

### Changed:
- Improved Sync Assistant
- Trim fields in email config
- Label for Sync enable/disable

## [0.8.32] - 2022-06-07
### Added:
- Tooltips for circular add actions
- Fix hover UX

## [0.8.32] - 2022-06-07
### Fixed:
- Navigation issue

## [0.8.31] - 2022-06-04
### Changed:
- Define aggregation type for dashboard item

## [0.8.29] - 2022-06-02
### Added:
- Empty Dashboards instructions

### Changed:
- Delete dashboards confirmation in red
- Save and View button in dashboard definition removed

## [0.8.29] - 2022-06-01
### Added:
- Beginnings of a Manual

### Removed:
- Default measurable types

### Added:
- AppBars with matching titles for dashboard and measurable data type management

## [0.8.27] - 2022-06-01
### Changed:
- Improved UI in header

## [0.8.26] - 2022-05-31
### Fixed:
- Top margin for iPhone notch

## [0.8.25] - 2022-05-31
### Changed:
- Hide tasks tab unless config flag is set

## [0.8.24] - 2022-05-31
### Changed:
- Improve Search Header in Tasks

## [0.8.23] - 2022-05-31
### Changed:
- Improve Search Header in Journal

## [0.8.22] - 2022-05-31
### Changed:
- Show open, groomed & in-progress tasks by default
- Remove AppBar in Journal
- Show all types in Journal by default

## [0.8.20] - 2022-05-28
### Fixed:
- Bring back workout import

## [0.8.20] - 2022-05-28
### Fixed:
- Editor crashes

## [0.8.19] - 2022-05-25
### Added:
- Romanian localization

## [0.8.17] - 2022-05-22
### Fixed:
- Intra-day steps import

## [0.8.16] - 2022-05-22
### Added:
- Dashboard not found header, this becomes relevant after deleting a dashboard

## [0.8.15] - 2022-05-21
### Changed:
- Activity imports up to now

## [0.8.14] - 2022-05-21
### Fixed:
- Dashboard creation

## [0.8.12] - 2022-05-20
### Changed:
- Disable file sharing on iOS

## [0.8.11] - 2022-05-19
### Added:
- Persistence of editor drafts

## [0.8.9] - 2022-05-18
### Changed:
- Add task header

## [0.8.7] - 2022-05-17
### Changed:
- Add task stats header for task list

## [0.8.5] - 2022-05-16
### Changed:
- GitHub release for Linux from GitHub Action

## [0.8.4] - 2022-05-16
### Changed:
- Faster screenshots when no location in cache

## [0.8.3] - 2022-05-16
### Changed:
- Bottom Navigation Bar hidden in entry details
- Bottom Navigation Bar hidden in sync assistant
- Bottom Navigation Bar hidden in logging

## [0.8.2] - 2022-05-16
### Changed:
- Bottom Navigation Bar hidden in dashboards
- Dashboard title moved to app bar

## [0.8.1] - 2022-05-15
### Changed:
- Upgrade to Flutter 3.0.0

## [0.7.38] - 2022-05-12
### Added:
- Min and Max weight in BMI chart range
- Only allow charts to shift back, not forward

## [0.7.37] - 2022-05-11
### Added:
- Disable panning while zoom is ongoing

## [0.7.36] - 2022-05-11
### Added:
- Horizontal Chart Zoom
- Horizontal Chart Panning

## [0.7.33] - 2022-05-11
### Added:
- Hide inactive dashboards

## [0.7.32] - 2022-05-11
### Added:
- Inherit private status from linked

## [0.7.31] - 2022-05-11
### Added:
- Dark keyboard on iOS

## [0.7.30] - 2022-05-11
### Fixed:
- Zero wait for location on entry create, will be added later when available

## [0.7.29] - 2022-05-10
### Fixed:
- Tabs routes are now restored on application restart

## [0.7.28] - 2022-05-05

### Fixed:
- Audio playback for multiple recordings in list of linked entries was not
  working previously

## [0.7.22] - 2022-04-28
### Added:
- Haptic feedback for setting/unsetting starred/private/flagged statuses

## [0.7.19] - 2022-04-28
### Fixed:
- Footer spacing on mobile

## [0.7.18] - 2022-04-27
### Added:
- Share image and audio files from share button in entry footer

### Changed:
- Removed audio file sharing from audio player

## [0.7.17] - 2022-04-27
### Added:
- Share audio recordings

## [0.7.16] - 2022-04-27
### Added:
- No autofocus on task text

## [0.7.15] - 2022-04-27
### Added:
- Adaptive max height for images

## [0.7.14] - 2022-04-27
### Fixed:
- Code signing on macOS leading to crash on startup

## [0.7.13] - 2022-04-26
### Fixed:
- No sync calls when not configured

## [0.7.11] - 2022-04-26
### Fixed:
- Linux entry persistence crash fix

## [0.7.10] - 2022-04-26
### Added:
- Sync settings: hide sensitive info
- Sync settings: select IMAP folder
- Styling: shadow on navigation bar
- Sync assistant

### Changed:
- Task form styling
- Unfocus on save only on mobile
- Sync IMAP messages marked seen
- Sync IMAP messages in lotti_sync folder
- Styling: entry card color

## [0.7.9] - 2022-04-25
### Changed:
- Text color in sync settings
- Unfocus on save
- Entry styling

## [0.7.8] - 2022-04-24
### Added:
- New color scheme
- Text editor in slideshow for faster import

## [0.7.7] - 2022-04-24
### Added:
- Added flutter_image_slideshow

## [0.7.6] - 2022-04-22
### Added:
- Release to TestFlight via fastlane
- Added fastlane-plugin-changelog
- Populating release notes/what to test from CHANGELOG
- Added fastlane match
- Added GitHub Actions setup

## [0.7.5] - 2022-04-21
### Added:
- Added `make` tasks for TestFlight upload
### UI/UX
- Checklist section polish:
  - Clear visual separation for items with subtle rounded backgrounds and hairline borders
  - Increased row padding (H 16, V 8), multi‑line support (up to 4 lines) with fade overflow
  - Checked items use strikethrough with reduced text opacity for faster scanning
  - Swipe‑to‑delete background now clips to the same radius and aligns with row padding
  - Header keeps Edit and Export; Delete remains available while editing just below the header to ensure a reliable tap‑target (follow‑up planned to unify in header)
  - No functional changes to reordering, export/share, or AI suggestions

### Tests
- Added widget tests for checklist visuals (strikethrough on check, row wrapper presence) and suggestion overlay rendering; kept behavioural tests green.
