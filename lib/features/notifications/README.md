# Notifications

Notifications are Lotti's durable alerts: an agent has suggestions on a task, a
habit is due, something needs attention.

They are not fire-and-forget system toasts — they are records that survive
restarts and stay consistent across the user's devices.

## What it does for the user

- **Tells the user when something is waiting.** Task suggestions, check-in
  reminders, a goal that has slipped, a day plan that finished in the
  background and newly detected sync conflicts all surface as real
  notifications — and stay in the bell until dealt with.
- **Opens what it is about.** Tapping an alert takes the user to the task,
  the person or the page behind it, whether Lotti is already running or the
  tap is what starts it.
- **Reaches a closed app.** An alert can be armed days or weeks ahead, so the
  operating system delivers it whether or not Lotti is running.
- **Clears everywhere at once.** Dismissing or acting on an alert on one device
  removes it on the others, and it does not come back. Two kinds stay on the
  device they are about — a plan job's outcome and a sync conflict — because
  they are only true there.
- **Retracts itself when it stops being true.** If the agent withdraws its
  suggestions, the alert goes away rather than leading to an empty page.
- **Survives a restart** — and an app update, a reinstall, or an Android
  reboot, all of which drop the operating system's own copy of a pending alarm.
  An alert is stored, not just shown.
- **Stays quiet until asked.** Notifications ship switched off. Until the user
  turns them on in Settings, Lotti neither delivers anything nor asks the
  operating system for permission to.
- **Alerts only about what the user chose.** The Notifications page under
  Preferences has one switch per kind — task suggestions, check-in reminders,
  goal alerts, habit reminders, habits checked off automatically, day plan
  results, sync conflicts, and the task count on the app icon where there is
  one. A kind switched off still shows in the bell; only the alert stops, and
  it stops at once, on every device.
- **Speaks in the agent's words, if allowed.** With the wording switch on, a
  goal or check-in alert takes the words of the banner the agent wrote for it
  instead of a fixed line. Off by default: those words can carry details, and
  an alert shows on the lock screen.

## What it owns

The notification store and repository; the scheduling of alerts, including
re-arming them at startup; the sync of notifications and their lifecycle state;
convergence when devices act in different orders; which surface a given alert
leads to; the tap on the OS alert that takes the user there; which kinds the
user has allowed onto the OS channel at all; and the one way an agent's LLM
tier may touch an alert — re-wording it with its banner's copy.

It does **not** decide when an alert is warranted. Producers own that — the
change-set builder for task suggestions, the relationship agent's deterministic
tier for check-in reminders. What a producer arms an alert *through* is this
module's: one sink contract, one choreography, per-episode identity
(ADR 0061).

## Where the code lives

```text
lib/features/notifications/
├── model/
├── preferences/
├── producer/
├── repository/
├── routing/
├── scheduler/
├── state/
└── ui/
```

Storage is its own database, `notifications.sqlite`. The platform boundary
itself is `lib/services/notification_service.dart`.

## How it works

Why the store is separate, why lifecycle state converges through monotonic
timestamps rather than whole-row last-write-wins, which two rows never leave
the device, what Android needed before it worked at all, why some variants
stay out of the inbox until they are due, how a tap on the OS alert finds its
screen, which kinds the user can switch off and what a switch does at once,
how an agent may re-word an armed alert, and what every producer shares, are
documented in the knowledge bundle:

**→ [knowledge/features/notifications.md](../../../knowledge/features/notifications.md)**
