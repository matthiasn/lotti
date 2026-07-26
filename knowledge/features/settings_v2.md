---
type: Feature Module
title: Settings v2
description: The single declarative settings tree and its two renderings, with real feature pages embedded as headerless bodies.
resource: ../../lib/features/settings_v2
tags: [settings, navigation, tree, declarative]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T16:00:00Z }
stale_after: 2027-03-08
sources:
  - id: src
    resource: ../../lib/features/settings_v2
    title: Settings v2 source
    last_modified: 2026-07-26
---

`settings_v2` is **the single declarative source of truth for the settings menu
and its navigation chrome**. It replaced the old hand-maintained per-platform
lists: the entire menu is declared once as a flag-gated tree
(`buildSettingsTree`), rendered two ways.

The name is not a migration in progress. `settings_v2` **defines** the tree and
renders the desktop tree-nav; [`settings`](settings.md) is the **shell** that
turns a URL into pages and hosts the editor kit. Both are current.

# Adding a page touches six places

Each one fails differently, and four of the six fail *silently* — which is why the
count is worth stating:

| Place | If you skip it |
|-------|----------------|
| A node in `buildSettingsTree` | The entry does not exist |
| A `(title, desc)` case in `settingsTreeLabelsFor` | The row renders its **raw node id** as its title — deliberate, so authoring mistakes surface instead of crashing |
| A spec in `kSettingsPanels` | The desktop pane silently renders `DefaultPanel` |
| A path in `settingsNodeUrls` | `pathToBeamUrl` falls back to `/settings`, so the row goes nowhere |
| A pattern in `SettingsLocation.pathPatterns` | The URL does not route at all |
| A branch in `SettingsLocation.buildPages` | The URL routes to **nothing** — this happened: `/settings/maintenance` was an advertised pattern with no page behind it, and the location now carries a legacy alias to keep those bookmarks working |

The last two are separate sites, not one step. A pattern without a page is a
blank destination that looks routable.

# `settingsNodeUrls` is a subset, on purpose and by accident

Five nodes have no entry, for three different reasons:

| Node | Why |
|------|-----|
| `manual` | Carries `SettingsNodeAction.openManual` and leaves the app. No route is wanted. |
| `whats-new` | Mobile taps open `WhatsNewModal` from `handleSettingsNodeTap`. **Its declared `panel: 'whats-new'` has no entry in `kSettingsPanels`**, so a desktop selection would fall through to `DefaultPanel` — the in-code comment calling it an in-pane panel is optimistic. |
| `ai/providers`, `ai/models`, `ai/usage` | These *do* have desktop panels, but no URL — so the rows are inert on mobile and `pathToBeamUrl` falls back to `/settings`. That one is an accident, not a design. |

A node id must also stay a single tree segment: `sync/matrix-maintenance` keeps a
hyphen where its URL uses a slash, because `sync/matrix/maintenance` would imply a
`sync/matrix` parent that does not exist.

# Panels embed real pages

Leaf panels embed **the real feature pages** — which still physically live in
`features/settings/`, `features/ai/`, `features/agents/`, `features/sync/`,
`features/categories/`, `features/labels/` — as **headerless `*Body` widgets**.

That is the mechanism that keeps one menu over many owners: this feature owns
structure and chrome, each feature keeps its own page, and neither has to know how
the other is laid out. A page gains its header from whichever shell mounts it.

# Why one tree matters

Before this, mobile and desktop each carried their own list, so a new settings
page had to be added twice and the two drifted. With one flag-gated tree, **the
two surfaces cannot disagree** about which settings exist, how they are grouped,
or which flags gate them.

See [settings](settings.md) for the shell that consumes this tree and the shared
list/detail editor kit.
