---
type: Feature Module
title: Settings v2
description: The single declarative settings tree and its two renderings, with real feature pages embedded as headerless bodies.
resource: ../../lib/features/settings_v2
tags: [settings, navigation, tree, declarative]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T12:30:00Z }
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

# Adding a page touches five places

Each one fails differently, and three of the five fail *silently* — which is why
the count is worth stating:

| Place | If you skip it |
|-------|----------------|
| A node in `buildSettingsTree` | The entry does not exist |
| A `(title, desc)` case in `settingsTreeLabelsFor` | The row renders its **raw node id** as its title — deliberate, so authoring mistakes surface instead of crashing |
| A spec in `kSettingsPanels` | The desktop pane silently renders `DefaultPanel` |
| A path in `settingsNodeUrls` | Tapping the node cannot resolve a URL to beam to |
| A pattern in `SettingsLocation.pathPatterns` ([the router](../architecture/navigation.md)) | The URL does not route |

**`settingsNodeUrls` is not universal.** It carries every node that
`pathPatterns` exposes as a navigable destination — `whats-new` is deliberately
absent, because it opens as an in-pane panel and never changes the URL. And a
node id must stay a single tree segment: `sync/matrix-maintenance` keeps a hyphen
where its URL uses a slash, because `sync/matrix/maintenance` would imply a
`sync/matrix` parent that does not exist.

| Surface | Rendering |
|---------|-----------|
| Desktop | Master/detail — a resizable tree column left, an in-pane detail panel right, with **bidirectional URL ↔ tree sync** |
| Mobile | A drill-down where each tree level is its own Beamer page |

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
