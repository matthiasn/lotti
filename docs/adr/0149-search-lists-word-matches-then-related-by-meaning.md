# ADR 0149: Search Lists the Word Matches, Then What Is Related by Meaning

- Status: Accepted
- Date: 2026-10-30
- Builds on: [ADR 0144](./0144-on-device-embeddings-use-embeddinggemma.md),
  whose fifth decision asked for the hybrid ranking to be measured on the
  app's own keyword path before it ships, and
  [ADR 0148](./0148-embeddings-run-only-on-the-device.md), which made
  EmbeddingGemma the only embedding provider
- Concept: [browse, search and linking](../../knowledge/features/journal/browse-and-linking.md#one-search-the-words-then-the-meaning)

## Context

The tasks and journal pages offered two searches behind a toggle: full text or
"Vector". Each answered only one kind of question.

- **Full text** finds what was typed: every word is required, the last one also
  as a prefix, ranked by BM25 with the title weighted highest. It cannot find a
  task described in other words.
- **Search by meaning** finds those. But it ranks an exact title match below a
  near neighbour often enough to be wrong where keywords are certain.

The tasks list's status, label, priority, project and agent selections narrowed
a full-text search but not a vector search. With the default open-work status
selection, searching for something already done found nothing, though finding
past work is much of what search is for.

A toggle makes the user guess, before typing, which kind of question they are
asking. ADR 0144 measured a plain reciprocal rank fusion against a BM25 baseline
that was not the app's search, so its numbers could not choose the fusion.

`tool/embedding_eval/hybrid.py` measures it on the app's own path: the search
index's columns and tokenizer, `ftsMatchExpression`, and the app's BM25 column
weights. Meaning comes from the shipped model, EmbeddingGemma-300m q4, with its
query and document prompts. The query sets run over the penguin demo world's
tasks in all eleven languages (mean reciprocal rank, n per set):

| Method | paraphrase (224) | title words (308) | one word (308) | body words (308) | typing (308) | title (308) |
|---|---|---|---|---|---|---|
| meaning alone | 0.848 | 0.981 | 0.856 | 0.684 | 0.908 | 0.998 |
| keywords alone | 0.004 | 1.000 | 0.982 | 0.998 | 0.998 | 1.000 |
| **keywords first** | **0.848** | **1.000** | **0.982** | **0.998** | **0.998** | **1.000** |
| best weighted RRF (k=10…60, w=2) | 0.848 | 1.000 | 0.977 | 0.997 | 0.998 | 1.000 |

"Keywords first" lists every keyword match in its BM25 order, then the rest of
the meaning ranking. It wins or ties on every set. No weighting of reciprocal
rank fusion over k ∈ {10, 30, 60} and keyword weight ∈ {0.25, 0.5, 1, 2} beats
it anywhere, and every one loses on single-word queries. Keywords are strict, so
a keyword match is nearly always the answer when there is one. When there is
none, meaning finds it as well as it does alone.

## Decision

1. **One search, no mode.** Every query runs the full-text search and, while
   search by meaning is on and set up on the device, search by meaning at the
   same time. The search-mode toggle is removed from the logbook and from the
   tasks filter sheet, along with its state and its labels.
2. **The word matches come first, in their own order.** The tasks page keeps
   the index's best-match order; the logbook keeps newest first.
3. **What meaning adds follows, nearest first, under a "Related by meaning"
   heading.** These are the results the words did not find. A result both
   searches found stays where the words put it.
4. **A task search reaches every task in scope, for both sections alike.**
   While a query is typed, the status, label, priority, project and agent
   selections do not apply: they shape the browsing list, not what a search
   can find. Category (and lockdown with it), the due view, starred and private
   mode still scope the search. A pasted pull request link already worked this
   way. A search is one page.
5. **The due-view counts follow the same rule**: they count the word matches
   plus what meaning added, with the same scope clauses.

## Consequences

- A search finds what was typed exactly where it used to, and finds a
  paraphrase it used to miss without the user switching anything.
- Meaning always returns its nearest results (up to twenty), so the related
  section is rarely empty. The heading marks where the certain matches end.
  A distance threshold could trim it later; it needs its own measurement.
- Each query also embeds the query text on the device. The list waits for
  both searches, and the results on screen stay until the new ones land.
- The logbook's matches now load as one page, bounded by the index's limit
  (500), instead of paging fifty at a time.
- A done or parked task now turns up in search while the list shows open
  work. Each result card shows its status. The filter chips over the list stay
  visible while a query is typed, although their status, label, priority,
  project and agent clauses do not apply to it.
- Where search by meaning is off or unavailable (Windows, or the model not
  downloaded), search is the full-text search alone, as before.
