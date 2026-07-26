---
type: Feature Module
title: Ratings
description: Catalog-driven structured judgments attached to another entry, where each stored dimension snapshots enough schema to survive catalog drift.
resource: ../../../lib/features/ratings
tags: [ratings, catalogs, snapshotting, sync]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T03:45:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: ../../../lib/features/ratings
    title: Ratings feature source
    last_modified: 2026-07-25
  - id: rating-data
    resource: ../../../lib/classes/rating_data.dart
    title: RatingData and RatingDimension
    last_modified: 2026-07-25
---

Ratings attach a structured judgment to another entry **without baking the
question set into the UI**. The shipped catalog is session-focused, but the model
is generic over `(targetId, catalogId)`.

```mermaid
flowchart TD
  Time["DurationWidget / TimeService stream"] --> SessionEnded["SessionEndedController"]
  SessionEnded --> Pulse["PulsatingRateButton"]
  Menu["ModernRateSessionItem"] --> Modal["RatingModal"]
  Pulse --> Modal
  Modal --> Controller["RatingController"]
  Controller --> Repo["RatingRepository"]
  Repo --> Persist["PersistenceLogic"]
  Repo --> Db["JournalDb"]
  Repo --> Link["EntryLink.rating"]
  Link --> Outbox["Sync outbox"]
  Db --> Summary["RatingSummary"]
  Summary --> Modal
```

Small, but it crosses more boundaries than it looks: the prompt comes from the
timer flow, the editor is catalog-driven, persistence is journal-backed, and
**rendering must still work when the local catalog is missing.**

# The model

**`RatingQuestion` is catalog schema, not stored data** — a stable `key`, a
localized `question`, an English `description` explaining the scale (intended for
downstream interpretation such as LLM use), an `inputType`, and normalized
options.

**`RatingData`** is the payload inside a `RatingEntry`: `targetId` (serialized
under the legacy wire key `timeEntryId`), the captured `dimensions`, `catalogId`,
`schemaVersion`, and an optional note.

**`(targetId, catalogId)` is the uniqueness boundary** — one target can hold
multiple ratings overall, but only one record per catalog.

## Snapshotting is the architectural decision

Each stored `RatingDimension` is deliberately **self-describing**: besides `key`
and `value` it may snapshot the `question`, `description`, `inputType`,
`optionLabels` and `optionValues`.

**That is what lets a synced rating stay readable** even if the catalog wording
changes, the catalog disappears locally, or a future client introduces catalogs an
older client does not know.

Without it, a rating synced from a newer device would render as bare numbers
against unknown keys.

# The catalog registry

`rating_catalogs.dart` maps `catalogId` values to **localized factory functions** —
so questions are generated in the active language rather than stored in one.

The registry currently holds a single catalog, `session`.
