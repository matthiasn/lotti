---
type: Feature Module
title: Checklist corrections
description: Not the checklist UI — the service that learns from title edits and feeds them back as category-level AI guidance.
resource: ../../lib/features/checklist
tags: [checklist, corrections, ai-guidance, undo]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:00:00Z }
stale_after: 2027-01-26
sources:
  - id: src
    resource: ../../lib/features/checklist
    title: Checklist corrections source
    last_modified: 2026-07-25
---

This feature is small and focused, and **it does not own the checklist UI** — the
visible experience lives in [tasks](tasks/checklists.md).

What it owns is the **correction-capture service** that learns from user edits to
checklist item titles and feeds those corrections back into category-level
guidance: capture of meaningful before/after corrections, delayed-save behaviour
with undo, duplicate and trivial-change filtering, and persistence of correction
examples onto categories.

# Why the filtering matters

Every rename is a potential training signal, and most renames are noise — a typo
fix, a capitalization change, a word reordered. Capturing those would fill a
category's guidance with examples that teach nothing.

So the service **filters trivial changes and duplicates before persisting**, and
**delays the save** so an undo takes the correction back rather than recording and
then contradicting it.

The surviving before→after pairs land on the category as `correctionExamples`,
which the AI feature injects as context — see [categories](categories.md) and
[AI execution paths](ai/execution-paths.md).
