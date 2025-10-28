# Checklist Item Parsing Hardening (Arrays Preferred, Robust Fallback)

## Summary

- Problem: Batch checklist creation split items on every comma, so legitimate commas inside a single item (or within parentheses) produced multiple unintended items. Models were also encouraged to provide comma-separated strings, which increased the chance of this failure.
- Solution: Prefer a JSON array of strings for `add_multiple_checklist_items.items`. When a string must be used, parse it robustly so commas within quotes, escapes, or grouping constructs do not split.
- Scope: AI checklist updates (function-calling), batch creation, prompts and schema guidance, and minimal shared parsing utility.

## Goals

- Accept `items` as a JSON array of strings (preferred) for `add_multiple_checklist_items`.
- For string fallback, handle:
  - Quotes: `"..."` and `'...'` group commas
  - Escape: `\,` yields a literal comma
  - Grouping: commas within `()`, `[]`, `{}` don’t split
- Update prompts and function schema to prefer arrays and document fallback rules.
- Add tests and keep analyzer at zero warnings.

## Non-Goals

- Changing single-item tool (`add_checklist_item`).
- Modifying checklist creation semantics or duplicate detection.
- Adding new functions or altering API outside of the parsing/guidance scope.

## Design Overview

1) Robust parser utility
- New `parseItemListString(String)` that returns `List<String>`.
- Linear scan with state: supports quotes, escapes, and parentheses/brackets/braces nesting.
- Trim and discard empties.

2) Tool schema (function definition)
- `add_multiple_checklist_items.items` supports `oneOf: [array<string>, string]`.
- Prefer array, document fallback with escaping/quotes.

3) Prompt and conversation guidance
- Preconfigured prompts instruct array usage: `{ "items": ["a", "b", "c"] }`.
- Fallback documented: `{ "items": "a, b, c" }` with `\,` or quotes for commas within items.
- Conversation continuation prompt mirrors this guidance.

4) Inference fallback
- When provider sends a string, use the robust parser instead of `split(',')`.
- Arrays remain the first class path.

5) Backward compatibility
- Existing comma-separated input continues to work but is parsed safely.
- No breaking changes to function names or overall behavior.

## Safety & Edge Cases

- Empty/whitespace-only input → results in empty list (rejected as no valid items).
- Misbalanced quotes/grouping → treated best-effort; only commas outside quotes and groupings split.
- Duplicates handled at existing layers as before.

## Code Touchpoints

- New
  - `lib/features/ai/utils/item_list_parsing.dart` — robust string parser for item lists
- Updated
  - `lib/features/ai/functions/lotti_batch_checklist_handler.dart` — accept arrays; use robust fallback parsing
  - `lib/features/ai/repository/unified_ai_inference_repository.dart` — robust fallback in unified processing; directives ordering
  - `lib/features/ai/functions/checklist_completion_functions.dart` — function schema `oneOf` (array|string) and updated description
  - `lib/features/ai/functions/lotti_conversation_processor.dart` — continuation prompt guidance updated
  - `lib/features/ai/util/preconfigured_prompts.dart` — array-first guidance with fallback
- Tests
  - `test/features/ai/utils/item_list_parsing_test.dart` — parser unit tests
  - `test/features/ai/functions/lotti_batch_checklist_handler_test.dart` — array acceptance, quotes, escaped comma, parentheses

## Implementation Steps

1) Add parser utility and tests
- Create `parseItemListString` and unit tests for quoting, escaping, grouping, trimming.

2) Update batch handler and unified inference
- Prefer arrays; use robust parser for string fallback.
- Propagate parsed list to downstream creation code.

3) Update tool schema + guidance
- Function definition: `oneOf` array/string with clear descriptions.
- Prompts: prefer arrays; document fallback string escaping and grouping rule.
- Conversation prompt: same guidance for continuation.

4) Verify
- Run analyzer: zero warnings.
- Run targeted tests for parser, batch handler, and prompts.
- Update CHANGELOG.

## Risks & Mitigations

- Model compliance: Some models may still emit strings. Mitigated by robust parser and strong schema/prompt guidance favoring arrays.
- Parser correctness: Covered by unit tests; logic is linear and limited in scope (no regex backtracking).
- Performance: O(n) per input; inputs are small (tool arguments), so cost is negligible.

## Rollback Strategy

- Revert to previous simple split logic in batch handler and unified inference if needed.
- Retain parser utility (unused) for future guarded rollout.
- Remove array guidance from prompts if rollback desired, though recommended to retain.

## Acceptance Criteria

- Analyzer reports zero warnings.
- Tests pass:
  - Parser unit tests exercise quotes, escapes, grouping, trimming.
  - Batch handler tests validate array + string inputs including complex cases.
  - Preconfigured prompts/conversation tests still pass.
- CHANGELOG entry documents the fix.
- Manual sanity: Verify an item like `Start database (index cache, warm)` remains a single item.

## Related / Follow-Up

- Duplicate task linkage: Search for and link existing issue tracking this (TBD by maintainer).
- Optional docs: Consider a short note in `lib/features/ai/README.md` referencing array-first usage for multi-item creation.

## Status

- Overall: Implemented and validated locally

Checklist:
- [x] Parser utility implemented (`parseItemListString`)
- [x] Batch handler updated to prefer arrays + robust fallback
- [x] Unified inference fallback updated to use robust parsing
- [x] Function schema updated to `oneOf` (array|string) with docs
- [x] Conversation and preconfigured prompts updated (array-first guidance)
- [x] Unit tests added (parser) and extended (batch handler)
- [x] Analyzer zero warnings
- [x] Targeted tests pass
- [x] CHANGELOG updated
- [ ] Full test suite run (optional, recommended before release)
- [ ] Link duplicate tracking task/issue (TBD by maintainer)
