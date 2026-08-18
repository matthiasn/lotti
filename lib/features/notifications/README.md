# Notifications

Notifications are Lotti's durable alerts: an agent has suggestions on a task, a
habit is due, something needs attention.

They are not fire-and-forget system toasts — they are records that survive
restarts and stay consistent across the user's devices.

## What it does for the user

- **Tells the user when something is waiting.** Task suggestions and check-in
  reminders surface as real notifications.
- **Reaches a closed app.** An alert can be armed days or weeks ahead, so the
  operating system delivers it whether or not Lotti is running.
- **Clears everywhere at once.** Dismissing or acting on an alert on one device
  removes it on the others, and it does not come back.
- **Retracts itself when it stops being true.** If the agent withdraws its
  suggestions, the alert goes away rather than leading to an empty page.
- **Survives a restart** — and an app update, a reinstall, or an Android
  reboot, all of which drop the operating system's own copy of a pending alarm.
  An alert is stored, not just shown.
- **Stays quiet until asked.** Notifications ship switched off. Until the user
  turns them on in Settings, Lotti neither delivers anything nor asks the
  operating system for permission to.

## What it owns

The notification store and repository; the scheduling of alerts, including
re-arming them at startup; the sync of notifications and their lifecycle state;
convergence when devices act in different orders; and which surface a given
alert leads to.

It does **not** decide when an alert is warranted. Producers own that — the
change-set builder for task suggestions, the relationship agent's deterministic
tier for check-in reminders.

## Where the code lives

```text
lib/features/notifications/
├── model/
├── repository/
├── scheduler/
├── state/
└── ui/
```

Storage is its own database, `notifications.sqlite`. The platform boundary
itself is `lib/services/notification_service.dart`.

## How it works

Why the store is separate, why lifecycle state converges through monotonic
timestamps rather than whole-row last-write-wins, what Android needed before it
worked at all, and why some variants stay out of the inbox until they are due,
are documented in the knowledge bundle:

**→ [knowledge/features/notifications.md](../../../knowledge/features/notifications.md)**
