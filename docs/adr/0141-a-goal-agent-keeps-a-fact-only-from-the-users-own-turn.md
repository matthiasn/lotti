# ADR 0141: A Goal Agent Keeps a Fact Only From the User's Own Turn

- Status: Accepted
- Date: 2026-10-19
- Implements: [ADR 0057](./0057-decade-scale-agent-memory.md) decision 1, the
  `remember` half — with the confirmation rule below in place of its
  "user-stated facts go straight to `confirmed`"

## Context

ADR 0057 decision 1 gives goal agents durable, keyed knowledge: a `remember`
tool writing to the knowledge store the day planner already keeps
(`PlannerKnowledgeEntity`, ADR 0022 decisions 9–10). It says user-stated
facts go straight to `confirmed` and agent-inferred ones to `proposed`.

The day planner deliberately does not do that. Every one of its proposals
lands `proposed`, whatever the model says about its source, because capture
transcripts reach its prompt: trusting "the user said this" would let words
quoted in a transcript write themselves into memory that every later wake
reads.

A goal agent has the same exposure. Its briefings read the user's check-ins,
and a check-in can quote anyone. But it also has something the planner's
wakes lack: a turn on which the user is speaking to it directly, in the chat.

The knowledge store, its "What I've learned" panel and their providers lived
in `daily_os_next`, which ranks above `goals` in the layer order, so goals
could not use them.

## Decision

1. **The knowledge store belongs to `agents`.** The domain, the service, the
   providers and the panel move to `lib/features/agents/knowledge/` and
   `lib/features/agents/ui/knowledge/`, keyed by agent id. The day planner
   keeps only its `propose_knowledge` tool wrapper. The entity, its id
   scheme and its sync are unchanged.
2. **A goal fact is kept only from the user's own turn.**
   `remember_goal_fact` records a fact `confirmed` when its `source` is
   `userStated` **and** the wake is answering the user's own chat message.
   Every other fact — inferred, or "user-stated" on a briefing or any other
   automatic wake — is `proposed`. The caller vouches, never the model: the
   service records a fact confirmed only when the goal workflow passes
   `userConfirmed`, from what it knows about the wake.
3. **The user reviews on the goal page.** The shared panel appears on the
   goal page once the agent has learned something, to confirm a proposal and
   to edit or forget any fact.
4. **Confirmed facts reach every wake.** A `knowledge` section of FACTS
   carries the goal's confirmed facts in key order within 600 tokens. Past
   that, a fact reads as its one-line hook, and once even hooks no longer
   fit, the rest are counted. It carries an interpretation policy that keeps
   measured FACTS above it, as the charter's does.
5. **Remembering never costs the reply.** Every outcome of the tool is an
   answer, a malformed fact included, and a fact the store cannot write is
   logged and dropped inside the output transaction rather than rolling it
   back.

## Consequences

- "Remember this" in the chat takes effect at once; the same sentence in a
  check-in becomes a proposal the user confirms with one tap.
- The day planner's behaviour is unchanged: its tool still never confirms.
- An agent that mis-remembers on the user's own turn writes a confirmed fact
  the user has to forget on the goal page. The tool's answer says it was
  kept, and the panel shows it.

## Related

- [ADR 0022](./0022-long-lived-daily-os-planner.md) decisions 9–10
- [ADR 0057](./0057-decade-scale-agent-memory.md)
- [ADR 0140](./0140-a-goal-is-constituted-by-its-charter-entries.md)
