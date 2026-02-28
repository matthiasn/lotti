# ADR 0006: Change Set — Deferred Tool Confirmation Workflow

- Status: Accepted
- Date: 2026-02-27 (updated 2026-02-28)

## Context

The task agent can autonomously mutate journal entities (titles, estimates, due
dates, priorities, statuses, checklist items, labels) via tool calls. Some of
these mutations are high-impact or subjective — e.g., changing a task's status to
BLOCKED or adding checklist items based on inferred requirements. Users need
visibility and control over what the agent proposes before mutations are applied.

Without a confirmation step, the only recourse is to undo changes after the fact,
which erodes trust and makes the agent feel unpredictable.

## Decision

1. **Classify tools as deferred or immediate.** A static set
   (`AgentToolRegistry.deferredTools`) lists tools whose mutations require user
   confirmation. Locally-handled tools (`update_report`, `record_observations`)
   and non-deferred tools (e.g., `set_task_language`) execute immediately.

2. **Accumulate proposals in a `ChangeSetBuilder`.** When the strategy encounters
   a deferred tool and a `ChangeSetBuilder` is provided, the tool call is added
   to the builder instead of being executed. The LLM receives a
   `"Proposal queued for user review."` response and can continue its
   conversation normally.

3. **Explode batch tools into individual items.** Batch tools (e.g.,
   `add_multiple_checklist_items` with 5 items) are split into individual
   `ChangeItem` entries so each element can be independently confirmed or
   rejected. The registry maps batch tool names to their array key
   (`AgentToolRegistry.explodedBatchTools`).

4. **Persist the change set as an `AgentDomainEntity`.** At the end of the wake,
   the builder produces a `ChangeSetEntity` with status `pending`. Each item
   carries a `toolName`, `args` map, `humanSummary`, and per-item
   `ChangeItemStatus`.

5. **Record user decisions as `ChangeDecisionEntity`.** Each confirm/reject
   action creates a decision entity with `itemIndex`, `verdict`, and optional
   `rejectionReason`, enabling the agent to learn from user preferences over
   time.

6. **Generate human-readable summaries.** Each change item gets a tool-specific
   summary (e.g., `Set title to "Fix login bug"`, `Add: "Design mockup"`,
   `Set estimate to 60 minutes`) for display in the confirmation UI.

7. **Sync change sets across devices.** All writes go through `AgentSyncService`,
   which means change sets, item status updates, and decision entities are
   automatically enqueued for cross-device sync. A proposal made on one device
   can be reviewed and confirmed on another.

## Change Set Lifecycle

```mermaid
stateDiagram-v2
  [*] --> pending: builder.build()
  pending --> partiallyResolved: some items decided
  pending --> resolved: all items decided
  partiallyResolved --> resolved: remaining items decided
  resolved --> [*]
  pending --> expired: TTL exceeded
  expired --> [*]
```

## End-to-End Flow

```mermaid
sequenceDiagram
  participant Agent as TaskAgentWorkflow
  participant Strategy as TaskAgentStrategy
  participant Builder as ChangeSetBuilder
  participant Sync as AgentSyncService
  participant DB as agent.sqlite
  participant UI as ChangeSetSummaryCard
  participant Service as ConfirmationService
  participant Dispatcher as TaskToolDispatcher
  participant Journal as Journal Repository

  Note over Agent,Strategy: Wake cycle
  Agent->>Strategy: processToolCalls([set_task_title, ...])
  Strategy->>Strategy: Tool in deferredTools?
  Strategy->>Builder: addItem(toolName, args, summary)
  Strategy-->>Agent: "Proposal queued for user review."

  Note over Agent,DB: End of wake
  Agent->>Builder: build(syncService)
  Builder->>Sync: upsertEntity(ChangeSetEntity)
  Sync->>DB: persist + enqueue for sync

  Note over UI,Journal: User reviews on any device
  UI->>DB: pendingChangeSetsProvider(taskId)
  DB-->>UI: List<ChangeSetEntity>
  UI-->>UI: Render per-item confirm/reject

  alt User taps Confirm
    UI->>Service: confirmItem(changeSet, index)
    Service->>DB: re-read fresh ChangeSetEntity
    Service->>Dispatcher: dispatch(toolName, args, taskId)
    Dispatcher->>Journal: execute handler (title/estimate/etc.)
    Journal-->>Dispatcher: ToolExecutionResult
    Dispatcher-->>Service: success
    Service->>Sync: persist ChangeDecisionEntity
    Service->>Sync: update item status → confirmed
    Service-->>UI: result
  else User taps Reject
    UI->>Service: rejectItem(changeSet, index)
    Service->>Sync: persist ChangeDecisionEntity (rejected)
    Service->>Sync: update item status → rejected
    Service-->>UI: applied
  end
```

## Tool Call Routing

```mermaid
flowchart TD
  A["Tool call received"] --> B{"update_report or\nrecord_observations?"}
  B -->|Yes| C["Handle locally"]
  B -->|No| D{"changeSetBuilder\npresent?"}
  D -->|No| E["Execute via AgentToolExecutor"]
  D -->|Yes| F{"Tool in\ndeferredTools?"}
  F -->|No| E
  F -->|Yes| G{"Tool in\nexplodedBatchTools?"}
  G -->|Yes| H["Explode into individual items"]
  G -->|No| I["Add single item"]
  H --> J["Add to ChangeSetBuilder"]
  I --> J
  J --> K["Respond: 'Proposal queued'"]
```

## Confirmation UI Architecture

```mermaid
flowchart TD
  subgraph TaskForm
    A[TaskAgentReportSection] --> B[ChangeSetSummaryCard]
    B --> C[LinkedTasksWidget]
  end

  subgraph ChangeSetSummaryCard
    D[pendingChangeSetsProvider] --> E[_ChangeSetCard]
    E --> F["_ChangeItemTile × N"]
    F -->|"Swipe right / tap ✓"| G[confirmItem]
    F -->|"Swipe left / tap ✗"| H[rejectItem]
    E -->|Confirm All button| I[confirmAll]
  end

  subgraph ChangeSetConfirmationService
    G --> J[TaskToolDispatcher.dispatch]
    J --> K[persist ChangeDecisionEntity]
    K --> L[update ChangeSetEntity status]
    H --> M[persist ChangeDecisionEntity]
    M --> L
    I --> G
  end

  L --> N[updateNotifications.notify]
  N --> D
```

## Confirmation Service Design

`ChangeSetConfirmationService` mediates between the UI and the tool dispatcher:

- **Re-reads before acting.** Every `confirmItem`/`rejectItem` call re-reads the
  `ChangeSetEntity` from the repository to guard against stale snapshots from
  rapid taps or concurrent clients on other devices.
- **Atomic per-item.** Each item is confirmed or rejected independently. A failed
  tool dispatch does not persist a decision — the item stays `pending` for retry.
- **`confirmAll` iterates sequentially.** Re-reads the change set after each item
  to see committed state from the previous handler. This guarantees ordering
  (e.g., title change is visible to the next tool).

### UI Safety

Async confirmation methods capture `ref`-dependent values (service, notifier)
*before* the `await` to prevent accessing `ref` after the widget is unmounted
during provider rebuilds.

## Consequences

- Users see proposed changes before they are applied, building trust.
- Granular per-item confirmation allows partial acceptance of batch proposals.
- Decision history enables agent learning from user preferences.
- The `ChangeSetBuilder` is optional — callers without it get the previous
  immediate-execution behavior, maintaining backward compatibility.
- Batch tool explosion means the singular tool handler (e.g.,
  `add_checklist_item`) must exist alongside the batch variant for re-execution
  of confirmed items.
- Change sets sync across devices — proposals can be created on one device and
  confirmed on another.
- Validation (type checks, rate limits) happens at confirmation time, not at
  proposal time. Invalid args are still deferred; errors surface when the user
  confirms.

## Related

- Implementation plan: `docs/implementation_plans/2026-02-27_change_set_confirmation_ui.md`
- `lib/features/agents/tools/agent_tool_registry.dart` — deferred/batch tool sets
- `lib/features/agents/workflow/change_set_builder.dart` — builder implementation
- `lib/features/agents/workflow/task_agent_strategy.dart` — routing logic
- `lib/features/agents/service/change_set_confirmation_service.dart` — confirmation/rejection logic
- `lib/features/agents/ui/change_set_summary_card.dart` — confirmation UI
- `lib/features/agents/state/change_set_providers.dart` — Riverpod providers
- `lib/features/agents/workflow/task_tool_dispatcher.dart` — tool dispatch at confirmation time
- `lib/features/agents/model/change_set.dart` — `ChangeItem` value type
- `lib/features/agents/model/agent_domain_entity.dart` — `ChangeSetEntity`, `ChangeDecisionEntity`
- ADR 0004: Tool execution policy (immediate path)
