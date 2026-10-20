---
type: Feature Module
title: AI settings UI
description: "One CustomScrollView with a pinned title strip, scrolling header controls and tab bar, three tabs over one filter model, and a first-run path when no provider exists."
resource: ../../../lib/features/ai/ui/settings
tags: [ai, settings, ui, slivers]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-20T12:00:00Z }
stale_after: 2026-12-26
sources:
  - id: runtime-settings
    resource: ../../../lib/features/ai/state/ai_runtime_settings_controller.dart
    title: Runtime and default profile settings controllers
    last_modified: 2026-10-04
  - id: src
    resource: ../../../lib/features/ai/ui/settings
    title: AI settings UI source
    last_modified: 2026-10-07
  - id: routes
    resource: ../../../lib/features/settings/routing/settings_routes.dart
    title: The AI settings leaves and their desktop panels
    last_modified: 2026-10-19
---

The AI settings page renders as **one `CustomScrollView`**. Only the shared
`SettingsPageHeader` title strip is **pinned**; the header controls and the tab
bar scroll with the content.

```dart
CustomScrollView(
  slivers: [
    if (!hideHeader)
      SettingsPageHeader(...),          // shared settings title strip (pinned)
    SliverPadding(                      // search + runtime defaults (scrolls)
      sliver: SliverToBoxAdapter(child: AiSettingsHeaderBar(...)),
    ),
    // zero providers: FTUE banner, tab bar, no-providers card
    if (!hideTabBar)
      SliverToBoxAdapter(               // tab bar (scrolls)
        child: AiSettingsTabBar(...),
      ),
    // per-tab content:
    //   providers -> provider card list (two per row from 700 px)
    //   models    -> filter chips + model list
    //   profiles  -> profile card list (two per row from 700 px)
    SliverToBoxAdapter(                 // clears the bottom nav and the FAB
      child: SizedBox(height: occupiedHeight + step12),
    ),
  ],
)
```

Choosing slivers over a plain list is what keeps a large model catalog smooth and
memory-efficient; pinning only the title strip keeps the reading area large on
short windows, where a pinned header bar plus tab bar would eat most of a phone
screen.

# Desktop panels

On desktop each AI settings leaf mounts `AiSettingsBody` with `hideTabBar: true`
and `hideHeader: true`, and the Providers, Models and Profiles leaves also set
`initialTab`: the sidebar names the tab and the panel breadcrumb replaces the
title strip, so neither the tab bar nor the pinned header renders. The page
re-applies `initialTab` when the sidebar switches leaves, because the
master/detail surface reuses its state.

# Three tabs, one filter model

Providers, models and profiles are tabs over the same header, so search and the
runtime controls stay in one place rather than being repeated per tab. Only the
models tab adds its own filter-chip strip. A per-tab floating add button creates
a provider, model or profile; on the providers tab it opens the provider picker,
which drops its first-run chrome and lists every provider type once the user
has chosen "Don't show again".

# Runtime controls

Below the search field the header carries two device-local controls held by
`AiRuntimeSettingsController`: the agent-wake concurrency (1–8, default 3,
`AI_AGENT_WAKE_CONCURRENCY`) and the default wake cadence for task agents whose
task and category set none (default hourly, `AI_DEFAULT_AGENT_WAKE_CADENCE`). A
change the user makes before the stored values load is not overwritten by the
load.

# Default inference profile

The header includes a profile selector and an explicit “No default profile”
choice. It lists all profiles independently of the active tab/search. A saved
selection follows profile renames; a deleted profile displays the missing-profile
label until the user chooses another or clears it. Failed saves show an error
and retain the last persisted selection. Writes are serialized so rapid choices
cannot persist out of order. If the initial preference read fails, the selector
starts without a selection and remains usable for saving a new default.

The device-local routing contract is in
[profile resolution](profile-resolution.md). `DefaultInferenceProfileController`
publishes a new value only after a successful save; agent setup summaries, the
system-health default model and relationship runtime maintenance watch it and
refresh then.

# The empty state is a first-run path, not a message

When **no providers are configured**, the body swaps to an FTUE banner, the tab
bar — on the page only; the desktop panels hide it, as everywhere — and a
no-providers card with six quick-add provider chips (Gemini, OpenAI, Anthropic,
Alibaba, oMLX, Ollama) rather than an empty list — because at that point the
useful action is connecting a provider, not filtering nothing.

Initial-load and error states render through shared loading and error components
in a `SliverFillRemaining`, so they occupy the viewport rather than collapsing the
scroll extent.

# Form components

The AI configuration forms share a small component set so the provider and model
forms have one visual language, one error-display convention and one
keyboard/screen-reader behaviour. They bridge into
[the design system](../design_system/) rather than restyling controls locally.

Provider and model pickers reuse the shared selection rows described in
[the AI overview](overview.md#configuration-selection-ui), which is what keeps the
standalone pickers and the embedded task-agent setup flow visually identical.
