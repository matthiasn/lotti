# Automatic Task Label Assignment via AI Function Calls

## Summary

- Extend the labels feature to support automatic label assignment from AI prompts (initial task
  setup audio or subsequent audio/text updates).
- Provide the model with the complete list of labels (id + name) at inference time and enable a
  function call to assign labels by ID.
- Integrate the new function into both streaming tool-call processing and the conversation-based
  checklist workflow.
- Follow AGENTS.md discipline: MCP-first, analyzer/test green, targeted changes, no generated files
  edited, update docs and CHANGELOG.

## Goals

- Add a dedicated function tool (assign_task_labels) that adds one or more labels to a task by ID.
- Make the list of all labels available to checklist update prompts (as tuples: id + name) so the
  model can pick precise IDs.
- Support both entry-driven flows:
  - Initial task setup audio: automatic transcription → automatic checklist updates pipeline → label
    assignment function when appropriate
  - Subsequent recordings or text prompts that trigger checklist updates
- Ensure the function is idempotent and resilient when labels already exist or are deleted.

## Non-Goals

- Creating new labels through AI (only assignment of existing labels).
- Removing labels through AI (future follow-up if needed).
- Changing the existing audio transcription pipeline (it remains text-only; label assignment happens
  in the checklist updates step).

## Design Overview

1) Function Tool: assign_task_labels

- Name: assign_task_labels
- Parameters:
  - labelIds: array<string> (required) — one or more label IDs to add
  - Optional future fields (not used now): reason, confidence
- Behavior: non-destructive add-only. Under the hood, uses LabelsRepository.addLabels(
  journalEntityId, addedLabelIds) which unions with existing labelIds in metadata and triggers DB
  reconciliation.

2) Prompt Enrichment with Labels

- Update the checklist updates preconfigured prompt to include an “Available Labels” block
  containing tuples of (id, name) for all labels.
- Add a new template placeholder {{labels}} to inject a compact JSON array of
  objects: [{"id":"...","name":"..."}, ...].
- If there are no labels, inject [] and instruct the model to skip label assignment.

3) Tooling Integration

- Include the new tool in both flows where checklist update tools are added:
  - UnifiedAiInferenceRepository._runCloudInference: add LabelFunctions.getTools() alongside
    ChecklistCompletionFunctions and TaskFunctions when AiResponseType.checklistUpdates.
  - UnifiedAiInferenceRepository._processWithConversation (conversation approach): include the same
    tool list.

4) Tool Call Handling (Non-conversation Mode)

- UnifiedAiInferenceRepository.processToolCalls:
  - Add branch for assign_task_labels
  - Parse arguments (JSON); collect unique, non-empty labelIds
  - Validate each ID exists (EntitiesCacheService.getLabelById or JournalDb.getLabelDefinitionById)
  - Call LabelsRepository.addLabels(journalEntityId: task.id, addedLabelIds: validIds)
  - Log success/failure with LoggingService

5) Tool Call Handling (Conversation Mode)

- LottiConversationProcessor.processToolCalls:
  - Add an else-if branch for assign_task_labels mirroring the non-conversation behavior
  - Respond with a succinct tool response message (e.g., “Assigned N labels: …”) via
    manager.addToolResponse
  - Keep currentTask reference updated only if JournalDb returns a refreshed task (not strictly
    required for labels, but consistent)

6) Prompt Building

- PromptBuilderHelper: detect {{labels}} and replace with JSON built from
  JournalDb.getAllLabelDefinitions()
  - Only include non-deleted definitions
  - Shape: [{"id": "uuid", "name": "Label Name"}]
  - Keep this independent of {{task}} so either or both can be present

7) Safety & Edge Cases

- Empty or missing labelIds → ignore safely (no-op) and return a tool response indicating no labels
  assigned
- Unknown or deleted IDs → filter out before calling repository
- Duplicate IDs → de-duplicate before calling repository (repository is idempotent as well)
- Private labels → included; AI may still decide to use them. UI visibility is separate from
  assignment authority.

## Code Touchpoints

- New: lib/features/ai/functions/label_functions.dart
  - Defines LabelFunctions.assignTaskLabels and ChatCompletionTool schema
  - Export a static List<ChatCompletionTool> getTools()

- Update: lib/features/ai/repository/unified_ai_inference_repository.dart
  - _runCloudInference: include ...LabelFunctions.getTools() for checklistUpdates
  - _processWithConversation: include tool in tools list
  - processToolCalls: handle assign_task_labels by calling LabelsRepository.addLabels

- Update: lib/features/ai/functions/lotti_conversation_processor.dart
  - Add assign_task_labels handling with validation + manager.addToolResponse

- Update: lib/features/ai/util/preconfigured_prompts.dart
  - checklistUpdatesPrompt.systemMessage: mention the new function and rules for label assignment
  - checklistUpdatesPrompt.userMessage: add an “Available Labels” JSON block using {{labels}}

- Update: lib/features/ai/helpers/prompt_builder_helper.dart
  - Detect and replace {{labels}} with JSON from JournalDb.getAllLabelDefinitions()

- Optional Docs: lib/features/labels/README.md
  - Add a short “AI-based assignment” section describing the function-call flow and that models use
    label IDs

## Implementation Steps

1) Define function schema

- Create lib/features/ai/functions/label_functions.dart
  - class LabelFunctions { static const String assignTaskLabels = 'assign_task_labels'; static
    List<ChatCompletionTool> getTools() { ... } }
  - Parameters JSON Schema: type=object, properties: labelIds (type=array of strings),
    required=['labelIds']

2) Prompt updates

- Extend checklistUpdatesPrompt in lib/features/ai/util/preconfigured_prompts.dart
  - System message: add a 5th tool “assign_task_labels” with one-line description: “Add one or more
    labels to the task using provided label IDs.”
  - User message: append section:
    Available labels (id and name):
    ```json
    {{labels}}
    ```

3) Prompt builder

- In lib/features/ai/helpers/prompt_builder_helper.dart, after building the user message:
  - If user message contains {{labels}}, replace with compact JSON of [{id,name}] from
    JournalDb.getAllLabelDefinitions()
  - Filter out deleted labels
  - If none: inject []

4) Tool registration

- In lib/features/ai/repository/unified_ai_inference_repository.dart:
  - _runCloudInference: when AiResponseType.checklistUpdates and model.supportsFunctionCalling,
    include ...LabelFunctions.getTools() in tools
  - _processWithConversation: include same in tools

5) Tool call handling (non-conversation)

- In UnifiedAiInferenceRepository.processToolCalls:
  - Add branch for LabelFunctions.assignTaskLabels
  - Parse arguments, validate IDs against cache/DB, de-duplicate
  - Call ref.read(labelsRepositoryProvider).addLabels(journalEntityId: task.id, addedLabelIds: ids)
  - Log outcome

6) Tool call handling (conversation)

- In LottiConversationProcessor.processToolCalls:
  - Add similar branch using LabelsRepository
  - manager.addToolResponse with success/failure summary

7) Telemetry

- Use LoggingService.captureEvent for function-call start/end with counts

8) Docs & changelog

- Add a short section to lib/features/labels/README.md documenting the AI label assignment flow
- Update CHANGELOG.md under “Added”

## Testing Strategy

Analyzer & formatting

- make analyze (zero warnings policy)
- dart format . (via dart-mcp.dart_format)

Unit tests

- test/features/ai/functions/label_functions_schema_test.dart
  - Validates ChatCompletionTool schema (name, required parameters)

- test/features/ai/helpers/prompt_builder_helper_labels_test.dart
  - When {{labels}} present and DB returns two labels, the JSON is injected with both id/name pairs
  - When no labels exist, [] is injected

- test/features/ai/repository/unified_ai_inference_repository_labels_test.dart
  - Tools list for checklistUpdates includes assign_task_labels
  - Given a tool call with valid label IDs, processToolCalls adds them to metadata (verify via
    JournalDb and LabelsRepository mocks)
  - Given unknown/deleted IDs, they’re filtered, no crash

- test/features/ai/functions/lotti_conversation_processor_labels_test.dart
  - Conversation path handles assign_task_labels; manager.addToolResponse called; repository invoked
    once with de-duplicated IDs

Integration tests

- Extend existing checklist updates integration to assert labels added when model returns
  assign_task_labels

Performance

- No special performance changes; repository add is O(n) in IDs with cache/DB lookups. Covered by
  existing labels_performance_test for reconciliation.

## Risks & Mitigations

- Ambiguous label names → The model sees both name and id; we require ID usage in the function.
  Mitigate by showing all labels explicitly and letting the model choose.
- Destructive overwrites → We use add-only function to avoid removing user-applied labels.
- Tool-call correctness → Tests cover both streaming and conversation flows with
  partial/duplicate/unknown IDs.
- Prompt bloat → Only injects a compact id/name JSON; if label count becomes very large, we can
  paginate or only include top-K by usage later (not in scope).

## Rollout & Monitoring

- Behind existing prompt configuration: checklist updates must be enabled for the category.
- LoggingService events (domain: 'labels_ai_assignment') for visibility.
- QA checklist: verify label injection in prompt (inspect logs), verify assignment on both initial
  and follow-up recordings, verify no removal of existing labels.

### Feature Flag & Shadow Mode (Easy Add)

- Global feature flag `enableAiLabelAssignment` (default: on) gates:
  - inclusion of LabelFunctions tool definitions
  - {{labels}} injection in PromptBuilderHelper
  - processing branch in processToolCalls and conversation strategy
- Per-category override already covered via prompt allowlists; flag applies as an additional global
  gate.
- Shadow mode `aiLabelAssignmentShadow` (debug/QA only):
  - Includes labels in the prompt but suppresses assignment side effects
  - Emits the structured tool response to logs and a non-blocking UI toast (“Suggested labels: … (
    shadow mode)”) without persisting
  - Useful for staged rollout and A/B evaluation

## Implementation Discipline

- Prefer MCP (dart-mcp) for analyze, format, tests.
- Zero analyzer warnings before PR; do not edit generated code.
- Keep changes minimal and isolated to AI prompt/tool plumbing and labels repository usage.
- Update docs and CHANGELOG.

---

# Addendum — Addressing Review Feedback

This addendum strengthens AI decision-making, user control, error handling, observability, and
edge-case coverage. It refines the original plan without changing core scope (assign existing labels
by ID).

## UX Polish — Label Creation and Presentation

The following UX improvements were applied to make label creation and presentation smoother and more
predictable, based on hands-on usage feedback:

- Preserve user casing end-to-end
  - Task label selector search no longer lowercases the “Create from search” suggestion; it passes
    the raw typed text to the label editor unchanged.
  - Labels settings search behaves the same and opens the editor prefilled with the exact search
    text (unchanged), if the user taps “Create”.
  - Rationale: users often include capitalization and emoji in names; we avoid surprising
    transformations.

- Capitalized search fields where labels are created from search
  - Task label selector search input uses `TextCapitalization.words`.
  - Labels settings search input now also uses `TextCapitalization.words`.

- Consistent “Create from search” affordance in settings
  - When a settings search yields no results, a centered affordance offers to create a new label
    with the current query, opening the label editor prefilled with that text.

- Label chip presentation refined
  - In presentation contexts (task view, task cards), chips no longer show the leading color dot.
  - The frame encodes the color more prominently (stronger border/background); the label text (often
    with emoji) stands on its own.
  - In settings, the dot remains unchanged to aid quick visual scanning while managing labels.

- Future idea: “Suggest labels” button
  - Add an optional “AI suggestions” action on a task to propose labels for existing tasks in bulk.
    Stays out-of-scope for this iteration but aligns with the function-calling plumbing already in
    place.

## Decision Criteria & Prompt Template (Exact Text)

We will extend the checklist updates preconfigured prompt with explicit instructions that define
when and how to assign labels.

1) System message additions (append to checklistUpdatesPrompt.systemMessage):

"""

5. assign_task_labels: Add one or more labels to the task using label IDs
  - Only assign when you have HIGH confidence a label applies based on the user’s input and task
    context
  - Prefer precision over recall: avoid assigning labels when ambiguous
  - Never guess a label ID: choose from the provided Available Labels section only
  - If multiple labels match, apply up to 3 highly relevant labels; do not exceed 3
  

Decision rubric:

- HIGH: Clear, direct mention or strong semantic match (e.g., “this is a bug” → bug)
- MEDIUM/LOW: Hints or weak signals — DO NOT assign

Ambiguity handling:

- If unsure which of several labels to apply, pick none
  """

2) User message additions (append a section under Task Details):

"""
Available Labels (id and name):

```json
{{
  labels
}}
```

Assignment rules:

- Assign at most 3 labels
- Only assign with HIGH confidence
- Skip ambiguous or borderline cases
  """

## Label Context

- Renames are handled by stable IDs; merges are out of scope for V1 (see Edge Cases).

## User Control, Transparency, and Undo

- Source attribution: record AI assignments using LoggingService events. Metadata remains the single
  source for current labels; provenance is tracked via logs.
- UI feedback (MVP): show a non-blocking toast in Task Details: “Assigned labels: bug, backend.
  Undo”.
  - Undo action removes the assigned labels via LabelsRepository.removeLabel for each.
- Opt-out controls:
  - Global preference: “Allow AI to assign labels” (default on)
  - Per-category toggle: extends existing automatic prompt gating. If disabled, the tool is not
    included.

## Performance Limits and Prompt Size

- Label injection limit: include up to 200 labels. If more exist, include the top 100 by usage and
  the next 100 alphabetically. Add summary note: “Showing 200 of N labels”.
- Sorting: top by usage desc, ties by name asc.
- JSON encoding: use proper JSON encoding for names to prevent prompt injection via label names.

Implementation details for usage ranking:

- Reuse existing DB stats: JournalDb.watchLabelUsageCounts() exists at lib/database/database.dart:
  895. Add a snapshot variant getLabelUsageCounts() to avoid maintaining a stream for prompt
  building.
- PromptBuilderHelper will request both getAllLabelDefinitions() and getLabelUsageCounts(); combine
  to compute Top-K (50) + alpha (50) set, then encode.
- Fallback: if stats query fails, use alphabetical order and still cap at 100.

Optional filter (easy add):

- Exclude private labels from prompt injection when `includePrivateLabelsInPrompts` is false (
  default true). This prevents exposing private labels to external providers if desired.

## Error Handling and Recovery

- Per-label atomicity: attempt to assign labels independently and return structured tool responses
  indicating assigned/invalid/skipped.
- Partial failures: proceed with valid IDs, report invalids in the tool response. The conversation
  strategy may request a retry only for invalids if subsequent rounds occur.
- Rate limiting (MVP): max 5 labels per function call; subsequent calls within 5 minutes for the
  same task are logged and ignored (to prevent churn).

Tool response format (conversation + non-conversation):

```json
{
  "function": "assign_task_labels",
  "request": {
    "labelIds": [
      "id-a",
      "id-b"
    ]
  },
  "result": {
    "assigned": ["id-a"],
    "invalid": ["id-b"],
    "skipped": []
  },
  "message": "Assigned 1 label; 1 invalid"
}
```

## Observability and Metrics

- LoggingService events (domain: 'labels_ai_assignment'):
  - assignment_attempted(count, taskId)
  - assignment_succeeded(count, taskId, labelIds)
  - assignment_failed(count, taskId, invalidIds)
  - assignment_rate_limited(taskId)
  - undo_triggered(taskId, labelIds)

## Edge Cases

- Renamed labels: ID stability ensures continuity; no action needed.
- Merged labels: out-of-scope for V1. Future: migration routine to map old IDs → new ID and
  reconciliation of metadata.
- Archived/deprecated labels: if represented by deletedAt or archived flag, exclude from prompt and
  validation.
- Excessive assignment: rate limit + 3-label cap from prompt rules.
- Concurrency: validate against DB just before assignment; if the task was deleted or labels changed
  concurrently, skip and report invalid/skipped in tool response.

## Exact Integration Points (file and approximate line numbers)

- Register tool for checklist updates
  - lib/features/ai/repository/unified_ai_inference_repository.dart:644–647 (_runCloudInference
    tools section) — add ...LabelFunctions.getTools() alongside ChecklistCompletionFunctions and
    TaskFunctions
  - lib/features/ai/repository/unified_ai_inference_repository.dart:1640–1700 (_
    processWithConversation tools list) — same addition

- Handle tool calls (non-conversation)
  - lib/features/ai/repository/unified_ai_inference_repository.dart:1014–1425 (processToolCalls)
    - Insert new else-if branch after line 1406 (post checklist item processing) and before line
      1424 (return)

- Handle tool calls (conversation)
  - lib/features/ai/functions/lotti_conversation_processor.dart:300–470 (
    LottiChecklistStrategy.processToolCalls)
    - Insert new else-if branch after set_task_language handling (~320–395) and before
      suggest_checklist_completion (~410–455)

## Expanded Testing Scenarios

- Max-volume prompt: 500 labels in DB → verify top 100 injection with correct ordering and summary
  note.
- Special characters in label names: ensure JSON encoding and no prompt injection; names like "}"
  or "\n" are escaped.
- Conversation retries: first call contains an invalid ID, second call corrects it — ensure only
  valid applied, structured tool responses returned.
- Concurrency: simulate label deletion between injection and assignment; invalid bucket populated.
- Rate limiting: subsequent calls within 5 minutes ignored and logged.
- Undo flow: toast shown, undo removes labels and increments undo metric.

Test file naming conventions:

- test/features/ai/functions/label_functions_test.dart — tool schema and registration
- test/features/ai/helpers/prompt_builder_helper_labels_test.dart — labels injection and
  capping/ordering
- test/features/ai/repository/unified_ai_inference_repository_labels_test.dart — non-conversation
  flow with rate limiting
- test/features/ai/functions/lotti_conversation_processor_labels_test.dart — conversation flow
  branch with structured tool responses

## Documentation & Privacy

- User guide (docs/user_guides/ai_labels.md):
  - Explain when labels are auto-assigned, how to undo, and how to opt out (global and
    per-category).
  - Clarify that the model sees label names and IDs (names sent to provider; IDs used in function
    calls).
  - Note privacy implications: label names become part of the model input.
- Developer notes: add a short section about feature flag and shadow mode and how to toggle them in
  dev builds.
- README updates: lib/features/labels/README.md add “AI assignment” section with summary + links.

## Technical Notes

- JSON Injection: always construct label JSON via a safe encoder; never manually interpolate.
- Cache Consistency: prefer EntitiesCacheService for hot lookups but verify against JournalDb before
  applying. DB is the source of truth.
- Tool Responses: return structured JSON payloads (see format above) to support future programmatic
  consumption.
