# Implementation Plan: Remove Label Group Exclusivity

Status: Approved Owner: Labels/AI Date: 2025-10-26

## Goal

Simplify the labels system by removing runtime group exclusivity for label assignment. Keep the data
model unchanged for now (no DB/schema migration), and adjust AI assignment logic, tests, and docs
accordingly.

## Non‑Goals

- Do not remove `groupId` column/field from schema/models in this pass.
- Do not implement/modify any priority field (tracked separately already).

## Design

- Remove exclusivity checks during AI label assignment. Previously, if a task had a label from a
  group, new labels from the same group were skipped with reason `group_exclusivity`.
- Keep `LabelAssignmentResult.skipped` for forward compatibility, but it will remain empty in
  current flows.
- Keep prompt injection as is (list of labels with `{ id, name }`).
- Keep rate limiting, shadow mode, add‑only behavior, and caps intact.
- UI: No behavior changes except no more exclusivity‑driven “skips”. Undo toast unaffected.

## Changes

1) Code

- lib/features/labels/services/label_assignment_processor.dart
  - Remove building `existingGroups` and the `seenGroups` set.
  - Remove adding `{'id': id, 'reason': 'group_exclusivity'}` to `skipped`.

2) Tests

- test/features/labels/label_assignment_processor_test.dart
  - Update first test to assert both labels are assigned when previously exclusive; keep invalid
    filtering.
- test/features/ai/repository/unified_ai_inference_repository_labels_test.dart
  - Update test to assert both labels (same former group) are assigned.
- Keep all other tests unchanged.

3) Docs

- lib/features/labels/README.md: remove group exclusivity description.
- docs/user_guides/ai_labels.md: remove group exclusivity from Safety & Limits.

## Validation

- Analyzer: zero warnings.
- Run targeted suites:
  - Processor + limiter tests
  - Conversation functions tests (labels)
  - Helpers: prompt builder labels
  - Unified repo labels test

## Rollback

- Re‑introduce the exclusivity block in `LabelAssignmentProcessor` (using the previous logic) and
  restore the tests.

