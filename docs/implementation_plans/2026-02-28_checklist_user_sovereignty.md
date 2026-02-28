# Checklist User Sovereignty: Prevent Agent from Reverting User-Checked Items

**Date:** 2026-02-28
**Status:** Implemented
**Priority:** P1
**Estimated effort:** ~2 hours

## Problem

The task agent reverses user-manual checklist completions when it cannot find
supporting evidence in the logs. If a user checks an item "done" at 10 PM,
and the agent wakes at 10:05 PM seeing no textual evidence, it unchecks the
item. This undermines trust and takes away user agency.

## Root Cause

`ChecklistItemData` has no provenance metadata — there is no way to
distinguish a user toggle from an agent toggle. The agent's
`update_checklist_items` tool and the `LottiChecklistUpdateHandler` treat
every `isChecked` value identically, regardless of who set it.

## Design Principles

1. **User actions carry weight.** A user-set state should not be overridden
   by the agent unless there is explicit evidence **from after** the user's
   action that justifies the change (e.g., a recording where the user says
   "actually, that's not done yet").
2. **Absence of evidence is not evidence of absence.** If the agent cannot
   find logs supporting a user-checked item, the item stays checked. The
   user may have completed the task outside of the app.
3. **Post-dated evidence unlocks override.** If the user checks an item at
   10 PM and then records at 10:30 PM "I realized X isn't actually done",
   the agent MAY uncheck it — the evidence postdates the user's action.
4. **Backward compatible.** Existing items (with no metadata) default to
   `user` provenance and are treated as user-set for safety.
5. **Minimal surface.** Only the `ChecklistItemData` model, the two write
   paths, the agent prompt, and the tool guard need to change.

---

## Architecture & Flow Diagrams

### System Architecture — Components Involved

```mermaid
graph TB
    subgraph UI["UI Layer"]
        CIW[ChecklistItemWidget]
        CIC[ChecklistItemController]
    end

    subgraph Agent["Agent Layer"]
        TAW[TaskAgentWorkflow<br/><i>system prompt + sovereignty rules</i>]
        TAS[TaskAgentStrategy]
        TTD[TaskToolDispatcher]
        LCUH[LottiChecklistUpdateHandler<br/><i>soft guard: requires reason<br/>for user-set overrides</i>]
    end

    subgraph Data["Data Layer"]
        CID[ChecklistItemData<br/><b>+ checkedBy</b><br/><b>+ checkedAt</b>]
        CR[ChecklistRepository]
        PL[PersistenceLogic]
        JDB[(journal.sqlite)]
    end

    CIW -->|"toggle checkbox"| CIC
    CIC -->|"stamps checkedBy: user<br/>checkedAt: now"| CR

    TAW -->|"LLM tool call"| TAS
    TAS -->|"route deferred tool"| TTD
    TTD -->|"update_checklist_items"| LCUH
    LCUH -->|"sovereignty guard:<br/>user-set? reason required"| LCUH
    LCUH -->|"stamps checkedBy: agent<br/>(if allowed)"| CR

    CR --> PL --> JDB
    JDB -.->|"deserialize"| CID

    style CID fill:#f9f,stroke:#333,stroke-width:2px
    style LCUH fill:#ff9,stroke:#333,stroke-width:2px
    style TAW fill:#9cf,stroke:#333,stroke-width:2px
```

### Evidence-Based Override Model

```mermaid
timeline
    title When can the agent override a user-checked item?
    section 10:00 PM : User checks item "Done"
        : checkedBy = user
        : checkedAt = 22:00
    section 10:05 PM : Agent wakes, sees no evidence
        : ❌ CANNOT uncheck
        : Absence of evidence ≠ evidence of absence
    section 10:30 PM : User records "X isn't done yet"
        : New evidence timestamped AFTER 22:00
    section 10:35 PM : Agent wakes, sees post-dated evidence
        : ✅ CAN uncheck (with reason citing the recording)
```

### Checklist Item State Machine — `isChecked` with Provenance

```mermaid
stateDiagram-v2
    [*] --> Unchecked_User: Item created<br/>(default: checkedBy=user)

    state "isChecked=false\ncheckedBy=user" as Unchecked_User
    state "isChecked=true\ncheckedBy=user" as Checked_User
    state "isChecked=true\ncheckedBy=agent" as Checked_Agent
    state "isChecked=false\ncheckedBy=agent" as Unchecked_Agent

    %% User transitions — always allowed
    Unchecked_User --> Checked_User: User checks
    Checked_User --> Unchecked_User: User unchecks
    Checked_Agent --> Checked_User: User re-checks
    Checked_Agent --> Unchecked_User: User unchecks
    Unchecked_Agent --> Checked_User: User checks
    Unchecked_Agent --> Unchecked_User: User unchecks

    %% Agent transitions on agent-owned items — always allowed
    Checked_Agent --> Unchecked_Agent: Agent unchecks (own item)
    Unchecked_Agent --> Checked_Agent: Agent checks (own item)

    %% Agent transitions on user-owned items — conditional
    Checked_User --> Unchecked_Agent: Agent unchecks\n⚠️ ONLY with post-dated\nevidence + reason
    Unchecked_User --> Checked_Agent: Agent checks\n⚠️ ONLY with post-dated\nevidence + reason

    note right of Checked_User
        PROTECTED STATE
        Agent needs reason + evidence
        dated AFTER checkedAt to override
    end note

    note right of Unchecked_User
        PROTECTED STATE (default)
        Legacy items land here too
    end note

    note left of Checked_Agent
        AGENT-OWNED
        Agent can freely modify
        No reason required
    end note
```

### Agent Update Flow — Decision Logic

```mermaid
flowchart TD
    A["Agent calls<br/>update_checklist_items"] --> B["LottiChecklistUpdateHandler<br/>.processFunctionCall()"]
    B --> C{Valid JSON<br/>& schema?}
    C -->|No| ERR[Return error result]
    C -->|Yes| D["executeUpdates()"]

    D --> E["Fetch entity from DB"]
    E --> F{Entity exists &<br/>is ChecklistItem?}
    F -->|No| SKIP1["Skip: not found"]
    F -->|Yes| G{Belongs to<br/>task's checklists?}
    G -->|No| SKIP2["Skip: wrong task"]
    G -->|Yes| H{isChecked<br/>change requested?}

    H -->|No| TITLE["Apply title-only update<br/>(always allowed)"]
    H -->|Yes| I{{"checkedBy == user?"}}

    I -->|No, agent-owned| L["Apply full update<br/>Stamp checkedBy: agent<br/>Stamp checkedAt: now"]

    I -->|Yes, user-set| J{Agent provided<br/>reason field?}

    J -->|No reason| SKIP3["Skip isChecked change<br/>'User set this item at T —<br/>provide reason with post-dated<br/>evidence to override'"]
    J -->|Has reason| K["Allow override<br/>Stamp checkedBy: agent<br/>Stamp checkedAt: now<br/>Log reason for audit"]

    SKIP3 --> TITLE_CHECK{Title change<br/>also requested?}
    TITLE_CHECK -->|Yes| TITLE_ONLY["Apply title only"]
    TITLE_CHECK -->|No| SKIP_FULL["Skip entirely"]

    TITLE --> N[success++]
    TITLE_ONLY --> N
    K --> N
    L --> N

    SKIP1 --> O[skippedItems++]
    SKIP2 --> O
    SKIP_FULL --> O

    style I fill:#f90,stroke:#333,stroke-width:3px,color:#fff
    style J fill:#f90,stroke:#333,stroke-width:2px,color:#fff
    style K fill:#ff9,stroke:#333
    style L fill:#9f9,stroke:#333
    style SKIP3 fill:#f99,stroke:#333
    style SKIP_FULL fill:#f99,stroke:#333
```

### Write Path Comparison — User vs Agent

```mermaid
sequenceDiagram
    participant U as User (UI)
    participant CIC as ChecklistItemController
    participant CR as ChecklistRepository
    participant DB as journal.sqlite

    Note over U,DB: User Write Path (always succeeds)
    U->>CIC: toggleCheckbox(checked: true)
    CIC->>CIC: data.copyWith(<br/>isChecked: true,<br/>checkedBy: user,<br/>checkedAt: now)
    CIC->>CR: updateChecklistItem(data)
    CR->>DB: persist

    participant LLM as LLM (Agent)
    participant LCUH as UpdateHandler

    Note over LLM,DB: Agent Path — no post-dated evidence (BLOCKED)
    LLM->>LCUH: update_checklist_items([{id, isChecked: false}])
    LCUH->>DB: fetch entity
    DB-->>LCUH: entity (checkedBy: user, checkedAt: 22:00)
    LCUH->>LCUH: No reason provided
    LCUH-->>LLM: "Skipped: user set at 22:00, provide reason"

    Note over LLM,DB: Agent Path — with post-dated evidence (ALLOWED)
    LLM->>LCUH: update_checklist_items([{id, isChecked: false,<br/>reason: "User said 'not done' at 22:30"}])
    LCUH->>DB: fetch entity
    DB-->>LCUH: entity (checkedBy: user, checkedAt: 22:00)
    LCUH->>LCUH: Reason present → allow override
    LCUH->>CR: updateChecklistItem(isChecked: false,<br/>checkedBy: agent, checkedAt: now)
    CR->>DB: persist
    LCUH-->>LLM: "Updated: unchecked (override reason logged)"
```

### Data Model Change — Before & After

```mermaid
classDiagram
    class ChecklistItemData_Before {
        +String title
        +bool isChecked
        +List~String~ linkedChecklists
        +bool isArchived
        +String? id
    }

    class ChecklistItemData_After {
        +String title
        +bool isChecked
        +List~String~ linkedChecklists
        +bool isArchived
        +String? id
        +CheckedBySource checkedBy
        +DateTime? checkedAt
    }

    class CheckedBySource {
        <<enumeration>>
        user
        agent
    }

    ChecklistItemData_After --> CheckedBySource

    note for ChecklistItemData_After "checkedBy defaults to 'user'\nfor backward compatibility\n(legacy items are protected)"
```

### Legacy Deserialization — Backward Compatibility

```mermaid
flowchart LR
    subgraph Legacy["Legacy JSON (no new fields)"]
        LJ["{ title, isChecked,<br/>linkedChecklists, ... }"]
    end

    subgraph New["New JSON (with fields)"]
        NJ["{ ..., checkedBy: 'agent',<br/>checkedAt: '2026-...' }"]
    end

    LJ -->|"fromJson()"| D1["ChecklistItemData<br/>checkedBy = user (default)<br/>checkedAt = null"]
    NJ -->|"fromJson()"| D2["ChecklistItemData<br/>checkedBy = agent<br/>checkedAt = 2026-..."]

    D1 -->|"Agent tries override<br/>without reason"| BLOCKED["BLOCKED<br/>(needs reason)"]
    D1 -->|"Agent provides reason<br/>citing evidence"| ALLOWED2["ALLOWED<br/>(reason logged)"]
    D2 -->|"Agent updates freely"| ALLOWED["ALLOWED<br/>(agent-owned)"]

    style BLOCKED fill:#f66,color:#fff
    style ALLOWED fill:#6f6
    style ALLOWED2 fill:#cf9
```

### Enforcement Layers — Defense in Depth

```mermaid
flowchart TB
    subgraph L1["Layer 1: Prompt Instructions"]
        P1["Agent system prompt:<br/>'Only override user-set items<br/>with post-dated evidence'"]
        P2["Tool description:<br/>'reason required for<br/>user-set overrides'"]
    end

    subgraph L2["Layer 2: Tool Schema"]
        S1["update_checklist_items schema:<br/>optional 'reason' field per item"]
    end

    subgraph L3["Layer 3: Handler Guard"]
        G1["LottiChecklistUpdateHandler:<br/>if checkedBy==user && no reason<br/>→ skip with message"]
    end

    subgraph L4["Layer 4: Audit Trail"]
        A1["Override reason logged<br/>in tool response + dev log"]
    end

    L1 --> L2 --> L3 --> L4

    style L1 fill:#9cf,stroke:#333
    style L2 fill:#9cf,stroke:#333
    style L3 fill:#ff9,stroke:#333
    style L4 fill:#cfc,stroke:#333
```

---

## Implementation Plan

### Phase 1 — Data Model (`ChecklistItemData`)

**File:** `lib/classes/checklist_item_data.dart`

Add two optional fields with safe defaults:

```dart
@freezed
abstract class ChecklistItemData with _$ChecklistItemData {
  const factory ChecklistItemData({
    required String title,
    required bool isChecked,
    required List<String> linkedChecklists,
    @Default(false) bool isArchived,
    String? id,
    // --- new fields ---
    @Default(CheckedBySource.user) CheckedBySource checkedBy,
    DateTime? checkedAt,
  }) = _ChecklistItemData;

  factory ChecklistItemData.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemDataFromJson(json);
}

/// Who last changed the `isChecked` field.
enum CheckedBySource {
  /// Set by the user via the UI.
  user,
  /// Set by an AI agent tool call.
  agent,
}
```

**Why `@Default(CheckedBySource.user)`?** Legacy items have no metadata.
Defaulting to `user` is the safe choice — it means the agent needs to
provide a reason to override, which is the correct conservative behavior.

**Why `checkedAt` instead of a generic `lastUpdatedAt`?** The `meta.updatedAt`
already tracks the last write time for the whole entity. We specifically need
to know when the *checked state* last changed and by whom, so we scope the
timestamp narrowly. The agent uses `checkedAt` to determine whether its
evidence postdates the user's action.

**Migration:** No schema migration needed. `ChecklistItemData` is serialized
as JSON inside the journal `serialized` column. Freezed + `json_serializable`
handle missing keys via the `@Default` annotation — old records deserialize
cleanly.

**After editing:** Run `make build_runner` to regenerate `.freezed.dart` and
`.g.dart` files.

---

### Phase 2 — User Write Path

When the user toggles a checkbox in the UI, stamp `checkedBy: user` and
`checkedAt`.

**File:** `lib/features/tasks/state/checklist_item_controller.dart`

In `updateChecked()`:

```dart
void updateChecked({required bool checked}) {
  final current = state.value;
  final data = current?.data;
  if (current != null && data != null) {
    final updated = current.copyWith(
      data: data.copyWith(
        isChecked: checked,
        checkedBy: CheckedBySource.user,   // <-- new
        checkedAt: DateTime.now(),          // <-- new
      ),
    );
    ref.read(checklistRepositoryProvider).updateChecklistItem(
          checklistItemId: id,
          data: updated.data,
          taskId: taskId,
        );
    state = AsyncData(updated);
  }
}
```

Similarly, any other UI path that creates items (e.g.,
`ChecklistRepository.createChecklistItem`, `addItemToChecklist`) should
default to `CheckedBySource.user` (which the `@Default` already provides).

---

### Phase 3 — Tool Schema Update (add `reason` field)

**File:** `lib/features/ai/functions/checklist_completion_functions.dart`

Add an optional `reason` field to each item in the `update_checklist_items`
tool schema:

```dart
'reason': {
  'type': 'string',
  'description':
      'Required when changing isChecked on a user-set item. '
      'Must cite specific evidence (e.g., a recording or note) '
      'that postdates the user\'s last toggle. The system will '
      'reject isChecked changes on user-set items without a reason.',
},
```

Update the tool `description` to mention the policy:

```
'Update one or more existing checklist items. You can mark items as '
'done/undone or correct titles. When an item was last toggled by the '
'user, you must provide a reason citing evidence from AFTER the '
'user\'s action to change its checked state. Title updates are '
'always allowed.'
```

Update the `isChecked` field description:

```
'New checked status. For items last set by the user, you must also '
'provide a reason citing post-dated evidence. Without a reason, the '
'isChecked change will be rejected for user-set items.'
```

---

### Phase 4 — Agent Write Path (Soft Guard Logic)

**File:** `lib/features/ai/functions/lotti_checklist_update_handler.dart`

**Validation change in `processFunctionCall()`:** Accept the new optional
`reason` field per item:

```dart
validatedItems.add({
  'id': id.trim(),
  if (isChecked != null) 'isChecked': isChecked,
  if (normalizedTitle != null) 'title': normalizedTitle,
  if (reason != null) 'reason': reason,   // <-- new
});
```

**Guard logic in `executeUpdates()`:** After fetching the entity, before
applying `isChecked` changes:

```dart
// --- User sovereignty soft guard ---
if (newIsChecked != null && newIsChecked != currentIsChecked) {
  final isUserSet = entity.data.checkedBy == CheckedBySource.user;
  final reason = item['reason'] as String?;

  if (isUserSet && (reason == null || reason.trim().isEmpty)) {
    // Agent has no justification for overriding a user action.
    final checkedAtStr = entity.data.checkedAt?.toIso8601String() ?? 'unknown';
    _skip(
      id,
      'User set this item at $checkedAtStr. Provide a reason '
      'citing evidence from after that time to override.',
    );

    // Still allow a title update if requested
    if (titleChanged) {
      final titleOnlyData = entity.data.copyWith(title: newTitle!);
      await checklistRepository.updateChecklistItem(
        checklistItemId: id,
        data: titleOnlyData,
        taskId: task.id,
      );
      _updatedItems.add(UpdatedItemDetail(
        id: id,
        title: newTitle,
        isChecked: currentIsChecked,
        changes: ['title'],
      ));
      successCount++;
    }
    continue;
  }

  // Log override reason for audit
  if (isUserSet && reason != null) {
    developer.log(
      'Overriding user-set item $id. Reason: $reason',
      name: 'LottiChecklistUpdateHandler',
    );
  }
}
```

When the agent *is* allowed to update `isChecked` (agent-owned, or user-set
with valid reason), stamp the provenance:

```dart
final updatedData = entity.data.copyWith(
  isChecked: newIsChecked ?? currentIsChecked,
  title: newTitle ?? currentTitle,
  checkedBy: (newIsChecked != null)
      ? CheckedBySource.agent
      : entity.data.checkedBy,
  checkedAt: (newIsChecked != null)
      ? DateTime.now()
      : entity.data.checkedAt,
);
```

---

### Phase 5 — Agent Prompt Update

**File:** `lib/features/agents/workflow/task_agent_workflow.dart`

Add a new section to `taskAgentScaffold` under "Tool Usage Guidelines":

```
- **Checklist sovereignty**: Checklist items track who last toggled them
  (user or agent) and when (`checkedAt`). Rules:
  - If YOU (the agent) last set the item, you can freely change it.
  - If the USER last set the item, you must NOT change its checked state
    UNLESS you have clear evidence from journal entries, recordings, or
    notes that are timestamped AFTER the user's `checkedAt` time.
  - Absence of evidence is NOT grounds for unchecking. The user may have
    completed the task outside the app.
  - When overriding a user-set item, you MUST provide a `reason` field in
    the tool call explaining what post-dated evidence justifies the change.
    Without a reason, the system will reject the isChecked change.
  - Title updates (fixing typos, transcription errors) are always allowed
    regardless of who last toggled the item.
```

---

### Phase 6 — Expose Provenance in Agent Context

**File:** `lib/features/agents/workflow/task_agent_workflow.dart` (or
wherever checklist items are serialized into the agent's context)

When building the task context that the agent sees, include `checkedBy` and
`checkedAt` for each checklist item so the agent can make informed decisions:

```json
{
  "id": "abc-123",
  "title": "Write integration tests",
  "isChecked": true,
  "checkedBy": "user",
  "checkedAt": "2026-02-28T22:00:00Z"
}
```

This is critical — without visibility into provenance, the agent cannot
follow the prompt rules.

---

### Phase 7 — Agent Tool Registry Description

**File:** `lib/features/agents/tools/agent_tool_registry.dart`

If the `update_checklist_items` tool has its own description in the registry
(separate from `checklist_completion_functions.dart`), update it consistently
with the same sovereignty language. Also add the `reason` field to the
registry's schema if it defines one independently.

---

### Phase 8 — Tests

#### 8a. Unit test: `LottiChecklistUpdateHandler` sovereignty guard

**File:** `test/features/ai/functions/lotti_checklist_update_handler_test.dart`

Test cases:
1. **Agent blocked: user-set, no reason** — item has `checkedBy: user`,
   agent tries to uncheck without reason → skipped with descriptive message.
2. **Agent allowed: user-set, with reason** — item has `checkedBy: user`,
   agent provides reason → override succeeds, `checkedBy` flips to `agent`.
3. **Agent freely updates agent-set item** — item has `checkedBy: agent`,
   agent toggles without reason → success.
4. **Title-only passthrough on blocked override** — item has
   `checkedBy: user`, agent sends title + isChecked without reason →
   title updated, isChecked skipped.
5. **Legacy item (default)** — item has `checkedBy: user` (default
   from missing JSON field) → treated as user-set, requires reason.
6. **Empty reason treated as missing** — reason: `"  "` → still blocked.

#### 8b. Unit test: `ChecklistItemController.updateChecked` stamps provenance

**File:** `test/features/tasks/state/checklist_item_controller_test.dart`

Test that calling `updateChecked(checked: true)` produces data with
`checkedBy == CheckedBySource.user` and a non-null `checkedAt`.

#### 8c. Serialization round-trip

Verify that `ChecklistItemData.fromJson` / `.toJson` correctly handles:
- New fields present → deserialized correctly.
- New fields missing (legacy JSON) → defaults applied (`user`, `null`).

---

## Files Changed (Summary)

| File | Change |
|------|--------|
| `lib/classes/checklist_item_data.dart` | Add `checkedBy`, `checkedAt` fields + `CheckedBySource` enum |
| `lib/features/tasks/state/checklist_item_controller.dart` | Stamp `checkedBy: user` on toggle |
| `lib/features/ai/functions/checklist_completion_functions.dart` | Add `reason` to schema, update descriptions |
| `lib/features/ai/functions/lotti_checklist_update_handler.dart` | Soft sovereignty guard + stamp `checkedBy: agent` |
| `lib/features/agents/workflow/task_agent_workflow.dart` | Prompt addition + provenance in context |
| `lib/features/agents/tools/agent_tool_registry.dart` | Tool description + schema update |
| Tests (3 files) | New/updated test cases |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Agent fabricates reasons to bypass the guard | The reason is logged for audit. The prompt instructs it to cite specific timestamped evidence. If this becomes a pattern, we can add a harder block in a follow-up. |
| Legacy items default to `user` → agent always needs reason for old items | Correct conservative behavior. Once the agent or user toggles an old item, provenance is stamped going forward. |
| Agent doesn't see `checkedAt` in context | Phase 6 ensures provenance is included in the task context JSON. |
| `DateTime.now()` in production code | Acceptable — this is a real timestamp, not a test. Tests will use deterministic dates per project policy. |
| JSON size increase | Negligible — two small fields + occasional reason string per item. |

---

## Out of Scope

- UI indicator showing who last toggled an item (could be a follow-up).
- Audit log / history of checklist state changes.
- Hard-blocking the agent entirely (we chose the softer evidence-based approach).
- Changes to the `suggest_checklist_completion` flow (it only suggests,
  doesn't directly modify state).

---

## Post-Implementation Hardening (2026-02-28)

After the initial implementation, the following hardening measures were added:

### 1. Minimum reason length enforcement
The sovereignty guard now requires reasons to be at least 20 characters
(`minReasonLength`). This prevents trivial/hallucinated justifications like
"ok" or "done" from bypassing the guard. The agent must provide a
substantive reason citing specific evidence.

### 2. Safe enum deserialization
`CheckedBySource` now uses `@JsonKey(unknownEnumValue: CheckedBySource.user)`
so that unknown persisted values (from future versions or data corruption)
safely default to `user` instead of throwing an `ArgumentError` during
deserialization. This is the correct conservative fallback — unknown
provenance is treated as user-owned.

### 3. Injectable clocks
Both `UnifiedAiInferenceRepository` and `ChecklistItemController` now use
injectable clock functions instead of `DateTime.now()`, enabling deterministic
timestamp assertions in tests.

### 4. Auto-check sovereignty guard
The auto-check path in `UnifiedAiInferenceRepository` now respects the
sovereignty guard: items with `checkedBy: user` are never auto-checked,
since auto-check has no reason to provide.
