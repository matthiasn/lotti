---
type: Feature Module
title: Theming
description: Stored preferences turned into ThemeData, and the one selection that syncs across devices.
resource: ../../../lib/features/theming
tags: [theming, themes, sync]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:00:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: ../../../lib/features/theming
    title: Theming source
    last_modified: 2026-07-25
---

The theming feature turns stored user preferences into actual `ThemeData` for the
light theme, the dark theme and the theme mode — and **syncs the selection across
devices**.

# The sync boundary

Theme selection is one of the few pure-preference values that replicates: a change
enqueues a `SyncMessage.themingSelection`, and an inbound change applies under
last-write-wins.

That is deliberate — a user who picks a theme on their laptop expects their phone
to match, unlike device-local concerns such as pane widths, agent-wake concurrency
or Daily OS category exclusions, which stay put.

# Where the tokens come from

The theming feature builds the app's `ThemeData`; the
[design system](../design_system/) injects its token tree into that theme's
extensions, so `context.designTokens` resolves inside production widgets without
the app adopting the standalone design-system theme wholesale.

The theming **UI** lives under [settings](../settings/); the state machine lives
here.
