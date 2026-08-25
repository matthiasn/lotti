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

# A branch can be added without moving a single URL

Grouping is a **tree-shape** change, not a routing change. `definitions` and
`preferences` were both introduced by renaming their leaves' ids into the branch
namespace (`theming` → `preferences/theming`) while leaving the `settingsNodeUrls`
value untouched — so `/settings/theming` still routes exactly where it did, and
every shipped deep link, what's-new entry and manual page keeps resolving.

A leaf can even move *between* branches this way: `advanced/animations` became
`preferences/animations` and kept answering on `/settings/advanced/animations`.

Three properties make that safe, and all three are load-bearing:

- **`beamUrlToPath` is a greedy longest-prefix walk over URLs, not a path
  parser.** It never assumes the URL shape mirrors the tree, so a one-segment URL
  resolving to a two-segment tree path is ordinary, not a special case.
- **Panel ids are a third namespace**, and independent of both. A leaf that
  merely changed branch keeps its key — `preferences/theming` still declares
  `panel: 'theming'` — so `kSettingsPanels` needed no entry and the detail pane
  needed no change. A key is only worth renaming when it *names* the branch the
  leaf left, as `advanced-animations` did; it became `preferences-animations`,
  which is safe precisely because panel ids are internal and carry no
  deep-link value. The rule the two cases share: rename for honesty, never for
  symmetry.
- **Mobile matches the hub on the leaf URLs.** `_inPreferencesBranch` (and
  `_inDefinitionsBranch` before it) lists those URLs explicitly, which is what
  keeps the hub in the page stack beneath the leaf so a back tap walks up one
  level instead of jumping to the Settings root.

The last point is where a moved leaf can bite. `_inAdvancedBranch` matches the
whole `/settings/advanced/` prefix, so it would claim `animations` — a page that
is no longer in that branch. It therefore starts with
`!_inPreferencesBranch(path)`: **the tree decides the hub, the URL never does.**
Any future leaf that keeps a URL under another branch's prefix needs the same
guard.

The cost is that the URL list lives in two files — `settingsNodeUrls` and the
`_*LeafPaths` constant in `settings_location.dart`. Adding a leaf to such a branch
means editing both, or the page stack silently loses its hub.

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
