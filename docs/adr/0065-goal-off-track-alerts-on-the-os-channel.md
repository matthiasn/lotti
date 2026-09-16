# ADR 0065: Goal Off-Track Alerts on the OS Channel

- Status: Accepted — implemented. `NotificationEntity.goalOffTrack`,
  `GoalOffTrackAlertService` in `lib/features/goals/service/`, and the
  `GoalOffTrackSink` seam in `GoalAgentPhaseA`.
- Date: 2026-09-16

## Context

ADR 0055 made the goal agent's attention channel banner-only and named the
condition for revisiting push: tap routing, and the synced notification inbox
as the substrate. Both now exist — taps open the screen a notification is
about, and every kind arms rows through one producer contract (ADR 0064).
ADR 0059 Decision 4 already took the same step for people: the banner stays
the primary channel, and an OS alert covers the one case a banner cannot —
the device the user is not holding.

A slipped goal is the case the user named: "send a notification when I'm not
meeting my goal". What the banner channel established still governs — quiet
by default, one automatic banner a day, dismissal as data, never a
guilt-trip over a data gap — and an OS alert that ignored any of it would be
the nag that trains people to switch notifications off.

## Decision

1. **A fifth inbox variant, `goalOffTrack`**, linked to the goal *agent* —
   the id the goal detail route, the registers and the banners are all keyed
   by. A tap opens the goal's page, where the progress and the banner both
   are, not the chat. It waits in the inbox until its alert hour like the
   check-in reminder, and unlike the task and habit rows.

2. **The deterministic tier is the producer, on the banner's own predicate.**
   `GoalAgentPhaseA` projects only a *persisted status transition*: into a
   slip — `automaticGoalAdEligible`, i.e. off track, or at risk on the first
   evaluation or with a worsening trend — it arms; out of one it clears.
   An unchanged slip projects nothing, and a fenced write projects nothing.
   The two channels can therefore never disagree about what a slip is, and
   no model is consulted.

3. **The episode is the transition day and the baseline it left.** One row per slip, keyed by the
   evaluation day that saw the transition, so a goal that stays behind is
   alerted once and a later slip is a new episode. Recovery, achievement, a
   data gap, or deletion (the `deleteGoalAgent` cascade) retract the open
   row, which is what cancels the alarm.

4. **The alert fires at the next 09:00 local**, not at the tick. The cadence
   tick runs at 06:00 and a signal-driven tick can run at any hour; neither
   is a time to be told you are behind. The same hour the check-in reminder
   uses, so a morning with both says both at once.

5. **Copy is deterministic and content-minimal**: the goal's title and a
   fixed line, from the ARB catalogs, baked in the arming device's locale.
   Nothing about how far behind, nothing from a check-in — the ADR 0039
   Decision 6 rule, because the copy lands on a lock screen.

## Consequences

- The goal gained an OS channel for four hooks and one call: the producer
  subclass supplies kind, subject, episode key, instant and copy; Phase A
  calls the sink after its transaction. No repository change (ADR 0064's
  promise, kept).
- Older peers cannot decode the new variant and drop the row with a log
  (`UnrecoverableSyncPayloadException`), the documented mixed-fleet rule.
- **A banner dismissal does not cancel an already-armed alert.** "Not today"
  is written to the nudge row, which wakes no goal tick; an alert armed at
  06:00 for 09:00 still fires after an 08:00 dismissal. Wiring the dismissal
  through the sink is a follow-up, recorded in the goals concept.
- Only the deterministic tier speaks. Model-authored alert copy stays out,
  for the lock-screen reason above.

## Non-Goals

- Alerts for at-risk goals that are not worsening, or for insufficient data.
- A recurring "still behind" alert. The episode moves only with the status.
- Per-goal alert settings; the global notifications switch governs, as for
  every kind.

## Related

- [ADR 0055: The Banner-Nudge Attention Channel](./0055-banner-nudge-attention-channel.md) — the banner-only stance this extends
- [ADR 0059: Relationship Agents on the Shared Runtime](./0059-relationship-agent-runtime-and-nudge-generalization.md) — Decision 4, the same step for people
- [ADR 0064: Notification Producers — One Episode Contract](./0064-notification-producers-one-episode-contract.md) — the contract this rides on
- [ADR 0039: Relationship Check-In Reminders](./0039-relationship-check-in-reminders.md) — the content-minimal copy rule
