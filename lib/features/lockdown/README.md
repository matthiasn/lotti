# Lockdown

Lockdown narrows the desktop app to a single category so it can be shown to an
audience — a demo, a screen share, a talk — without anything outside that
category appearing on screen.

It is a hidden gimmick, not a settings page: nothing in the ordinary UI
mentions it. The Lotti logo at the top of the expanded desktop sidebar is the
one trigger.

## What it does for the user

- **Tap the logo, pick a category.** A small menu lists the active categories.
  Choosing one locks the app down to it.
- **Only that category is left.** The sidebar keeps Tasks and Logbook, both
  filtered to the category. Settings, the day plan, projects, goals, habits,
  insights, people, events, saved filters, the activity panel and the contact
  band are gone, and every category picker offers just the locked category.
- **Tap the logo again to leave.** While locked, the menu names the locked
  category and offers "Exit lockdown". Restarting the app also exits — the
  state is never persisted.

Mobile has no logo and no lockdown; narrowing the desktop window below the
desktop breakpoint shows the ordinary mobile navigation.

## What it owns

The lockdown state (`LockdownState`, a *set* of category ids so a later
multi-category picker needs no model change), its controller, the option list
the logo menu draws from, and the menu's rows.

It does not own the filtering: the journal page controller clamps its category
filter to the lockdown set, the entities cache scopes its category list, and the
desktop shell decides which rail slots survive.

## Where the code lives

```text
lib/features/lockdown/
├── domain/lockdown_state.dart
├── state/lockdown_controller.dart
└── ui/lockdown_logo_menu.dart
```

## How it works

The enforcement points, the reasons the rail is cut rather than filtered, and
the known gaps are in the knowledge bundle:

**→ [knowledge/features/lockdown.md](../../../knowledge/features/lockdown.md)**
