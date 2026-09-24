# ADR 0074: Agent-Worded Alerts Restate an Armed Episode

- Status: Accepted — implemented. `NotificationEpisodeRestater` in
  `lib/classes/notification_producer.dart`,
  `NotificationRepository.restateOpenRows`, `AgentAlertCopy` in
  `lib/features/notifications/producer/`, wired into `GoalAgentWorkflow` and
  `RelationshipAgentWorkflow`; the `notify_agent_copy` switch on the
  Notifications settings page.
- Date: 2026-09-16

## Context

ADR 0072 and ADR 0073 kept model-authored copy off the OS channel: a
notification's words are baked at write time and land on a lock screen, and
ADR 0039 Decision 6 keeps them content-minimal — a name, nothing more.

Meanwhile the goal and relationship agents' LLM tier authors a personalised
banner brief on every escalation wake (`create_goal_ad`,
`create_relationship_ad`), and that wake follows the deterministic tier that
armed an alert for the same subject minutes or days earlier. The alert says
"Anna is due"; the banner, in the agent's voice, says why. The brief for this
work asked for agents that reach the user through notifications, and a fixed
template line is not an agent speaking.

## Decision

1. **The LLM tier may re-word an alert; it may not create one.** A new seam,
   `NotificationEpisodeRestater.restate(subjectId, title:, body:)`, is what
   the workflow gets. It updates the words of a subject's open, not-yet-fired
   rows of the producer's kind and nothing else: no row is minted, a row
   already due keeps the words it fired with, a seen, acted-on or deleted row
   is untouched. `NotificationEpisodeSink` extends it, so every producer is a
   restater; the workflows depend on the narrow interface only.
2. **The words are the banner's.** `AgentAlertCopy.fromBrief` takes the
   persisted, sanitised `NudgeBrief` — headline as title, tagline or else
   call to action as body — fitted to lock-screen room: one line each, 80 and
   140 characters, cut at a word boundary. No new tool argument and no prompt
   change: the alert can never say what the banner does not, and the wake
   pays for no second inference.
3. **Opt-in.** `notify_agent_copy` ships off and is read at the moment of the
   wake. Decision 6's content-minimal rule stands until the user flips the
   switch under Preferences → Notifications, whose row says that the text can
   carry details and shows on the lock screen.
4. **After the transaction, best-effort, for this wake's banner only.** The
   workflow calls the helper once its output transaction has committed, and
   only for a banner this wake created: a re-run banner keeps the alert as it
   is, a fenced or rolled-back wake re-words nothing. Every failure is logged,
   never surfaced as a failed wake — the sink contract of ADR 0072.
5. **Same row, same id, on the wire whole.** The repository bumps `updatedAt`
   and the vector clock, re-schedules under the unchanged OS id — the alarm
   is replaced, not doubled — and enqueues the full row. Peers converge
   last-writer-wins on `updatedAt` (`NotificationMerge`), so the re-worded
   copy overtakes the template whichever order the two events arrive in. A
   device-local row is re-worded but never enqueued. Words that already read
   this way write nothing, so a repeated wake is idempotent.

## Consequences

- Once allowed, the OS alert and the in-app banner read the same, in the
  agent's voice. Until then nothing changes.
- A slip detected at 06:00 is armed with template copy and re-worded by the
  escalation wake minutes later; a check-in reminder armed days ahead is
  re-worded on its due day's wake — both before the 09:00 alarm. A wake that
  runs after the alarm fired leaves it alone, and a peer that receives the
  re-wording after its own alarm fired shows the new words in the bell only:
  the inbound handler re-arms a content update only for a row still ahead.
- The bell shows the re-worded row too; a tap still marks the same row seen.
- Both workflows gain one optional constructor argument; every existing
  construction site is unchanged.

## Non-Goals

- Agent-worded alerts for kinds without an authoring tier: task suggestions,
  habits, plan outcomes, sync conflicts.
- A "write the lock-screen line" tool argument. The banner brief is the
  agent's words already.
- Re-wording an alert that already fired.

## Related

- [ADR 0039: Relationship Check-In Reminders](./0039-relationship-check-in-reminders.md) — Decision 6, the content-minimal rule this makes opt-out
- [ADR 0055: Banner Nudge Attention Channel](./0055-banner-nudge-attention-channel.md) — the banner brief this borrows
- [ADR 0072: Notification Producers, One Episode Contract](./0072-notification-producers-one-episode-contract.md) — the sink this extends
- [ADR 0073: Goal Off-Track Alerts on the OS Channel](./0073-goal-off-track-alerts-on-the-os-channel.md) — the alert this re-words
