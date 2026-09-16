# ADR 0061: Notification Producers — One Episode Contract per Agent Kind

- Status: Accepted — implemented. `NotificationEpisodeSink` in
  `lib/classes/notification_producer.dart`, `NotificationEpisodeProducer` in
  `lib/features/notifications/producer/`, `NotificationRepository.armEpisode`
  and `retractOpenRows`; `RelationshipReminderService` is the first producer
  on the contract.
- Date: 2026-09-16

## Context

OS notifications reach the user from producers that grew separately: the task
agent's change-set builder writes task suggestions, the relationship agent's
deterministic tier arms check-in reminders, the habit auto-completion engine
records what it checked off. Each answered the same four questions on its
own — which row is *this* episode, what to do when the row already exists,
what to do with the episode it supersedes, and what a failure may cost the
caller — and the answers accumulated in `NotificationRepository` as one
create, one retract and one id helper per variant.

Tap routing (the step before this one) made notifications worth producing,
and the next kinds — a goal that has slipped, the deferred channel of ADR
0055 — would each have added another copy of the same choreography.

The relationship reminder (ADR 0039, amendment 1) had already found the right
shape: the tier decides *when*, a sink declared beside the tier's derivation
projects the verdict, the service imports the runtime and never the reverse,
identity is per episode, a superseded episode is retracted, a lapsed one earns
no alarm, and nothing thrown ever reaches the wake. That shape was specific to
one kind only by accident.

## Decision

1. **One sink contract, in `lib/classes`.**
   `NotificationEpisodeSink<TSubject, TDerivation>` has two members of its
   own, `arm({subject, derivation})` and `clearFor(subjectId)`, and since
   ADR 0063 inherits a third, `restate(subjectId, {title, body})`, from
   `NotificationEpisodeRestater`; when a restatement is permitted is that
   ADR's policy, not this contract's. A runtime names
   its own alias beside its derivation — `RelationshipReminderSink` is
   `NotificationEpisodeSink<RelationshipEntry, RelationshipCadenceDerivation>`
   — and imports only `lib/classes`. The one-way direction the amendment
   fixed is now enforced by where the type lives rather than by care.

2. **One choreography, in the notifications feature.**
   `NotificationEpisodeProducer<S, D>` implements the sink. A kind supplies
   seven hooks — `kind`, `logSubDomain`, `subjectIdOf`, `episodeKeyOf`,
   `scheduledInstantOf`, `categoryOf`, `buildRow` — and nothing else. The
   base derives the id, arms idempotently while the instant is still ahead,
   retracts the rows the new episode supersedes, clears on demand, and logs
   rather than throws. Before writing, it refuses a row whose kind or linked
   entity differs from what it will later retract by.

3. **Two repository primitives replace the per-kind methods.**
   `armEpisode(id, scheduledFor, build, category)` creates unless the id
   exists, never invoking `build` otherwise; `retractOpenRows(linkedEntityId,
   kind, exceptId)` retracts every open row of one kind for one subject.
   `createRelationshipCheckIn`, `retractRelationshipCheckIns` and
   `notificationIdForRelationshipCheckIn` are removed.
   `createHabitAutoCompletion` stays as the engine's entry point but is built
   on `armEpisode`. Task suggestions keep their own serialised,
   replace-the-previous path: a suggestion wave is not an episode.

4. **Episode identity is `uuid5(kind, subjectId, episodeKey)`**
   (`notificationEpisodeId`), with `kind` the variant's wire discriminator
   named once in `NotificationKinds` and answered by `NotificationEntity.type`.
   The value is exactly what the check-in rows have always synced under, so a
   mixed fleet sees no new ids.

5. **Per-kind union variants stay.** A generic row carrying a route string
   would be shorter, but the exhaustive switches over the union are what force
   a new kind to decide its inbox behaviour (`showsBeforeScheduledTime`) and
   its tap route rather than inherit one. Adding a kind means a variant, a
   producer subclass, and a call from its tier; the compiler lists every site.

## Consequences

- A goal off-track alert is a variant, a subclass with seven hooks and one
  call after the goal tier's transaction commits — no repository change.
- Identity, idempotency, supersession and the best-effort rule exist once
  and are tested once, in `notification_episode_producer_test.dart`; the
  relationship suite now covers copy, instant, category and kind.
- `NotificationRepository` stops growing with the union. What is per kind is
  what only that kind knows.
- Nothing on the wire changes for the kinds that exist: their discriminators,
  ids and message families are as before. A kind adopted later (ADR 0062's
  goal alert) adds its own discriminator, as any new variant does; the
  contract itself carries nothing new over the wire.

## Non-Goals

- Model-authored copy at arming time. What a producer arms is baked at write
  time and lands on lock screens; ADR 0039 Decision 6's content-minimal rule
  stands. Whether an agent may later re-word a row it armed, in its own
  voice, is a separate decision — ADR 0063 — layered on top of this
  contract, not part of it.
- Recurring reminders. The episode key moves only with the subject's own
  state, which is what keeps an ignored subject alerted once.
- Moving task suggestions onto the contract.

## Related

- [ADR 0039: Relationship Check-In Reminders](./0039-relationship-check-in-reminders.md) — the shape this generalises
- [ADR 0054: Deterministic-First Two-Tier Wakes](./0054-deterministic-first-two-tier-wakes.md) — why the producer is the deterministic tier
- [ADR 0055: The Banner-Nudge Attention Channel](./0055-banner-nudge-attention-channel.md) — the in-app channel this complements
- [ADR 0059: Relationship Agents on the Shared Runtime](./0059-relationship-agent-runtime-and-nudge-generalization.md) — sibling variants, never conversion
