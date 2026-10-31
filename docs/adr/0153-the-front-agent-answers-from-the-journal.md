# ADR 0153: The Front Agent Answers From the Journal

- Status: Accepted
- Date: 2026-10-31
- Builds on: [ADR 0149](./0149-search-lists-word-matches-then-related-by-meaning.md),
  which made search by meaning part of every search
- Concepts: [front agent](../../knowledge/features/front_agent.md),
  [scoped query conversations](../../knowledge/features/agents/query-chat.md#journal-wide-questions)
- Plan: [voice-first front agent](../implementation_plans/2026-10-31_voice_first_front_agent.md), slice A

## Context

A search field finds entries, not answers. A question such as "what did I
decide about the fish stores last month?" needs several things found, often
in different categories, and then read. Query chat already answers questions
with numbered, verified evidence and live privacy checks, but only about one
task, one project or one category, and its retrieval was a keyword crawl
inside that one category.

The front agent is the one place the user talks to. Until now she routed a
question to the task, project or goal that owns it, and a question no single
owner holds — a `journal` question — landed in her inbox unanswered.

Two entry points for journal-wide questions were tried and rejected first: an
Ask control in or beside the search field takes width from the field, and an
"Ask" row in the results put a second chat surface next to hers. The owner's
direction is that journal questions belong to the front agent, which becomes
the voice-first place from which she can do anything.

## Decision

1. **A `journal` question is hers to answer.** The front agent's walker runs
   the query answer pipeline, headless, over `QueryScope.journalIn` of her
   allow-list (`allowedCategoryIds`; empty means every visible category), as
   `front_agent`. Her contract says so; a `journal` statement is still kept
   as a note. This narrows "she answers for no one": she still never answers
   for an owner, and never speaks for a task, project or goal.
2. **A journal scope with no home.** `QueryScopeKind.journal` reads the
   categories of its selection, or every visible category without one; the
   selection is part of the id. No query chat pane hosts it; it exists for
   her answers.
3. **The agent plans its searches.** The planning step that rewrites the
   question also names one to three natural-language `searches`, one for each
   separate thing the answer needs. Each runs as a search by meaning beside
   the keyword terms, and its hits are read first. Without planned searches
   the rewritten question is the one search.
4. **A named category narrows.** For a journal scope, the plan is offered the
   names of the categories the scope can see and may name those the question
   limits itself to ("in the colony category, find …"). Only offered names
   count, so a named category narrows the search and never widens it — a
   question naming only categories the scope cannot see reads nothing — and a
   private category is never offered while hidden.
5. **Her answer carries its evidence, checked live.** The door record keeps
   the answer's passages and the sources it depends on. The card shows the
   answer "From your journal" with numbered sources, each opening its entry,
   only while every source is still visible; a source turned private, or
   lockdown, hides it until visibility is known again.
6. **It runs on the Settings default.** No category's profile applies, so the
   model is resolved standalone from the Settings default, as the voice-first
   plan records for answers that have no owner.
7. **Scope kinds decode tolerantly.** `QueryScopeKind` decodes an unknown
   kind as `unknown`, which is never readable, so a kind a newer build adds
   never breaks an older one.

## Consequences

- One question finds related material across categories without the user
  choosing where to look, and the answer still cites exact passages.
- Journal answers read original entries, not agent reports, because there is
  no home whose reports come first.
- Where search by meaning is off or unavailable, the crawl runs on keywords
  and recent material alone, and a failed meaning search marks the answer
  incomplete rather than failing it.
- Answering is still typed in this slice; multiple chats and the voice-first
  surface follow in later slices of the plan.
