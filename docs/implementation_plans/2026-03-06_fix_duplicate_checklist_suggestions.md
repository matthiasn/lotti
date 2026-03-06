# Fix Duplicate Checklist Item Suggestions

**Date:** 2026-03-06
**Priority:** P0
**Status:** Plan

## Problem Statement

The AI task agent repeatedly proposes `add_checklist_item` changes for items that
already exist in the task's checklist, have been previously confirmed, or were
explicitly rejected. This creates a "nagging" experience that breaks user trust.

**Example from screenshots:** The task "Fix Agent Entity Sync Regression" already
has 12 checklist items (e.g., "Ensure 95% or higher patch coverage", "Create pull
request"). Despite this, the agent proposes adding all 8 of those same items again
as "Proposed changes."

## Current Pipeline (Before Fix)

```mermaid
flowchart TD
    LLM["LLM emits tool call\nadd_checklist_item / update_checklist_item"]
    STRAT["TaskAgentStrategy.processToolCalls()"]
    DEFER{Is tool deferred?}
    EXEC["Execute immediately"]
    BATCH{Batch tool?}
    ADD_SINGLE["ChangeSetBuilder.addItem()"]
    ADD_BATCH["ChangeSetBuilder.addBatchItem()"]
    REDUND{"_checkRedundancy()\n(update_checklist_item ONLY)"}
    SKIP_REDUND["Suppress redundant update"]
    ACCUMULATE["Accumulate in _items list"]
    BUILD["ChangeSetBuilder.build()"]
    DEDUP{"_deduplicateItems()\nvs pending change sets ONLY"}
    PERSIST["Persist ChangeSetEntity"]
    UI["ChangeSetSummaryCard\nshows proposals to user"]
    CONFIRM["User confirms"]
    REJECT["User rejects"]
    DISPATCH["TaskToolDispatcher.dispatch()"]
    DECISION["Persist ChangeDecisionEntity"]
    GONE["Decision leaves dedup window\nwhen change set resolves"]

    LLM --> STRAT
    STRAT --> DEFER
    DEFER -->|No| EXEC
    DEFER -->|Yes| BATCH
    BATCH -->|No| ADD_SINGLE
    BATCH -->|Yes| ADD_BATCH
    ADD_BATCH --> REDUND
    REDUND -->|Redundant| SKIP_REDUND
    REDUND -->|Not redundant| ACCUMULATE
    ADD_SINGLE --> ACCUMULATE
    ACCUMULATE --> BUILD
    BUILD --> DEDUP
    DEDUP --> PERSIST
    PERSIST --> UI
    UI --> CONFIRM
    UI --> REJECT
    CONFIRM --> DISPATCH
    REJECT --> DECISION
    DECISION --> GONE

    style REDUND fill:#f97316,color:#fff
    style DEDUP fill:#f97316,color:#fff
    style GONE fill:#ef4444,color:#fff
```

**Orange = incomplete guards. Red = data loss.** The three gaps are:
- `_checkRedundancy` ignores `add_checklist_item` entirely
- `_deduplicateItems` never checks the task's actual checklist
- Rejected decisions vanish from the dedup window after resolution

## Root Cause Analysis

The deduplication pipeline has **three structural gaps**:

### Gap 1: No title-based dedup for `add_checklist_item` against existing items

`ChangeSetBuilder._checkRedundancy()` (line 394 of `change_set_builder.dart`) only
handles `update_checklist_item`. When the agent calls `add_checklist_item` with a
title that already exists on the task, **nothing catches it**. The method explicitly
returns `null` for non-update tools.

### Gap 2: `_deduplicateItems()` only checks against other pending change sets

`ChangeSetBuilder._deduplicateItems()` (line 288) compares proposed items against
items in existing *pending change sets* — not against the actual checklist items on
the task. So if all previous change sets are resolved, a new wake can re-propose the
exact same additions.

### Gap 3: Rejected decisions evaporate after change set resolution

`ChangeDecisionEntity` records ARE persisted when items are rejected (in
`ChangeSetConfirmationService.rejectItem()`), and `AgentRepository.getRecentDecisions()`
CAN query them. However, the `ChangeSetBuilder.build()` method only receives
`existingPendingSets` — once a change set is fully resolved, its rejected items are
no longer visible to the dedup pipeline. A subsequent agent wake can immediately
re-propose a rejected item.

### Visualizing the Three Gaps

```mermaid
flowchart LR
    subgraph GAP1["Gap 1: Add-Item Blind Spot"]
        A1["Agent proposes:\nadd 'Buy groceries'"]
        A2["Task already has:\n'Buy groceries'"]
        A3["_checkRedundancy():\nonly handles updates"]
        A4["DUPLICATE\nreaches UI"]
        A1 --> A3
        A2 -.->|not checked| A3
        A3 --> A4
    end

    subgraph GAP2["Gap 2: Task-State Blindness"]
        B1["All prior change sets\nresolved"]
        B2["_deduplicateItems():\nchecks pending sets only"]
        B3["Pending sets = empty"]
        B4["DUPLICATE\nreaches UI"]
        B1 --> B3
        B3 --> B2
        B2 --> B4
    end

    subgraph GAP3["Gap 3: Rejection Amnesia"]
        C1["User rejects\n'Add: Buy groceries'"]
        C2["ChangeDecisionEntity\npersisted"]
        C3["Change set resolves\n(all items decided)"]
        C4["Next wake:\nrejection invisible"]
        C5["DUPLICATE\nre-proposed"]
        C1 --> C2
        C2 --> C3
        C3 --> C4
        C4 --> C5
    end

    style A4 fill:#ef4444,color:#fff
    style B4 fill:#ef4444,color:#fff
    style C5 fill:#ef4444,color:#fff
    style GAP1 fill:#fef3c7,stroke:#f59e0b
    style GAP2 fill:#fef3c7,stroke:#f59e0b
    style GAP3 fill:#fef3c7,stroke:#f59e0b
```

### Why prompt engineering alone cannot fix this

The agent's "One-Strike Rule" observation shows awareness but no enforcement.
The LLM receives the full checklist in its context, yet still proposes duplicates
because:
- It generates tool calls based on patterns, not exact string matching
- The deferred-tool architecture intercepts calls *after* the LLM emits them
- There is no code-level guard between the LLM's output and the UI

## Solution Architecture

Add three layers of defense that make duplicate proposals structurally impossible:

```mermaid
flowchart TD
    LLM["LLM emits add_checklist_item\n'Ensure 95% coverage'"]

    subgraph LAYER1["Layer 1: Title-Match Guard (NEW)"]
        direction TB
        RESOLVE["ExistingChecklistTitlesResolver\nfetches task's current items"]
        NORMALIZE["Normalize: lowercase + trim"]
        MATCH{"Title already\nexists?"}
        SUPPRESS1["Suppress: return redundancy detail\n'already exists in the checklist'"]
    end

    subgraph LAYER2["Layer 2: Rejection History (NEW)"]
        direction TB
        QUERY["Query ChangeDecisionEntity\nverdict = rejected"]
        FINGER["Compute fingerprints from\nrejected decisions"]
        MATCH2{"Fingerprint\nin rejected set?"}
        SUPPRESS2["Suppress: drop from\ndeduped list"]
    end

    subgraph LAYER3["Layer 3: Cross-Wake Dedup (EXISTS)"]
        direction TB
        PENDING["Gather items from\nexisting pending change sets"]
        MATCH3{"Fingerprint in\npending sets?"}
        SUPPRESS3["Suppress: already\nqueued for review"]
    end

    subgraph LAYER4["Layer 4: Provider Dedup (EXISTS)"]
        direction TB
        RACE["_deduplicateChangeSets()\ncollapses race-condition duplicates"]
    end

    UI["ChangeSetSummaryCard\nshows ONLY genuinely new proposals"]

    LLM --> RESOLVE
    RESOLVE --> NORMALIZE
    NORMALIZE --> MATCH
    MATCH -->|Yes| SUPPRESS1
    MATCH -->|No| QUERY
    QUERY --> FINGER
    FINGER --> MATCH2
    MATCH2 -->|Yes| SUPPRESS2
    MATCH2 -->|No| PENDING
    PENDING --> MATCH3
    MATCH3 -->|Yes| SUPPRESS3
    MATCH3 -->|No| RACE
    RACE --> UI

    style LAYER1 fill:#059669,color:#fff,stroke:#059669
    style LAYER2 fill:#059669,color:#fff,stroke:#059669
    style LAYER3 fill:#2563eb,color:#fff,stroke:#2563eb
    style LAYER4 fill:#2563eb,color:#fff,stroke:#2563eb
    style SUPPRESS1 fill:#ef4444,color:#fff
    style SUPPRESS2 fill:#ef4444,color:#fff
    style SUPPRESS3 fill:#ef4444,color:#fff
```

**Green = new guards. Blue = existing guards. Red = suppression points.**

## Data Flow: Fixed Pipeline

```mermaid
sequenceDiagram
    participant LLM as LLM
    participant Strategy as TaskAgentStrategy
    participant Builder as ChangeSetBuilder
    participant DB as JournalDb / ChecklistRepo
    participant AgentRepo as AgentRepository
    participant Sync as AgentSyncService
    participant UI as ChangeSetSummaryCard

    LLM->>Strategy: add_multiple_checklist_items({items: [...]})
    Strategy->>Builder: addBatchItem(toolName, args)

    Note over Builder: Per-item loop begins

    Builder->>DB: existingChecklistTitlesResolver()
    DB-->>Builder: {"ensure 95% coverage", "create pull request", ...}

    rect rgb(5, 150, 105)
        Note over Builder: NEW: _checkAddRedundancy()
        Builder->>Builder: title "Ensure 95% coverage" matches existing
        Builder-->>Builder: SUPPRESS (redundant)
    end

    Builder->>DB: checklistItemStateResolver(itemId)
    DB-->>Builder: {title, isChecked}
    Builder->>Builder: _checkRedundancy() for updates
    Builder->>Builder: Accumulate non-redundant items

    Note over Builder: Per-item loop ends

    Strategy->>Builder: build(syncService, existingPendingSets, rejectedFingerprints)

    rect rgb(5, 150, 105)
        Note over Builder: NEW: rejection-aware dedup
        Builder->>AgentRepo: getRecentDecisions(agentId, taskId)
        AgentRepo-->>Builder: [rejected decisions with args]
        Builder->>Builder: Add rejected fingerprints to dedup set
    end

    Builder->>Builder: _deduplicateItems(proposed, existing, rejectedFingerprints)
    Builder->>Sync: upsertEntity(changeSetEntity)
    Sync-->>UI: Stream update
    UI->>UI: Render only genuinely new proposals
```

## Component Dependency Map

```mermaid
graph LR
    subgraph WORKFLOW["task_agent_workflow.dart"]
        WF["TaskAgentWorkflow.execute()"]
    end

    subgraph STRATEGY["task_agent_strategy.dart"]
        TS["TaskAgentStrategy"]
        ACS["_addToChangeSet()"]
    end

    subgraph BUILDER["change_set_builder.dart"]
        CSB["ChangeSetBuilder"]
        ADD_R["_checkAddRedundancy() NEW"]
        UPD_R["_checkRedundancy()"]
        DEDUP["_deduplicateItems()"]
        BUILD["build()"]
    end

    subgraph FILTER["change_proposal_filter.dart"]
        CPF["ChangeProposalFilter"]
    end

    subgraph REPOS["Repositories & DB"]
        CR["ChecklistRepository"]
        AR["AgentRepository"]
        JDB["JournalDb"]
    end

    subgraph MODEL["Models"]
        CI["ChangeItem"]
        CSE["ChangeSetEntity"]
        CDE["ChangeDecisionEntity"]
    end

    subgraph SERVICE["Confirmation"]
        CCS["ChangeSetConfirmationService"]
        TTD["TaskToolDispatcher"]
    end

    WF --> TS
    WF --> CSB
    WF -->|wire resolvers| CR
    WF -->|query rejections| AR
    TS --> ACS
    ACS --> CSB
    ACS --> CPF
    CSB --> ADD_R
    CSB --> UPD_R
    CSB --> DEDUP
    CSB --> BUILD
    BUILD -->|persist| CSE
    CCS -->|persist| CDE
    CCS --> TTD
    ADD_R -.->|NEW dependency| CR
    DEDUP -.->|NEW: rejected fingerprints| CDE

    style ADD_R fill:#059669,color:#fff
    style DEDUP fill:#f97316,color:#fff
    style CDE fill:#f97316,color:#fff
```

**Green = new component. Orange = modified component.**

## Implementation Plan

### Step 1: Add existing-checklist-items resolver to `ChangeSetBuilder`

**Files:** `change_set_builder.dart`, `task_agent_workflow.dart`

Add a new callback type and field to `ChangeSetBuilder`:

```dart
/// Resolves all existing checklist item titles for the target task.
/// Returns a set of normalized (lowercased, trimmed) titles.
typedef ExistingChecklistTitlesResolver = Future<Set<String>> Function();
```

In `task_agent_workflow.dart`, wire it up using `ChecklistRepository.getChecklistItemsForTask()`:

```dart
final changeSetBuilder = ChangeSetBuilder(
  // ... existing params ...
  existingChecklistTitlesResolver: () async {
    final task = await journalDb.journalEntityById(taskId);
    if (task is! Task) return {};
    final items = await checklistRepository.getChecklistItemsForTask(task);
    return items
        .map((item) => item.data.title.toLowerCase().trim())
        .toSet();
  },
);
```

**Caching note:** The resolver result should be cached for the duration of a single
`addBatchItem()` call to avoid repeated DB queries for each item in a batch.

### Step 2: Implement `_checkAddRedundancy()` in `ChangeSetBuilder`

**File:** `change_set_builder.dart`

Add a new static method alongside `_checkRedundancy()`:

```dart
/// Check whether an `add_checklist_item` proposal is redundant because
/// an item with the same title already exists on the task.
///
/// Returns a human-readable detail string if redundant, or `null` if
/// the item should be kept.
static String? _checkAddRedundancy(
  String singularToolName,
  Map<String, dynamic> args,
  Set<String> existingTitles,
) {
  if (singularToolName != TaskAgentToolNames.addChecklistItem) {
    return null;
  }
  final title = args['title'];
  if (title is! String || title.isEmpty) return null;
  if (existingTitles.contains(title.toLowerCase().trim())) {
    return '"$title" already exists in the checklist';
  }
  return null;
}
```

Call this from `addBatchItem()` right before the existing `_checkRedundancy()` call,
and from `addItem()` when the tool name is `add_checklist_item`.

### Step 3: Add rejection-history dedup to `build()`

**Files:** `change_set_builder.dart`, `task_agent_workflow.dart`

Extend `build()` to accept recent rejected decisions:

```dart
Future<ChangeSetEntity?> build(
  AgentSyncService syncService, {
  List<ChangeSetEntity> existingPendingSets = const [],
  Set<String> rejectedFingerprints = const {},  // NEW
}) async {
```

In `_deduplicateItems()`, merge rejection fingerprints into the existing-hashes set:

```dart
static List<ChangeItem> _deduplicateItems(
  List<ChangeItem> proposed,
  List<ChangeItem> existing, {
  Set<String> rejectedFingerprints = const {},  // NEW
}) {
  if (existing.isEmpty && rejectedFingerprints.isEmpty) return proposed;
  final existingHashes = {
    ...existing.map(ChangeItem.fingerprint),
    ...rejectedFingerprints,
  };
  return proposed
      .where((item) => !existingHashes.contains(ChangeItem.fingerprint(item)))
      .toList();
}
```

In `task_agent_workflow.dart`, query recent rejections before building:

```dart
final recentRejections = await agentRepository.getRecentDecisions(
  agentId,
  taskId: taskId,
);
final rejectedOnly = recentRejections
    .where((d) => d.verdict == ChangeDecisionVerdict.rejected)
    .toList();

// Reconstruct fingerprints from rejected decisions
final rejectedFingerprints = rejectedOnly
    .where((d) => d.args != null)
    .map((d) => ChangeItem.fingerprintFromParts(d.toolName, d.args!))
    .toSet();

await changeSetBuilder.build(
  syncService,
  existingPendingSets: pendingSets,
  rejectedFingerprints: rejectedFingerprints,  // NEW
);
```

**Note:** `ChangeDecisionEntity` currently stores `toolName` and `humanSummary` but
may not store `args`. If `args` are not persisted on the decision entity, we need to
either:
- (a) Add `args` to `ChangeDecisionEntity` (preferred — enables fingerprint matching), or
- (b) Use title-based fuzzy matching on the `humanSummary` field (fragile fallback)

**Check needed:** Read `ChangeDecisionEntity` fields to confirm whether `args` is stored.
If not, Step 3a below covers adding it.

### Step 3a (if needed): Persist tool args on `ChangeDecisionEntity`

**Files:** `agent_domain_entity.dart`, `change_set_confirmation_service.dart`

Add an `args` field to `ChangeDecisionEntity`:

```dart
/// The tool arguments, preserved for fingerprint-based dedup of future
/// proposals.
Map<String, dynamic>? args,
```

In `ChangeSetConfirmationService.rejectItem()` and `confirmItem()`, populate:

```dart
AgentDomainEntity.changeDecision(
  // ... existing fields ...
  args: item.args,  // NEW
)
```

Run `make build_runner` to regenerate freezed/json files.

### Step 4: Add title tracking to prevent re-proposal within the same wake

**File:** `change_set_builder.dart`

The `existingChecklistTitlesResolver` cache should also include titles from items
already added during the current wake (in `_items`). This prevents the LLM from
proposing the same item twice in one batch:

```dart
// In addBatchItem(), after resolving existing titles:
final addedTitles = _items
    .where((i) => i.toolName == TaskAgentToolNames.addChecklistItem)
    .map((i) => (i.args['title'] as String?)?.toLowerCase().trim())
    .whereType<String>()
    .toSet();
final allExistingTitles = {...existingTitles, ...addedTitles};
```

### Step 5: Write tests

**Files:** New test file `test/features/agents/workflow/change_set_builder_test.dart`
(or extend existing tests)

Test cases:

1. **`add_checklist_item` suppressed when title exists on task** — provide a
   resolver that returns `{"buy groceries"}`, propose adding "Buy Groceries",
   verify it's suppressed with case-insensitive matching.

2. **`add_checklist_item` allowed when title is novel** — same resolver, propose
   "New unique item", verify it passes through.

3. **Rejected fingerprint blocks re-proposal** — build with a rejected fingerprint
   set containing the proposed item's fingerprint, verify it's dropped.

4. **Same-wake dedup** — call `addBatchItem` with two items having the same title,
   verify only one is added.

5. **Update redundancy still works** — existing `_checkRedundancy` tests remain
   green.

6. **Integration: full pipeline** — create a ChangeSetBuilder with all resolvers,
   add items that overlap with existing checklist + rejected history, verify the
   built ChangeSetEntity contains only genuinely new items.

### Step 6: Verify and clean up

1. Run `dart-mcp.analyze_files` — ensure zero warnings.
2. Run `dart-mcp.dart_format` — normalize formatting.
3. Run targeted tests for the changed files.
4. Run the full agent workflow test suite.

## File Change Summary

| File | Change |
|------|--------|
| `lib/features/agents/workflow/change_set_builder.dart` | Add `ExistingChecklistTitlesResolver`, `_checkAddRedundancy()`, extend `build()` for rejection history, same-wake title tracking |
| `lib/features/agents/workflow/task_agent_workflow.dart` | Wire up the new resolver, query recent rejections, pass to `build()` |
| `lib/features/agents/workflow/change_proposal_filter.dart` | No changes needed (metadata redundancy is separate) |
| `lib/features/agents/model/agent_domain_entity.dart` | Add `args` field to `ChangeDecisionEntity` (if not present) |
| `lib/features/agents/service/change_set_confirmation_service.dart` | Persist `args` on decision creation |
| `test/features/agents/workflow/change_set_builder_test.dart` | New/extended tests for all dedup layers |

## Risk Assessment

- **Low risk:** All changes are additive guards — they only suppress proposals,
  never alter confirmation/execution logic.
- **Backwards compatible:** Existing `ChangeDecisionEntity` records without `args`
  simply won't match fingerprints (conservative — keeps items rather than falsely
  suppressing).
- **Performance:** One additional DB query per wake (`getChecklistItemsForTask` +
  `getRecentDecisions`). Both are indexed and bounded. Negligible impact.
- **Edge case:** If the user manually renames a checklist item after the agent
  proposed adding it, the title-based check uses the current title, so a stale
  proposal for the old title would correctly not match. The fingerprint-based
  rejection history handles the inverse case.

## Success Criteria

1. An `add_checklist_item` proposal for a title that already exists on the task is
   silently suppressed (never reaches the UI).
2. A rejected `add_checklist_item` is not re-proposed in subsequent agent wakes
   (within the recent-decisions window).
3. Existing update-redundancy and cross-wake dedup continue to work unchanged.
4. All new and existing tests pass with zero analyzer warnings.
