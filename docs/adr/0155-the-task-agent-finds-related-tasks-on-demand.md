# ADR 0155: The Task Agent Finds Related Tasks on Demand

- Status: Accepted
- Date: 2026-11-01
- Concepts: [task agents](../../knowledge/features/agents/task-agents.md#related-tasks-are-fetched-on-demand),
  [task link suggestions](../../knowledge/features/ai/task-link-suggestions.md)

## Context

A note that speaks of other work — *blocked by the relay repair*, *same
problem as last week's census* — names an edge of the task graph. The task
agent reads every note, but it can only propose `link_task` for a task whose
id is in its context, and its context held only tasks already linked.

Two earlier attempts left this unsolved. Injecting sibling tasks' TL;DRs
into every wake polluted the context window and was switched off, leaving
`get_related_task_details` implemented but disabled, waiting for "a better
retrieval path". Mechanical link suggestions (a cue-phrase table, then a
search by meaning) found the candidates on the device, but the phrase table
read other languages poorly: German "das hängt von X ab" splits its verb
around the object, Czech and Romanian inflect, and anything phrased outside
the list was never seen.

## Decision

1. **The model searches only when a note calls for it.** A
   `find_related_tasks {query}` tool runs the on-device search by meaning
   (`RelatedTaskFinder`, the same one link suggestions use) for a query the
   model writes from the note. Nothing about other tasks enters a wake that
   does not call it, and the prompt forbids searching when no note refers
   to other work.
2. **Two depths, fetched in order.** A search answers with at most five
   tasks: id, title, status and their agent's one-liner. Only then can
   `get_related_task_details` read one of them — its TL;DR, and with
   `includeFullReport` the whole latest report.
3. **Only what a search returned can be read.** The drill-down refuses any id
   no search of the current wake returned, so the model cannot inspect a
   task it guessed.
4. **The search keeps the measured cutoff and the existing-link exclusion.**
   A task within 0.55 cosine distance, not the task itself, holding no live
   link to it. Proposals still go through `link_task` and the user's
   confirmation; nothing is linked without it.
5. **What leaves the device is bounded.** Results go to the agent's
   inference provider, so a search covers only the agent's allowed
   categories and never returns a private task.
6. **No search, no tools.** Where search by meaning cannot run — the
   embedding pipeline did not start, or it is switched off — neither tool
   is offered, on every wake (`TaskAgentWakeFacts.hasRelatedTaskSearch`).
7. **The `enabled` flag on tool definitions goes.** It existed for the
   disabled drill-down alone; with both tools gated by a wake fact it had no
   user left.

## Consequences

- A tool result lives only in the wake that fetched it: the stored tool
  message keeps the tool name and any error, not the answer, and each wake
  builds its context afresh.
- The model decides when to search. It can miss a mention or search where
  none was needed; the cutoff, the allowlist and the user's confirmation
  bound what that costs.
- Titles and one-liners of other tasks in the agent's categories now reach
  its provider when it searches; narrowing the agent's allowed categories
  narrows what it can search.
- The two tool definitions are in every request where search runs — a few
  hundred tokens — whether or not the wake searches.
