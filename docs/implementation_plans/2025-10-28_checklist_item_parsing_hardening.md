# Checklist Item Parsing Hardening (Arrays Preferred, Robust Fallback)

## Summary

- Problem: Batch checklist creation split items on every comma, so legitimate commas inside a single
  item (or within parentheses) produced multiple unintended items. Models were also encouraged to
  provide comma-separated strings, which increased the chance of this failure.
- Solution: Prefer a JSON array of strings for `add_multiple_checklist_items.items`. When a string
  must be used, parse it robustly so commas within quotes, escapes, or grouping constructs do not
  split.
- Scope: AI checklist updates (function-calling), batch creation, prompts and schema guidance, and
  minimal shared parsing utility.

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
  - `lib/features/ai/functions/lotti_batch_checklist_handler.dart` — accept arrays; use robust
    fallback parsing
  - `lib/features/ai/repository/unified_ai_inference_repository.dart` — robust fallback in unified
    processing; directives ordering
  - `lib/features/ai/functions/checklist_completion_functions.dart` — function schema `oneOf` (
    array|string) and updated description
  - `lib/features/ai/functions/lotti_conversation_processor.dart` — continuation prompt guidance
    updated
  - `lib/features/ai/util/preconfigured_prompts.dart` — array-first guidance with fallback
- Tests
  - `test/features/ai/utils/item_list_parsing_test.dart` — parser unit tests
  - `test/features/ai/functions/lotti_batch_checklist_handler_test.dart` — array acceptance, quotes,
    escaped comma, parentheses

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

- Model compliance: Some models may still emit strings. Mitigated by robust parser and strong
  schema/prompt guidance favoring arrays.
- Parser correctness: Covered by unit tests; logic is linear and limited in scope (no regex
  backtracking).
- Performance: O(n) per input; inputs are small (tool arguments), so cost is negligible.

## Rollback Strategy

- Revert to previous simple split logic in batch handler and unified inference if needed.
- Retain parser utility (unused) for future guarded rollout.
- Remove array guidance from prompts if rollback desired, though recommended to retain.

## Acceptance Criteria

- Analyzer reports zero warnings.
- Tests pass:
  - Parser unit tests exercise quotes, escapes, grouping, trimming, unicode, newlines/tabs, and
    best‑effort behavior for unbalanced groups.
  - Batch handler tests validate array (incl. non‑string values filtered, empty arrays rejected) +
    string fallback (quotes, escapes, grouping) including complex cases.
  - Unified inference integration test verifies string fallback path uses robust parsing and creates
    checklist items.
  - Function schema test verifies `oneOf` (array|string) preference for arrays.
  - Preconfigured prompts/conversation tests remain green.
- CHANGELOG entry documents the fix.
- Manual sanity: Verify an item like `Start database (index cache, warm)` remains a single item.

## Related / Follow-Up

- Duplicate task linkage: Search for and link existing issue tracking this (TBD by maintainer).
- Optional docs: Consider a short note in `lib/features/ai/README.md` referencing array-first usage
  for multi-item creation.

## Status

- Overall: Implemented and validated locally

Changes landed:

- [x] Parser utility implemented (`parseItemListString`)
- [x] Batch handler updated to prefer arrays + robust fallback (filters null/empty/non-string
  properly)
- [x] Unified inference fallback updated to use robust parsing
- [x] Function schema updated to `oneOf` (array|string) with array-first description
- [x] Conversation + preconfigured prompts updated (array-first guidance, string fallback rules)
- [x] Retry prompt updated to show array-first and fallback rules
- [x] Tests added/extended:
  - Parser: nested quotes, grouping, escapes, unbalanced groups, unicode, newlines/tabs, trimming
  - Batch handler: array (empty, non-string/null filtering), string fallback (quotes, escapes,
    grouping), single-item array
  - Unified inference: integration verifying robust parsing on string fallback
  - Schema: oneOf presence and array-first preference
- [x] Analyzer zero warnings
- [x] Targeted tests pass
- [x] CHANGELOG updated
- [ ] Full test suite run (optional, recommended before release)
- [ ] Link duplicate tracking task/issue (TBD by maintainer)

## Test Coverage (Added)

- Parser:
  - `test/features/ai/utils/item_list_parsing_test.dart`
- Batch handler:
  - `test/features/ai/functions/lotti_batch_checklist_handler_test.dart`
- Unified inference integration (string fallback path):
  - `test/features/ai/repository/unified_ai_inference_repository_test.dart`
  - Function schema (arrays preferred via oneOf):
  - `test/features/ai/functions/checklist_completion_functions_test.dart`

---

## 2025-11-02 Investigation: “All items lumped in one bracketed string”

### Problem Statement

When dictating multiple checklist items, the app sometimes creates a single checklist item whose
title looks like a raw array, for example:

`[Investigate audio quality from Bluetooth headphones, Find out if network connectivity detection triggers sending, Come up with an implementation plan to fix the network issue]`

This matches the attached screenshot and is a regression from the hardening work in
`46a221a5c51e4de380ed891f148a9ecaa9ab69cd`.

### What’s Happening

- Tool set offered for checklist updates includes BOTH single-item (`add_checklist_item`) and
  multi‑item (`add_multiple_checklist_items`).
- Models sometimes choose the single‑item function but place a human‑styled list representation (
  square‑bracketed, comma‑separated) into the `actionItemDescription` string instead of calling the
  multi‑item function.
- Our single‑item handler (`LottiChecklistItemHandler.processFunctionCall`) currently accepts any
  non‑empty string and proceeds to create that as a single checklist item, so the entire bracketed
  list is stored as one item.

### Evidence in Code

- Tools are injected broadly for checklist updates in three places and currently always include the
  multi‑item tool:
  - `lib/features/ai/repository/unified_ai_inference_repository.dart` (three injection points: lines ~676, ~696, ~1569)
- Single‑item handler accepts any non‑empty string:
  `lib/features/ai/functions/lotti_checklist_handler.dart`.
- Batch path is already robust and would parse correctly if the model called
  `add_multiple_checklist_items`.

### Why It Appears Now

- The hardening work improved the multi‑item path and updated prompts to prefer arrays. That likely
  nudged some models to construct bracketed lists, but models may still pick the single‑item tool.
  With the single‑item handler permissive, that list is saved as one item.
- In practice this seems more likely with providers that don’t strictly follow tool schemas or where
  we run fewer rounds (cloud providers) and the model “crams” everything into one call.

### Scope Clarification

- We only need the “pass multiple at once” behavior for GPT‑OSS models running on Ollama (local
  OpenAI‑compatible), due to their multi‑tool‑call limitations at the time of introduction.
- Other Ollama models that support function calling are fine with multiple single calls; they should
  NOT get the multi‑item tool.
- All non‑Ollama providers are also fine with multiple single calls.

### Remediation Plan (Phased)

1) Guard single‑item handler against multi‑lists (pragmatic fix)

- In `LottiChecklistItemHandler.processFunctionCall`, detect common multi‑item patterns and reject with an instructive error.
- Use two simple checks that share logic with the batch path:
  - Bracketed list: trimmed value starts with `[` and ends with `]` and contains a comma.
  - Robust parser length: if `parseItemListString(description)` yields 3+ items, reject. This keeps rules consistent with batch parsing and avoids logic duplication.
- Return a failure `FunctionCallResult` with an error like: “Multiple items detected in a single‑item call. Provide items separately or use the appropriate multi‑item tool if available.”
- The conversation strategy already turns failures into a retry prompt, which will guide the model
  to use the correct function.

2) Provider‑gated tool exposure (Only Ollama + GPT‑OSS models)

- Create new helper: `lib/features/ai/functions/checklist_tool_selector.dart` exposing
  `getChecklistToolsForProvider({required AiConfigInferenceProvider provider, required AiConfigModel model})` to return the appropriate tool list.
- In all three tool injection paths in `unified_ai_inference_repository.dart` (around lines ~676, ~696, ~1569), replace
  direct calls to `ChecklistCompletionFunctions.getTools()` with
  `getChecklistToolsForProvider(provider: provider, model: model)`.
- Include `add_multiple_checklist_items` only when BOTH are true:
  - `provider.inferenceProviderType == InferenceProviderType.ollama`, AND
  - `model.providerModelId` identifies a GPT‑OSS variant (precisely: starts with `gpt-oss:`)
- All other cases (non‑Ollama, or Ollama but not GPT‑OSS) receive only the single‑item tool; models
  can emit multiple single calls if needed.

3) Optional parsing rescue in single‑item handler (deferred)

- If a string clearly encodes a JSON or pseudo‑list, we could parse and internally route to the
  batch handler. This is more invasive and risks false positives; keep as a later improvement if
  needed. => nope let's not

4) Prompt nudge (non‑breaking)

- Keep array‑first guidance as is, but add one explicit line: “Never put square‑bracketed lists into
  `actionItemDescription`.”

5) Prompt adaptation (deferred for now)

- The static preconfigured prompts currently mention both single and multi‑item tools.
- Making prompts fully provider‑aware would require dynamic prompt generation based on available tools.
- For now, keep general guidance; the single‑item guard and conversation retry logic handle tool availability at runtime.
- Future improvement: switch to dynamic prompt templates that only mention tools actually exposed to the model.

### Logging Plan (optional, helpful for validation)

- Add logging calls using the lightweight `lottiDevLog` helper (mirrors to `developer.log` and to `print` inside an `assert` so unit tests can capture output):
  - Single‑item handler: when the multi‑list heuristic matches, log the first ~120 characters and the function name.
  - Unified repository: when assembling tools, log which checklist tools are included for each provider/model combination and whether the multi‑item tool was exposed.

### Decisions

- Multi‑item creation tool is exposed only for the combination: provider is Ollama AND model is a
  GPT‑OSS variant (e.g., `gpt-oss:20b`, `gpt-oss:120b`). All others get only the single‑item tool.
- The single‑item handler strictly fails on bracketed or pseudo‑list inputs; do not auto‑split.
  Provide guidance via retry prompt and log the event.

### Acceptance for Fix

- Attempting to create multiple items via single‑item tool results in a tool‑error + retry prompt,
  not a malformed single item.
- Non‑Ollama providers and Ollama models that are NOT GPT‑OSS do not receive
  `add_multiple_checklist_items`; they emit multiple single calls instead.
- Existing batch path continues to parse correctly when the proper function is used.

### Test Cases for Fix

Unit tests
- Single‑item handler guard
  - Rejects square‑bracketed arrays passed as a single description and responds with guidance that does not assume multi‑item availability (for example: “Multiple items detected in single‑item call. Provide items separately or use the appropriate tool if available.”).
  - Rejects obvious comma‑separated multi‑lists (for example, three or more comma‑separated items) with the same provider‑agnostic guidance (does not assume multi‑item tool availability).
  - Accepts legitimate single items containing commas within grouping constructs such as parentheses (for example, “Setup database (cache, indexes, warm‑up)”).
  - Accepts single items with a single descriptive comma (for example, “Buy milk, 2%”).
  - Reproduces the screenshot input and confirms the guard produces an error, not a malformed single item.

- Tool selection (provider/model gating)
  - For Ollama with a GPT‑OSS model identifier, returns the three checklist tools: suggest completion, add single item, and add multiple items.
  - For Ollama with a non‑GPT‑OSS model, returns only suggest completion and add single item; excludes add multiple.
  - For all non‑Ollama providers (OpenAI, Anthropic, Gemini, genericOpenAi, OpenRouter, Nebius, etc.), returns only suggest completion and add single item; excludes add multiple.

Integration tests
- Conversation flow without the multi‑item tool
  - With a non‑Ollama provider, verify that a bracketed list sent to the single‑item function yields a tool error, a retry prompt is generated, and subsequent creation proceeds via multiple single‑item calls.
  - Verify logging reflects that the multi‑item tool was unavailable for the provider.

- Conversation flow with the multi‑item tool
  - With Ollama + GPT‑OSS, verify that multiple items are created via a single add‑multiple‑items function call with no fallback to multiple single calls.
  - Verify logging reflects the presence of the multi‑item tool for the provider/model.

Manual test checklist
- Non‑Ollama provider (OpenAI/Anthropic): “Add milk, eggs, and cheese …” results in three separate items via three single‑item calls; no single item with bracketed text appears.
- Ollama with GPT‑OSS model: same input results in a single multi‑item call creating all items.
- Ollama with non‑GPT‑OSS model: same input results in three single‑item calls; the multi‑item tool is not available.
- Edge cases: parentheses grouping and one‑comma descriptions are accepted as single items; bracketed lists sent to the single‑item function are rejected with guidance.
- The screenshot reproduction phrase creates three separate items (or recovers via retry), never a single bracketed entry.

Checklist tool selector utility
- New helper file: `lib/features/ai/functions/checklist_tool_selector.dart`.
- Provides `getChecklistToolsForProvider(provider, model)` to determine the correct set of checklist tools per provider/model.
- Ensures the execution uses only the tools actually available for each provider/model combination (for example, multi‑item tool only for Ollama + GPT‑OSS). Prompts remain general for now.

Regression checks
- Analyzer passes with zero warnings and code is formatted.
- Full unit and integration suite is green; no regressions in checklist creation flows.

### Rollout Order

1. Implement single‑item guard + extra logging.
2. Gate multi‑item tool by provider (Ollama‑only to start).
3. Evaluate whether any provider warrants inclusion beyond Ollama.

If you approve, I can add the lightweight guard + logging first so you can reproduce and share logs,
then we can gate the multi‑item tool exposure.
