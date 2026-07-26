# User activity

A small feature with an outsized effect: it knows whether the user is currently
busy, and lets background work wait until they are not.

## What it does for the user

- **Keeps the app responsive.** Heavy background work — sending and receiving
  sync's send and receive passes — waits for a pause rather than competing
  with typing and scrolling.
- **Catches up when idle.** As soon as the user stops interacting, queued work
  drains.

There is nothing to configure; it is invisible when it works.

## What it owns

Activity tracking and the idle gate other features await before starting
disruptive work.

## Where the code lives

```text
lib/features/user_activity/
└── state/
```

## How it works

Who waits on the gate, and why it is an awaited gate rather than a boolean check,
are documented in the knowledge bundle:

**→ [knowledge/features/user_activity.md](../../../knowledge/features/user_activity.md)**
