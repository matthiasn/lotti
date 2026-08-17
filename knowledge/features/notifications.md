---
type: Feature Module
title: Synced notifications
description: Durable app-level alerts stored outside the journal, converging across devices through monotonic state timestamps — and the OS delivery boundary they project onto, including what Android needed before it worked at all.
resource: ../../lib/features/notifications
tags: [notifications, sync, convergence]
status: stable
generated: { by: claude-code/opus-5, at: 2026-08-03T09:00:00Z }
stale_after: 2027-03-01
sources:
  - id: src
    resource: ../../lib/features/notifications
    title: Synced notifications source
    last_modified: 2026-08-02
  - id: os-boundary
    resource: ../../lib/services/notification_service.dart
    title: NotificationService — the OS delivery boundary
    last_modified: 2026-08-17
  - id: scheduler
    resource: ../../lib/features/notifications/scheduler/notification_scheduler.dart
    title: NotificationScheduler — rows to OS alarms, and startup reconcile
    last_modified: 2026-08-17
  - id: adr-0039
    resource: ../../docs/adr/0039-relationship-check-in-reminders.md
    title: ADR 0039 — Relationship check-in reminders
    last_modified: 2026-08-17
---

Synced notifications are durable app-level alerts stored **outside the journal
database**. They carry AI and task suggestions across devices, then use
**monotonic state timestamps** to converge when a user dismisses, acts on, or
retracts an alert on any device.

```mermaid
flowchart LR
  Repo["NotificationRepository"] --> DB["NotificationsDb<br/>notifications.sqlite"]
  Repo --> Outbox["OutboxService"]
  Outbox --> Matrix["Matrix sync"]
  Matrix --> Processor["SyncEventProcessor"]
  Processor --> DB
```

# Why a separate database

An alert is not user content. Keeping it out of `db.sqlite` means notification
churn — created, delivered, dismissed, retracted — never competes with journal
reads for the same write lock, and a notification schema change never touches the
primary store.

# Why monotonic state, not last-write-wins on the row

Dismissal is a **state transition**, not a field edit. Two devices can act on the
same alert in different orders; comparing whole rows would let an older
"delivered" overwrite a newer "acted on".

Carrying the state timestamp separately means the lifecycle only ever moves
forward, so the alert leaves the inbox on every device and stays gone.

Each transition is a separate nullable timestamp on the row — `seenAt`,
`actedOnAt`, `deletedAt` — and `_statePatchWouldChange` only lets a patch through
when the field it sets is still null. That is what makes the lifecycle a lattice
rather than a sequence: the three marks are independent, so replaying a
transition is a no-op and reordering two of them converges either way.

The union has three variants — `taskSuggestion`, `taskOverdue` and
`relationshipCheckIn` — and the discriminator strings are the sync wire format,
so renaming one would make every already-synced row of that kind undecodable on
upgrade. A peer too old to know a variant throws in `fromJson`, which
`SyncEventProcessor` turns into `UnrecoverableSyncPayloadException` and skips:
the row is dropped with a log rather than retried forever. There is no
`unknown` fallback variant, unlike the nudge substrate.

```mermaid
stateDiagram-v2
  [*] --> Pending: created — all three timestamps null

  Pending --> Seen: markSeen sets seenAt
  Pending --> ActedOn: suggestion action sets actedOnAt
  Pending --> Retracted: retract sets deletedAt

  Seen --> ActedOn: suggestion action
  ActedOn --> Seen: markSeen
  Seen --> Retracted: retract
  ActedOn --> Retracted: retract

  Seen --> Seen: markSeen again — no-op, returns null
  ActedOn --> ActedOn: repeated suggestion action — no-op
  Retracted --> Retracted: retract again — no-op

  note right of Pending
    Only Pending is schedulable. Any of the
    three marks makes NotificationScheduler
    cancel the OS-level alert, so a row seen
    on the laptop stops buzzing the phone.
  end note

  note right of Retracted
    The marks are not exclusive — a row can
    carry all three. Each is guarded only
    against its own re-application, so even
    a retracted row still accepts a late
    seenAt arriving from another device.
  end note
```

Read the states as *which marks are set*, not as a single-valued status column:
there is no status field, and `Seen --> ActedOn` and `ActedOn --> Seen` are the
same end state reached in either order.

The three marks differ in what they *hide*, not in what they permit:
`actedOnAt` and `deletedAt` both drop a suggestion out of the open set, while
`seenAt` only clears the badge and stops the OS alert.

A no-op returns `null` before touching the vector clock, so it enqueues no
outbox message either — a device re-marking what it already marked produces no
sync traffic at all.

Only a transition that actually changed something advances the vector clock,
enqueues a `notificationStateUpdate`, reschedules and notifies listeners; the
four steps happen inside one `withVcScope` so a failure part-way commits nothing.

Both `notification` and `notificationStateUpdate` are **sequence-tracked**
[sync message families](sync/message-model.md), so a missed transition is a
detectable gap rather than silent divergence.

The scheduler and the platform-plugin boundary live in `lib/services/`, lazily
registered so a sandboxed build does not initialise the plugin until something
actually schedules — see [bootstrap](../architecture/bootstrap-and-di.md).

# Nothing reaches the OS before the config flag says so

`NotificationService` is the only place Lotti talks to the OS notification
system, and every one of its entry points passes through a single gate before
anything crosses the platform channel:

```mermaid
flowchart TD
  Entry["scheduleNotification · scheduleNotificationAt<br/>showNotificationNow"]
  Badge["updateBadge"]
  Badge --> IconBadge{"has an icon badge?<br/>(iOS, macOS)"}
  IconBadge -- "no — Android" --> StopBadge["return before the flag check;<br/>there is nothing to put a count on"]
  IconBadge -- yes --> Platform
  Entry --> Platform{"a platform Lotti notifies on?<br/>(iOS, macOS, Android)"}
  Platform -- "no — Linux, Windows" --> Stop["return; no database read either"]
  Platform -- yes --> Flag{"enable_notifications<br/>config flag on?"}
  Flag -- "no (the shipped default)" --> Stop2["return; badge cleared if one was posted"]
  Flag -- yes --> Ask["_requestPermissions() — once per process<br/>Darwin alert+badge · Android POST_NOTIFICATIONS"]
  Ask --> Post["cancel + show / zonedSchedule"]
```

**The order is the invariant, not an optimisation.** Requesting permission is
what raises the OS "…would like to send you notifications" dialog, so anything
that asks before consulting the flag prompts a user who has switched
notifications off. `enable_notifications` ships **off**, which makes that the
default experience rather than an edge case.

Two things conspired to make the prompt appear during a user's *first task*.
`updateBadge` runs after every entry write, and it is what first resolves the
lazily registered service — so construction and the first gate evaluation both
happen inside that write. `DarwinInitializationSettings` then defaults all three
of `requestAlertPermission`, `requestBadgePermission` and
`requestSoundPermission` to `true`, and the native `initialize` forwards them
straight to `UNUserNotificationCenter.requestAuthorization`; initialisation must
pass all three as `false`, or the prompt arrives before any gate can run. With
every option false the native side returns without calling
`requestAuthorization` at all, so this makes `initialize` silent rather than
merely quieter.

Android's runtime `POST_NOTIFICATIONS` permission is requested from the same
place and for the same reason. Its `initialize` does not ask for anything —
only the icon — so the ordering invariant costs nothing there, but the request
still has to come after the flag rather than at launch.

Permission is requested at most once per process. The OS shows its dialog for
the first request only, so later calls are channel round trips returning a
decision already on file; memoising the *future* rather than a boolean also
collapses concurrent callers into one request.

**A failed request is logged, swallowed, and not memoised.** Both halves are
load-bearing. Asking is best-effort but the callers are not — `createDbEntity`
runs `updateBadge` as post-commit work, and `NotificationRepository` schedules
inside a vector-clock scope that commits only when its body returns, so an
error escaping the request would abort notification creation and every
lifecycle transition. Memoising a *rejected* future would then make that abort
permanent for the life of the process rather than transient.

The badge follows the flag rather than outliving it, and taking it down is
**two calls, not one**. `cancel` removes the delivered record — the "3 tasks in
progress" entry in Notification Center — but on Darwin the number on the icon
is carried by a notification's own `badge` field (`content.badge` natively),
and `removeDeliveredNotifications` does not reset it. Only a `badgeNumber: 0`
post actually clears the icon.

Posting that while notifications are off is not a notification in any sense the
user sees: empty, `presentAlert: false`, and existing only to zero the number.
It also cannot prompt — the dialog comes from `requestAuthorization`, never
from posting — and without authorization it silently does nothing, which is
correct, because then there is no badge either.

The clear is guarded on a flag tracking whether the icon is *known to read
zero*, which starts **false**. It cannot be guarded on the task count, and it
cannot start true: the icon outlives the process that set it, so a run that
inherited a badge from the previous one must still take it down. The guard
bounds the cost at one pair of platform calls per process rather than one pair
per entry write.

```mermaid
stateDiagram-v2
  [*] --> Unknown: process start — the icon may carry a previous run's count

  Unknown --> Zeroed: notifications off — cancel + post badgeNumber 0
  Unknown --> Showing: notifications on, tasks in progress
  Showing --> Zeroed: task count reaches zero, or the flag goes off
  Zeroed --> Showing: tasks in progress again
  Zeroed --> Zeroed: further writes — guarded, no platform call
  Showing --> Showing: count changed — cancel + post the new count
```

`updateBadge` is the only thing that reconciles the icon with the flag, and
outside entry creation nothing else called it — so toggling the flag left the
count on the icon until the user happened to write something.
`setConfigFlagImpl` therefore refreshes the badge when
`enable_notifications` actually changes, next to the `private` hook it already
carries. That is also what makes the permission prompt land at the moment the
user switches notifications on, rather than at some later write. A failure
there is logged and swallowed: the setting the user asked for is already
saved, and a badge refresh that cannot reach the platform is not a reason to
report it as unsaved.

Cancelling is the one thing that stays ungated: removing an alert must keep
working after notifications are switched off.

# Android needed settings before it needed anything else

`InitializationSettings` carried `linux`, `macOS` and `iOS` but no `android`,
and the plugin throws `ArgumentError('Android settings must be set…')` in
exactly that case. Because `_initializePlugin` deliberately swallows its own
failures — a sandboxed flatpak build must stay startable — that throw was
caught, logged, and never surfaced. The result was not a degraded Android
experience but an absent one: the plugin stayed uninitialised, so habit
reminders, the Daily OS plan-ready banner and sync-conflict alerts were all
discarded silently.

Three things follow from switching it on, and none of them are cosmetic:

- **The small icon must be a monochrome drawable.** Android masks it by its
  alpha channel and paints the result white, so `@mipmap/ic_launcher` — 95%
  opaque — renders as a solid white square. `ic_stat_lotti.xml` is the ring
  glyph lifted verbatim out of `brand_logo_light.svg`.
- **The channel's name and description are frozen at first creation.**
  `channelAction` defaults to `createIfNotExists`, so Android stores whatever
  the first notification carried and ignores later posts. They come from the
  ARB catalogs because they are user-visible in system settings, but switching
  the app's language does *not* rename an existing channel — only
  `AndroidNotificationChannelAction.update` would, and some channel properties
  are immutable even then. Resolving that copy also degrades to English rather
  than throwing: it runs inside `NotificationRepository`'s vector-clock scope,
  where an escaping exception would abort the notification row itself.
- **`updateBadge` is Darwin-only, and that is a behavioural guard.** The badge
  is a *number on the icon*, carried by a notification's own `badge` field and
  posted with `presentAlert: false`. Android has no such thing: the same call
  posts a visible "3 tasks in progress" notification after every entry write.
  The early return sits *before* the flag check, because this is not a
  "notifications are off" path — there is simply nothing to put a count on.
- **Scheduling is inexact on purpose.** The exact modes need
  `SCHEDULE_EXACT_ALARM`, which Android 13+ does not grant on install and the
  Play Store accepts only from apps whose core function is alarms or calendars.
  Nothing Lotti schedules is that. `inexactAllowWhileIdle` keeps the half that
  matters — without `allowWhileIdle`, Doze defers the reminder on exactly the
  idle phone it exists for.

The manifest's `ScheduledNotificationReceiver` is what actually posts a
notification when its time arrives; without it `zonedSchedule` accepts the
alarm and nothing is ever shown. `ScheduledNotificationBootReceiver` re-arms
pending alarms after a reboot or an app update.

# Alarms outlive their rows, so startup re-arms them

`schedule` runs only on a write. An OS-level alarm, though, does not survive an
app update, a reinstall or an Android reboot, while the row describing it sits
untouched in `notifications.sqlite`. Nothing reconciled the two, so a reminder
armed weeks ahead silently stopped existing at the OS level.

`NotificationScheduler.reconcile()` closes that at startup, and the query
already filters to unseen/unacted/undeleted rows — so a row dealt with on any
device is never revived. It is called fire-and-forget through
`reconcileScheduledNotifications`, which swallows and logs: a notification
database that cannot be read is not a reason to fail a launch. An empty inbox
costs one indexed query and does **not** materialise the lazily registered
`NotificationService`, which is what keeps the sandboxed-build guarantee above
intact through startup.

**It re-arms only rows that are still in the future**, and the asymmetry is the
whole point. Showing a notification does not mark its row — only `markSeen`,
`actedOnAt` or `deletedAt` do, all of which come from user action in the bell —
and no tap handler is wired, so an OS alert cannot clear itself. Re-announcing
already-due rows would therefore fire a banner for each of them on *every*
launch, permanently, for alerts the user can already see in the inbox on the
device in their hand. A due row needs no alarm; a future one is the only thing
standing between a closed app and a missed reminder.

# Where a notification leads

`_deepLinkFor` switches over the union rather than reading the shared
`linkedEntityId` getter. Every variant answers that getter, so reading it and
appending `/tasks/` silently produced a dead route for anything that was not a
task — which is what happened the moment a second entity kind got a
notification. The same trap exists in the bell, where `_InboxRow` routes
through `onSelectEntry` with the whole entity for the same reason.

**The payload is still not consumed anywhere.** `initialize` is called without
`onDidReceiveNotificationResponse`, and nothing calls
`getNotificationAppLaunchDetails`, so tapping an OS notification opens the app
wherever it was. The deep links are correct and inert, on every platform.

# Not every variant may surface before it is due

`inboxNotificationsProvider` concatenates due rows *and* upcoming ones. That is
right for the task variants, which are written with `scheduledFor` = now and
only land in the upcoming set through clock skew between synced devices —
hiding them would make a suggestion vanish until the local clock caught up.

It is wrong for a check-in reminder, which is armed a whole cadence ahead
precisely so the OS alarm exists before the app closes. Surfacing it on arrival
would park "Check in with Anna?" in the bell for the entire cadence, turning a
once-per-episode nudge into the ambient noise the banner channel was chosen
over an inbox to avoid. `showsBeforeScheduledTime` is the per-variant gate, and
it is exhaustive over the union so a new variant has to make the choice rather
than inherit one.

# Copy is baked, not composed

A notification row carries its own `title` and `body`, written in the arming
device's locale and then synced verbatim — so a two-device, two-locale setup
reads the armer's language on both.

This knowingly departs from [localization](../conventions/localization.md)'s
rule to persist structured facts and compose the sentence at render time. The
reason is that there is no render moment: the OS holds the alarm for weeks with
the app closed, and what it will show has to be a string by then. All three
variants do this.
