# Settings v2

Settings v2 is the structure behind the Settings menu: one description of what
settings exist, rendered as a navigation tree on wide screens and as a drill-down
on phones.

It exists so a settings page has to be declared once, not twice.

## What it does for the product

- **One menu, two shapes.** The same declared tree becomes a resizable tree column
  with a detail pane on desktop, and a page-per-level drill-down on mobile. They
  cannot disagree about what exists.
- **Flags are part of the structure.** A section gated behind a feature flag is
  simply absent from the tree when the flag is off — no page has to check.
- **The URL and the tree stay in sync.** On desktop, selecting a node updates the
  URL and a deep link selects the node, in both directions.
- **Pages keep their owners.** Each leaf embeds the real feature page as a
  headerless body, so the AI, agents, sync, categories and labels settings stay
  with their features while sharing this chrome.

## What it owns

The settings tree definition; the desktop master/detail layout and its URL sync;
the mobile root, branch and leaf pages; and the shared tree row and shell widgets.

## Where the code lives

```text
lib/features/settings_v2/
├── domain/        # buildSettingsTree — the single source of truth
└── ui/
    ├── mobile/
    └── pages/
```

## How it works

The declarative tree, the two renderings, and the headerless-body embedding
contract are documented in the knowledge bundle:

**→ [knowledge/features/settings_v2.md](../../../knowledge/features/settings_v2.md)**
