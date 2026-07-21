# ADR 0031: Learning Verification Checkpoint Policy

- Status: Proposed
- Date: 2026-07-21

## Context

Learning quizzes are learner-initiated: the user starts one from a task, the
questions are tailored to that task's content, and questions are not usually
repeated on a schedule. Automatic delivery is at most a later convenience.
The triggering policy therefore has to be small, deterministic, and
respectful of the user's attention — not a cross-device scheduling system.

## Decision

1. **Manual first, on every task.** "Check my understanding" is available on
   any task, whether or not an agent worked on it. Preconditions: the task
   has quizzable content, inference is configured for its category, and no
   other quiz for the task is awaiting answers. The UI mints a
   `quizRequestId` once per action and reuses it through retries.
2. **Depth is a user choice.** Quick check (~3 questions) or deep dive
   (~6–8); thin content yields fewer questions, never filler.
3. **No eligibility machinery for manual quizzes.** No cooldowns, priority
   scores, or spacing checks.
4. **Automatic suggestions are a later, feature-flagged phase.**
   Deterministic triggers only (a task with substantial content is completed,
   or a change set resolves), simple local guards (foreground, not recording,
   no open quiz), at most two suggestions per rolling week, and
   snooze/dismiss/disable controls. A suggestion runs zero inference before
   acceptance.
5. **Suggestion dedup is best-effort.** Deterministic suggestion IDs sync as
   ordinary agent events; a rare duplicate card across offline devices
   resolves on sync. No lease or delivery election.
6. **Quizzes never gate anything** and never use push notifications.
7. **Repeat quizzes are user actions.** "Quiz me again" generates fresh
   questions. There is no spaced-repetition scheduler.

## Consequences

- The policy is a handful of pure functions over projection state and
  settings, unit-testable without simulators.
- Rare duplicate suggestion cards are accepted in exchange for having no
  coordination protocol.
- Without scheduled reviews, retention relies on the user choosing to
  re-quiz; revisit if usage shows demand for scheduling.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0032: Hybrid Understanding Evaluation](./0032-hybrid-understanding-evaluation.md)
- [ADR 0033: Learning Verification Session Persistence](./0033-learning-verification-session-persistence.md)
- [ADR 0034: Learning Understanding Rating](./0034-learning-understanding-rating.md)
