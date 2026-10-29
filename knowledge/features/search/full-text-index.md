---
type: Feature Module
title: Search index
description: The FTS5 index of the journal's text — what each entity contributes, how every write reaches it, how a typed query becomes a match that cannot fail, and how matches rank and filter before their limit.
resource: ../../../lib/database/fts5_db.dart
tags: [search, fts5, full-text, persistence, indexing]
status: draft
generated: { by: claude-code/opus-5.5, at: 2026-10-29T18:00:00Z }
stale_after: 2027-04-29
sources:
  - id: fts5-db
    resource: ../../../lib/database/fts5_db.dart
    title: Fts5Db — schema, catch-up, live indexing, matching
    last_modified: 2026-10-29
  - id: fts5-schema
    resource: ../../../lib/database/fts5_db.drift
    title: search_doc, search_fts and search_index_state
    last_modified: 2026-10-29
  - id: search-document
    resource: ../../../lib/database/search_document.dart
    title: searchDocumentFor — what each entity contributes
    last_modified: 2026-10-29
  - id: fts-query
    resource: ../../../lib/database/fts_query.dart
    title: ftsMatchExpression — the query builder
    last_modified: 2026-10-29
  - id: indexer
    resource: ../../../lib/services/search_index_service.dart
    title: SearchIndexService — indexing every journal write
    last_modified: 2026-10-29
  - id: title-search
    resource: ../../../lib/database/title_search.dart
    title: Title match ranking and the misspelling fallback
    last_modified: 2026-10-29
  - id: runner
    resource: ../../../lib/features/journal/state/journal_query_runner.dart
    title: JournalQueryRunner.fts5Search and taskFullTextHits
    last_modified: 2026-10-29
  - id: task-search
    resource: ../../../lib/database/task_search.dart
    title: searchTasks — a task found through what belongs to it
    last_modified: 2026-10-29
---

# What it is

`Fts5Db` (`fts5_db.sqlite`) is a **derived copy of the journal's text**,
rebuildable at any time from `JournalDb` and never synced: every device builds
its own, from whatever its journal holds. It lives in its own database file
so that indexing never takes the journal's write lock. Embeddings are a second,
separate index ([embeddings and search](../ai/embeddings-and-search.md)).

Two tables carry it:

| Table | Holds |
|-------|-------|
| `search_doc` | One row per indexed entity: its id, journal `type`, category (`''` for none), `private` flag and `date_from` — the filters a search applies before ranking — and the integer key of its text |
| `search_fts` | FTS5 over `title`, `body` and `extra`, keyed by `search_doc.id`; `unicode61 remove_diacritics 2` tokenizer, two- and three-character prefix indexes, text stored so a result can show a snippet |

`title_trigram` holds titles alone, tokenized into letter triples
(`trigram remove_diacritics 1`) and keyed the same way, so a title matches on
any three letters of it, inside a word too; only entities with a title have a
row there.

`search_index_state` holds one value: the journal rowid a pending rebuild
continues after.

# What an entity contributes

`searchDocumentFor` decides, per entity kind, what goes in each column:

| Column | Ranked | Holds |
|--------|--------|-------|
| `title` | ×10 | A task's, project's, goal's, event's, checklist's or checklist item's title; a pull request's title; an AI response's one-liner; a survey's identifier; a check-in's topics and next-time notes ([ADR 0139](../../../docs/adr/0139-check-ins-are-searchable.md)) |
| `body` | ×1 | The entry text; a recording's edited text, else its last transcript; an AI response's text; a goal's statement; a pull request's description |
| `extra` | ×2 | A measurement's name and value label (resolved through its definition), a survey's scores, a health reading's value, unit and name, a pull request's `owner/repo#number` |

An entity whose three columns are blank, a deleted one, and a goal's spec
snapshot (its goal is found instead) have no row.

# How every write reaches it

```mermaid
flowchart LR
  Local["Local edit / create"] --> Journal[("JournalDb")]
  Sync["Sync apply"] --> Journal
  Agent["Agent write"] --> Journal
  Journal --> Notify["UpdateNotifications.updateStream"]
  Notify --> Service["SearchIndexService"]
  Service -->|"indexByIds"| Index[("Fts5Db")]
  Index -->|"reads the entities, inside its queue"| Journal
```

Every journal write announces its ids on `UpdateNotifications.updateStream` —
local, synced and agent writes alike — and `SearchIndexService` hands each
batch to `Fts5Db.indexByIds`, which reads those ids from the journal (deleted
rows included) and upserts, replaces or removes their rows; an id with no row
(a notification token, a purged entry) is removed, at the cost of one lookup.
**That one subscription is why an entry that arrives by sync is searchable**;
before it, only local edits were indexed, so a device that received its data
had a largely empty index until a manual rebuild.

Writers to a journal that is not the live one (a world being seeded, a demo
copy) call `Fts5Db.indexEntities` with what they wrote. Task creation also
indexes the new task at once: the link picker's duplicate check can run
before the notification arrives. A measurable definition edit reindexes its
measurements with `reindexMeasurements`, passing the edited definition.

## One queue

Every write goes through one serial queue inside `Fts5Db`, and the writes that
read the journal read it **inside** that queue. So a rebuild batch read before a
live edit cannot be written after the edit and overwrite it with what it read.

# Rebuild

```mermaid
stateDiagram-v2
  [*] --> Owed: created, upgraded from v1 or v2, or reset
  Owed --> Owed: catchUp writes a batch and its last rowid
  Owed --> CaughtUp: catchUp reads a short batch
  CaughtUp --> Owed: recreateFts5 (file deleted, new index)
```

A new index — first launch, the version 1 upgrade (whose single `journal_fts`
table cannot be converted, so it is dropped), the version 2 upgrade (which
adds `title_trigram` for the rebuild to fill), or the maintenance rebuild —
starts **owed** a rebuild. `SearchIndexService.start`, tracked as startup work,
runs `catchUp`: it walks the journal's live rows by rowid
(`JournalDb.liveEntitiesAfterRowId`), 500 at a time, and writes each batch in one
transaction together with the rowid it reached, so a rebuild cut short by the
app closing resumes where it stopped. Disposing the service stops it between
batches. Live changes are indexed meanwhile, through the same queue.

The maintenance sheet's rebuild (`Maintenance.recreateFts5`) deletes the file,
opens a fresh index and runs the same `catchUp`, reporting its progress.

# From what was typed to a match

`ftsMatchExpression` rebuilds the `MATCH` expression from the input's words
instead of passing it through, because FTS5 gives quotes, `-`, `:`, `*`, `^`,
parentheses and the bare words `AND`, `OR`, `NOT`, `NEAR` a meaning:

- each whitespace-separated word becomes a quoted phrase of its letters,
  marks and digits, split the way the tokenizer splits it (`self-care` is
  `"self care"`);
- text in double quotes stays one exact phrase;
- the last word, unless quoted or followed by a space, also matches as a
  prefix from its second character (`"pengu"*`), so results keep up while it
  is typed;
- the phrases are all required, or any one of them with `anyTerm`;
- at most 16 phrases are kept.

Input with no letter or digit matches nothing. **No input can make a match
throw**; a property test feeds it FTS5 syntax at random.

# Ranking and filters

`Fts5Db.matchHits` returns hits best match first: BM25 with the column
weights above, newer `date_from` first among equals. Each carries its type and
an FTS5 `snippet()` of its best-matching column, twelve words around the
match, each matched word wrapped in private-use markers (`snippetMatchStart`,
`snippetMatchEnd`; `snippetSpans` splits them back out). `matchIds` is the
same without the snippets. Types, categories and
private visibility are applied **before** its limit (500 by default), so the
limit keeps the best matches the caller can show rather than spending it on
rows the caller then drops. The privacy gate still applies where results are
read: hits resolve through the private-filtered reads
([persistence](../../architecture/persistence.md)).

| Caller | Asks for |
|--------|----------|
| Tasks tab and its due-view counts (`taskFullTextHits`) | Tasks and what belongs to them (`searchTasks`), in the selected categories, private ones while private mode shows them |
| Journal tab (`JournalQueryRunner.fts5Search`) | The entry types it lists, in the selected categories, same privacy |
| Link-task picker | Tasks |
| Front agent and day agent open-task matching (`matchOpenTasksByPhrase`) | Tasks in the allowed categories |
| Query chat crawler | Any of its keywords, whole words only (`anyTerm`, no prefix) |

The tasks tab lists its matches in the index's order
([browse and linking](../journal/browse-and-linking.md)); the journal list
still orders by its own sort, the index's order deciding which matches
survive its limit; agents read it as relevance.

## A task is found through what belongs to it

`searchTasks` searches tasks together with the kinds that hang off them
(`taskSearchTypes`: entries, recordings, photos, AI responses, checklists and
checklist items) in one ranked match, so a checklist item that matches better
than another task's description puts its task first. It resolves every
non-task hit to the tasks it belongs to in three batched reads — the links to
it (`linksForIds`), and for checklists and their items the tasks their
checklist names (`ChecklistItemData.linkedChecklists`,
`ChecklistData.linkedTasks`) — and keeps each task's best hit, with its
snippet and the kind it was in (`TaskSearchHit`).

# Title search

`Fts5Db.searchTitles` finds entities by their title, for jumping to one by
name (the [command palette](../keyboard.md#the-palette-jumps-to-things-too)).
Its words of three letters or more match anywhere in a title through
`title_trigram`; a query of only shorter words uses the main index's prefix
match over the title column. `rankTitleMatches` then keeps the titles holding
every word — a short word only as the start of a title word — and orders them:
the title that is the query, titles starting with it, titles with a word
starting with its first word, then the rest, each tier in the index's order.
It compares words with their accents folded (`foldDiacritics`) the way the
index's tokenizers fold them, so an unaccented query holds an accented title
in Dart as it does in SQLite. The whole pool of up to 500 candidates
(`Fts5Db.titleCandidatePool`) is ranked before the limit is cut: the index's
BM25 order favours a repeated word over the title that is the query and cannot
check a short word, so cutting by it first would crowd real matches out.

When no title holds every word, `nearestTitles` takes the titles sharing at
least half of the query's letter triples (and two or more) from an any-trigram
match, most shared first, and marks them `fuzzy`: a misspelt name still finds
its task. The same type, category and privacy filters as `matchIds` apply
before the limit.

# Gotchas

- **A crash between a journal write and its notification leaves the entity
  unindexed** until it is written again or the index is rebuilt; the
  notification is in memory. The journal stays correct either way.
- **The index is resolved on every use**, by the indexer and the page's
  query runner alike: the maintenance rebuild closes the old instance and
  registers a new one, and a reference held across it would query a closed
  database.
