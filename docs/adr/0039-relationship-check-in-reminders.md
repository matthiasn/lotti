# ADR 0039: Relationship Check-In Reminders

- Status: Accepted, with two decisions superseded — see the amendments below.
  [ADR 0059](./0059-relationship-agent-runtime-and-nudge-generalization.md)
  made the in-app banner dock the *primary* attention channel; this ADR's
  reminders shipped afterwards as plan v2 phase 8, covering the case a banner
  structurally cannot (the app is closed).
- Date: 2026-07-22
- Amended: 2026-08-17 (phase 8 implementation)

## Amendments at implementation time

Two decisions below did not survive contact with the code, and one paragraph
of context was simply stale by the time it was built:

1. **Decision 3's `RelationshipReminderService` producer does not exist, and
   should not.** It proposed an event-driven producer recomputing the next due
   date on check-in save, relationship save and startup. By the time reminders
   were built, `RelationshipAgentPhaseA` already did exactly that — it derives
   the cadence on the daily tick, on every check-in write (via the
   relationship's `affectedIds` token) and on relationship saves, and its
   derivation is the same one the banner and the briefing use. A second
   producer would have been a second source of truth for "when is this person
   due", free to disagree with the banner. The reminder is therefore a
   *projection* of Phase A's verdict: `RelationshipReminderService` implements
   `RelationshipReminderSink` and owns no cadence logic at all.
2. **Decision 4's per-due-date identity is per *episode*, and rows are
   retracted rather than rewritten.** The id derives from
   `(relationshipId, dueDayKey)` as proposed, but the consequence was not
   spelled out: because the three lifecycle marks are monotonic and cannot be
   cleared, a check-in that moves the due day must mint a *new* row and
   retract the old one. Rewriting one row per person would let an August
   dismissal permanently silence September.
3. **The context section's claim that `reconcile()` "is built and tested but
   currently has no production caller" was stale.** It had been removed
   entirely as dead code in #3748 (*chore: remove unused feature APIs*), so
   phase 8 reinstated it rather than wiring it.
4. **Decision 5 overstated platform support.** It claimed iOS, macOS *and*
   Android got OS notifications through `zonedSchedule`. Android never did:
   `InitializationSettings` carried no `android` entry, so the plugin threw
   `ArgumentError` on `initialize`, that throw was swallowed, and the whole
   plugin stayed uninitialised. Phase 8 fixed that separately from the
   relationship feature — see the consequences.

## Context

When a relationship is marked important, Lotti should proactively remind the
user to check in. Per ADR 0037 there is no server, so reminders must be
computed and scheduled entirely on-device.

The app has two notification layers that fit together:

- `NotificationService` (`lib/services/notification_service.dart`) wraps
  `flutter_local_notifications` with timezone-aware `zonedSchedule`. OS
  scheduling works on iOS, macOS, and Android; Windows and Linux are
  skipped. Everything is gated on `enableNotificationsFlag`.
- The synced notification inbox (`lib/features/notifications/`): durable
  `NotificationEntity` rows in `NotificationsDb` that sync over Matrix,
  with `seenAt`/`actedOnAt` lifecycle, an in-app bell, and a
  `NotificationScheduler` that bridges rows to OS notifications using
  stable FNV-1a ids. Its `reconcile()` (re-arm OS alerts after restart) is
  built and tested but currently has no production caller, and the
  `taskOverdue` producer path is similarly dormant.

Habits set the precedent for scheduling without background workers: a
rolling model where saving or completing an entity re-arms the next OS
notification, rather than a periodic job.

## Decision

1. **New inbox variant `NotificationEntity.relationshipCheckIn`** carrying
   `linkedRelationshipId`, `title`, and `body`, alongside the existing
   `taskSuggestion`/`taskOverdue` variants. Reminders are durable inbox rows
   first, OS notifications second.
2. **Deterministic, local eligibility rule.** A reminder is due for a
   relationship iff `important == true`, status is `active`, and
   `now - lastCheckInDate >= checkInCadenceDays` (default 30 when unset).
   The last check-in date is the newest linked check-in's `meta.dateFrom`;
   for a relationship with no linked check-ins yet, the baseline is the
   relationship's own `meta.dateFrom`, so the first reminder fires one
   cadence after tracking starts — marking someone important is itself the
   request to be nudged, so reminders are never suppressed waiting for a
   first check-in. Relationships that are not important never produce
   reminders — the flag is the single consent switch for proactive
   behavior.
3. **Event-driven producer, no background scheduler.** A
   `RelationshipReminderService` recomputes the next due date and
   (re)schedules via `NotificationScheduler`:
   - when a check-in is saved (pushes the next reminder out by one cadence),
   - when a relationship is saved (arming, disarming, or re-cadencing),
   - at app startup via `NotificationScheduler.reconcile()` — which this
     feature finally wires into the launch sequence, fixing the dormant gap
     for all notification types at once.
4. **Stable identity and cross-device convergence.** Notification ids derive
   from the relationship id plus due date (the existing FNV-1a scheme), so
   two devices computing the same reminder converge on one row after sync,
   and acting on a reminder on one device (`actedOnAt`) clears the pending
   alert everywhere via the existing `SyncNotification` path.
5. **Platform behavior.** iOS/macOS/Android get OS notifications through
   `zonedSchedule`. Windows and Linux surface due reminders through the
   in-app inbox bell only, populated at startup reconcile — an accepted
   limitation inherited from `NotificationService`.
6. **Controls.** Globally gated by the existing `enableNotificationsFlag`;
   per-relationship control is the `important` flag and cadence itself.
   Reminder copy is localized and deliberately vague on lock screens
   ("Check in with Anna?" — no interaction details), since notification
   content leaves the app sandbox.

## Consequences

- No new dependencies (no workmanager/background_fetch); the reminder
  machinery is a thin projection over existing, tested infrastructure.
- On desktop platforms without OS scheduling, reminders appear only when the
  app runs — consistent with the local-only design, and mitigated by the
  synced inbox (a phone will still alert).
- Reinstating `reconcile()` at startup is a behavior change that also revives
  OS alerts for other inbox notification types; it has its own tests.
- If the app is not opened for a long period on a single-device setup, no
  reminder fires beyond the last scheduled OS notification — an accepted
  cost of having no server (ADR 0037).
- **The reminder had to fix Android notifications generally.** Adding
  `AndroidInitializationSettings` revives every path that was silently
  discarded — habit reminders, the Daily OS plan-ready banner, sync-conflict
  alerts — which is a much wider behavior change than a relationship feature
  would normally carry. Two deliberate consequences of that: `updateBadge` is
  now explicitly Darwin-only (the same call on Android posts a visible "N
  tasks in progress" notification after every entry write, rather than a
  silent icon count), and scheduling uses `inexactAllowWhileIdle` so Lotti
  never requests `SCHEDULE_EXACT_ALARM`, which Play restricts to alarm and
  calendar apps. A check-in reminder does not need minute precision.
- **The row's copy is baked at write time in the arming device's locale** and
  then syncs verbatim, so a two-device/two-locale setup reads the armer's
  language on both. This knowingly departs from
  [localization.md](../../knowledge/conventions/localization.md)'s
  "persist the facts, compose the sentence at render time": the OS holds the
  alarm for weeks with the app closed, so there is no render moment to compose
  at. It matches what `taskSuggestion` and `taskOverdue` already do.
- **Notification taps still do not route anywhere.** `_deepLinkFor` is now
  variant-aware and emits `/people/<id>`, but nothing consumes the payload:
  `initialize` is called without `onDidReceiveNotificationResponse` and
  nothing calls `getNotificationAppLaunchDetails`. Tapping any Lotti
  notification opens the app at wherever it was. That predates this ADR and is
  its own change.

## Related

- [ADR 0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md)
- [ADR 0038: Relationship Domain Model](./0038-relationship-domain-model.md)
- [ADR 0027: Wake Notification Propagation and Storm Prevention](./0027-wake-notification-propagation-and-storm-prevention.md)
- [ADR 0059: Relationship Agents on the Shared Runtime and the Kind-Agnostic Nudge Substrate](./0059-relationship-agent-runtime-and-nudge-generalization.md) — supersedes the attention-channel choice; keeps the eligibility rule
- [Implementation plan](../implementation_plans/2026-07-22_relationship_management.md)
  (superseded by [v2](../implementation_plans/2026-08-13_relationship_management_v2.md))
