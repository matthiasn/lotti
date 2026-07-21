# ADR 0031: Learning Verification Checkpoint Policy

- Status: Proposed
- Date: 2026-07-21 (replaces the 2026-07-18 draft)

## Context

The 2026-07-18 draft of this decision assumed automatic prompting would be the
primary delivery channel and therefore specified a cross-device checkpoint
coordinator with signed schedule-policy activations, authenticated deadlines, a
global burden projection folded across scoped logs, and a spaced-review
authority chain. That machinery had to be provably convergent before anything
could ship, and it put months of infrastructure between the user and the first
question. The full draft is preserved in git history.

The product direction is now learner-initiated: the user starts a quiz from a
task whenever they want to check their understanding, the questions are
tailored to that task's content, and questions are not usually repeated on a
schedule. Automatic delivery is a convenience to add later, not the core.
A policy this small does not need a distributed authority model; it needs to be
deterministic, testable, and respectful of the user's attention.

## Decision

1. **Manual first, available everywhere.** A quiz ("Check my understanding")
   can be started from any task, regardless of whether an agent worked on it.
   The only preconditions are: the task has quizzable content, AI inference is
   configured for the task's category, and no other quiz session for the same
   task is currently awaiting answers. Later phases extend the same entry point
   to projects, Daily OS days, and agent reports without changing this policy.
2. **No eligibility scoring for manual quizzes.** Manual invocation never
   consults cooldowns, priority scores, or spacing. Starting a quiz mints a
   `quizRequestId` in the UI action; retries of the same action reuse it.
3. **Depth is a user choice, not policy.** At entry the user picks a quick
   check (about 3 questions) or a deeper quiz (about 6–8); the generator may
   return fewer when the content is thin and must say so rather than padding
   with filler questions.
4. **Automatic suggestions are a later, feature-flagged phase.** When enabled,
   suggestions are emitted only by deterministic triggers: a task with
   substantial content transitions to done, or a consequential change set is
   resolved. A suggestion is a small non-modal card ("Quiz yourself on this?")
   that runs zero inference and reveals no generated content before the user
   accepts. Guards are simple and local: feature enabled globally and for the
   category, app in the foreground, user not recording or in a modal flow, no
   open quiz, at most two suggestions per rolling week, and at most one per
   task completion. Snooze, dismiss, per-category disable, and global disable
   are always offered.
5. **Suggestion deduplication is best-effort.** A suggestion fact is an
   ordinary synced agent event with a deterministic ID derived from the task
   and its completion event. A device shows the card only while its projection
   contains no disposition for that ID. Concurrent offline devices can briefly
   show the same card; the race resolves on sync. No lease, lock, or
   cross-device delivery election exists.
6. **Quizzes never gate anything.** No task transition, change-set
   confirmation, commit, or other workflow ever waits on a quiz or its grade.
   Suggestions never use push notifications in the planned phases.
7. **Repeat quizzes are user actions.** "Quiz me again" is always available and
   generates fresh questions against the task's current content. An optional
   later phase may suggest a re-quiz when the user revisits a task whose last
   quiz had missed items; that suggestion follows the same guards as rule 4.
   There is no spaced-repetition scheduler, interval algebra, or review-due
   authority in this design.

## Consequences

- The whole policy is a handful of pure functions over projection state and
  settings; it is unit-testable without simulators or replay harnesses.
- Rare duplicate suggestion cards across devices are accepted in exchange for
  removing all coordination protocol; dismissing one dismisses both on sync.
- Without a burden projection there is no cross-device prompt accounting; the
  per-week cap is evaluated against locally synced events, which is accurate
  enough at personal scale.
- Dropping spaced repetition removes the strongest retention mechanism the
  earlier draft had. The bet is that fresh, task-anchored quizzes the user
  actually takes beat scheduled reviews the user would disable. Revisit if
  usage shows demand for scheduled review.
- Suggestion trigger values (two per week, substantial-content threshold) are
  tunable hypotheses stored in settings, not invariants.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0016: Agent-Derived State as a Projection of the Append-Only Log](./0016-agent-state-as-log-projection.md)
- [ADR 0032: Hybrid Understanding Evaluation](./0032-hybrid-understanding-evaluation.md)
- [ADR 0033: Learning Verification Session Persistence](./0033-learning-verification-session-persistence.md)
- [ADR 0034: Learning Understanding Rating](./0034-learning-understanding-rating.md)
