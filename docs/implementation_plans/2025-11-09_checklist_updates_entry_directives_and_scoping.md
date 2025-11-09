# Checklist Updates — Entry‑Scoped Directives and “Single‑Item Plan” Handling (2025‑11‑09)

## Summary

- Add explicit, entry‑scoped directive handling to Checklist Updates so dictated plans or meta‑notes
  do not pollute suggestions.
- Teach models to apply directives per entry (each provided entry is a single unit) and obey simple
  inline directives:
  - Ignore for checklist extraction
  - Treat the rest of the entry as an implementation plan → emit at most one checklist item (e.g.,
    “Draft implementation plan”)
- Implement via prompt template updates (system + user) with clear rules and examples; no DB/model
  changes.
- Add tests to lock in directive guidance presence and phrasing.

## Problem

When users dictate implementation plans or meta‑instructions, the Checklist Updates prompt tries to
extract multiple items from content that should be ignored (or collapsed into a single tracking
item). This creates noisy suggestions and requires manual cleanup.

## Goals

- Per‑entry scoping: treat each entry independently when extracting items; within an entry, a
  plan‑only directive collapses to a single item and an ignore directive suppresses extraction
  entirely.
- Support simple inline directives embedded by the user in natural language.
- Minimal surface change: prompt‑only adjustment; no handler or DB schema changes.
- Backward compatible: if no directives are present, existing behavior remains.

## Non‑Goals

- NLP classification of arbitrary meta‑content beyond the provided directive cues.
- UI changes for directive insertion (future UX polish possible).

## Directive Vocabulary

Lightweight phrases that users can speak or paste. Models are instructed to detect them
case‑insensitively.

- Ignore entry: “Don’t consider this for checklist items”, “Ignore for checklist”, “No checklist
  extraction here”.
- Plan‑only single item: “The rest is an implementation plan”, “Treat as plan only”, “Single
  checklist item for this plan”.
- Optional explicit single‑item title: “Single checklist item: <title>”. If omitted, default to a
  sensible generic (e.g., “Draft implementation plan”).

Scope rules:

- “Ignore …” applies to the entire current entry text.
- “Plan‑only …” applies to the entire current entry text and results in at most a single
  item.

## Design

- Prompt template (system message) gains a new section: “Entry‑Scoped Directives (Per Entry)”. It:
  - Defines the directive phrases and scope semantics with the entry as the unit of scope.
  - Instructs the model NOT to split an entry into paragraphs/bullets for directive scoping; the
    directive applies to the entire entry.
  - Specifies the single‑item behavior when a plan‑only directive is present anywhere in the entry (
    optional explicit title supported).
- Prompt template (user message) keeps the existing structure but adds a short reminder and example
  of directives, and explicitly calls out per‑entry scope.
- No changes to tool schemas or handlers; the existing array‑only multi‑create function remains the
  integration point.

## Implementation Plan

A) Prompt updates

- Edit `lib/features/ai/util/preconfigured_prompts.dart` Checklist Updates template:
  - Add “Entry‑Scoped Directives (Per Entry)” to system message with explicit wording and examples.
  - Add a brief reminder block to the user message describing directives and that the model should
    scope them to each entry.

B) Tests

- Update `test/features/ai/util/preconfigured_prompts_test.dart` to assert system message includes
  directive guidance keywords (e.g., “Ignore for checklist”, “Single checklist item”).
- Add/extend tests to ensure user message includes a short reminder about directives.

C) Analyzer & formatting

- Run analyzer and formatter; fix any lints.

D) Docs & changelog

- This plan file; update feature README if needed in a follow‑up.

## Risks & Mitigations

- Over‑ignoring content: use precise phrases and keep behavior conservative (only act on clear
  directive cues).
- Model drift: keep examples in the prompt; add tests to prevent accidental removal of guidance.

## Rollout

- Prompt‑only change; safe to ship. Monitor suggestions after a few sessions and iterate on phrasing
  if necessary.

## Status (2025‑11‑09)

- Implemented prompt changes in `lib/features/ai/util/preconfigured_prompts.dart`:
  - Added "ENTRY‑SCOPED DIRECTIVES (PER ENTRY)" to the system message, clarifying that each provided
    entry is the unit of scope and how ignore/plan‑only directives behave.
  - Added a "Directive reminder" to the user message, including per‑entry scope and examples.
- Tests updated and passing:
  - `test/features/ai/util/preconfigured_prompts_test.dart` asserts directive guidance is present in
    both system and user messages.
  - Existing labels prompt tests remain green.
- Documentation updated:
  - Added a per‑entry directive section to `lib/features/ai/README.md` under "Adding Checklist Items".
- Validation:
  - Analyzer reports zero issues.
  - Targeted tests pass locally via MCP.
