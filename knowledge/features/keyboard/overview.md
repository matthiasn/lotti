---
type: Feature Module
title: Desktop keyboard commands
description: A typed command layer resolving key combinations against the focused feature scope, shared by shortcuts, the menu bar, the palette and help.
resource: ../../../lib/features/keyboard
tags: [keyboard, commands, desktop, accessibility]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:00:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: ../../../lib/features/keyboard
    title: Desktop keyboard commands source
    last_modified: 2026-07-25
---

The keyboard feature is Lotti's **desktop command layer**. It turns platform key
combinations into typed `AppCommandId` values, resolves those commands against
**the focused feature scope**, and exposes the same command metadata to Flutter
shortcuts, the macOS menu bar, the command palette, and localized help.

**It deliberately does not provide OS-global hotkeys.** Commands exist only while
Lotti is active, and feature handlers exist only while their widgets are mounted.

# One catalog, four consumers

The value of a typed catalog is that a command's binding, label and enabled
predicate are declared **once**. The shortcut handler, the menu-bar item, the
palette row and the help sheet all read the same entry — so a command cannot show
in the palette with one binding and fire with another, and a disabled command
renders disabled everywhere.

# Scopes are mounted, not registered globally

A feature contributes commands through an `AppCommandScope` that lives with its
widgets. When the task list has focus its scope is live; when focus moves to the
detail pane, that scope's commands take over. **Nothing has to deregister on
navigation, because nothing was globally registered.**

Examples live with their features: the
[task list's commands](../tasks/filtering.md), the
[entry editor's save](../journal/detail-and-saving.md), and the settings detail
scaffold's save. Global navigation and task creation are owned by the app shell.
