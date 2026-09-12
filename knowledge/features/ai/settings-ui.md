---
type: Feature Module
title: AI settings UI
description: "A single scrolling CustomScrollView with nothing pinned, three tabs over one filter model, and a first-run path when no provider exists."
resource: ../../../lib/features/ai/ui/settings
tags: [ai, settings, ui, slivers]
status: stable
generated: { by: codex/gpt-6, at: 2026-09-12T20:00:00Z }
stale_after: 2026-10-19
sources:
  - id: runtime-settings
    resource: ../../../lib/features/ai/state/ai_runtime_settings_controller.dart
    title: Runtime and default profile settings controllers
    last_modified: 2026-09-12
  - id: src
    resource: ../../../lib/features/ai/ui/settings
    title: AI settings UI source
    last_modified: 2026-09-12
---

The AI settings page renders as **one `CustomScrollView`** in which **nothing is
pinned**: the title strip, the header controls and the tab bar all scroll with the
content.

```dart
CustomScrollView(
  slivers: [
    SettingsPageHeader(...),            // shared settings title strip
    SliverToBoxAdapter(                 // search + runtime defaults (not pinned)
      child: AiSettingsHeaderBar(...),
    ),
    SliverToBoxAdapter(                 // tab bar (not pinned)
      child: AiSettingsTabBar(...),
    ),
    // per-tab content:
    //   providers -> provider card grid
    //   models    -> filter chips + model list
    //   profiles  -> profile card grid
    SliverToBoxAdapter(child: SizedBox(height: 80)),
  ],
)
```

Choosing slivers over a plain list is what keeps a large model catalog smooth and
memory-efficient; choosing *not* to pin anything keeps the reading area maximal on
short windows, where a pinned header plus tab bar would eat most of a phone
screen.

# Three tabs, one filter model

Providers, models and profiles are tabs over the same header, so search and the
runtime controls stay in one place rather than being repeated per tab. Only the
models tab adds its own filter-chip strip.

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
notifies model summaries and relationship maintenance after a successful save.

# The empty state is a first-run path, not a message

When **no providers are configured**, the body swaps to an FTUE banner and a
no-providers card rather than an empty list — because at that point the useful
action is connecting a provider, not filtering nothing.

Initial-load and error states render through shared loading and error components
in a `SliverFillRemaining`, so they occupy the viewport rather than collapsing the
scroll extent.

# Form components

The AI configuration forms share a small component set so providers, models and
prompts have one visual language, one error-display convention and one
keyboard/screen-reader behaviour. They bridge into
[the design system](../design_system/) rather than restyling controls locally.

Provider and model pickers reuse the shared selection rows described in
[the AI overview](overview.md#configuration-selection-ui), which is what keeps the
standalone pickers and the embedded task-agent setup flow visually identical.
