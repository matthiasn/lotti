# ADR 0039: Relationship Check-In Reminders

- Status: Proposed
- Date: 2026-07-22

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
  machinery is a thin producer over existing, tested infrastructure.
- On desktop platforms without OS scheduling, reminders appear only when the
  app runs — consistent with the local-only design, and mitigated by the
  synced inbox (a phone will still alert).
- Wiring `reconcile()` at startup is a behavior change that also revives OS
  alerts for other inbox notification types; it needs its own tests.
- If the app is not opened for a long period on a single-device setup, no
  reminder fires beyond the last scheduled OS notification — an accepted
  cost of having no server (ADR 0037).

## Related

- [ADR 0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md)
- [ADR 0038: Relationship Domain Model](./0038-relationship-domain-model.md)
- [ADR 0027: Wake Notification Propagation and Storm Prevention](./0027-wake-notification-propagation-and-storm-prevention.md)
- [Implementation plan](../implementation_plans/2026-07-22_relationship_management.md)
