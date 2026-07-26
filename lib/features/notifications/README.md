# Notifications

Notifications are Lotti's durable alerts: an agent has suggestions on a task, a
habit is due, something needs attention.

They are not fire-and-forget system toasts — they are records that survive
restarts and stay consistent across the user's devices.

## What it does for the user

- **Tells the user when something is waiting.** Task suggestions and reminders
  surface as real notifications.
- **Clears everywhere at once.** Dismissing or acting on an alert on one device
  removes it on the others, and it does not come back.
- **Retracts itself when it stops being true.** If the agent withdraws its
  suggestions, the alert goes away rather than leading to an empty page.
- **Survives a restart.** An alert is stored, not just shown.

## What it owns

The notification store and repository; the scheduling of alerts; the sync of
notifications and their lifecycle state; and convergence when devices act in
different orders.

## Where the code lives

```text
lib/features/notifications/
├── repository/
└── scheduler/
```

Storage is its own database, `notifications.sqlite`.

## How it works

Why the store is separate, and why lifecycle state converges through monotonic
timestamps rather than whole-row last-write-wins, are documented in the knowledge
bundle:

**→ [knowledge/features/notifications.md](../../../knowledge/features/notifications.md)**
