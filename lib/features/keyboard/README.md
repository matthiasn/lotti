# Keyboard

Keyboard is Lotti's desktop shortcut layer — the thing that makes the app feel
like a real desktop application rather than a phone app on a big screen.

## What it does for the user

- **Real shortcuts for real actions.** Save, search, refresh, create, navigate —
  bound to the platform's own conventions (Command on macOS, Control elsewhere).
- **Shortcuts that follow focus.** The same key can mean the right thing in the
  task list and in the entry editor, because commands belong to whatever has
  focus.
- **One list of everything available.** The command palette, the macOS menu bar,
  and the in-app help all show the same commands with the same bindings and the
  same enabled state.
- **Nothing hijacked globally.** Shortcuts only exist while Lotti is in front —
  the app never claims a system-wide hotkey.

## What it owns

The command catalog and its typed ids; key-combination resolution; the scope
mechanism features use to contribute commands; and the shared metadata the
palette, menu bar and help surfaces render.

Individual commands live with the features that perform them.

## Where the code lives

```text
lib/features/keyboard/
```

## How it works

The one-catalog-four-consumers model and the mounted-scope resolution are
documented in the knowledge bundle:

**→ [knowledge/features/keyboard.md](../../../knowledge/features/keyboard.md)**
