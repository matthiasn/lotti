# Minimum Agentic Layer: Task Agent Implementation Plan

Date: 2026-02-20
Status: Draft for review
Companion docs:
- `docs/implementation_plans/2026-02-17_explicit_agents_foundation_layer.md`
- `docs/implementation_plans/2026-02-17_explicit_agents_foundation_layer_formal_model.md`
- `docs/implementation_plans/2026-02-19_agentic_product_direction.md`

## 1. Objective

Implement the minimum viable agentic infrastructure to support a **Task Agent** — a persistent, mostly-asleep agent that maintains a first-class task summary report and performs incremental metadata updates via tool calls.

### What the Task Agent does

1. Maintains a read-only view of one task's knowledge graph (the task itself, linked entries, checklists, time entries — all owned by journal domain in `db.sqlite`). The agent does not own this data; it observes it.
2. Owns its internal operational state: report, messages, wake history, and tool call records (all in `agent.sqlite`).
3. Maintains a persistent "task summary" report (viewable without LLM recompute).
4. Uses explicit tool calls to mutate journal-domain data via existing handlers in `lib/features/ai/functions/` (`TaskEstimateHandler`, `TaskDueDateHandler`, `TaskPriorityHandler`, `LottiBatchChecklistHandler`, `LottiChecklistUpdateHandler`, etc.). These handlers already persist through `journalRepository.updateJournalEntity()` into `db.sqlite`. The only new handler needed is `set_task_title`.
5. Wakes incrementally: sees what changed since its last wake, updates only what is affected, and persists its new state.

### Scope boundaries

- Local infrastructure only (no sync payloads in this phase).
- No orchestrator/attention layer, no persona versioning, no creative artifacts.
- No memory compaction (hot memory only for MVP; compaction is additive later).
- Model hardcoded to `models/gemini-3.1-pro-preview` for MVP. Configurable model selection deferred to a later iteration. The agent does **not** use the `AiConfigPrompt` → `AiResponseType` path — that path pollutes journal domain with AI output and is being phased out. Agent inference output stays in `agent.sqlite` as `AgentMessage` and `AgentReport` records.
- Cross-domain saga is simplified: journal-domain writes use existing `PersistenceLogic`, agent-domain writes are separate; full saga recovery deferred to Phase 0B.

## 2. Database Architecture: `agent.sqlite`

### 2.1 Design principles

- Separate SQLite database file (`agent.sqlite`), opened and managed by a dedicated `AgentDatabase` class using Drift.
- All agent-domain entities stored as typed rows with a `serialized` JSON column (matching the journal-domain pattern).
- Agent entities use a **single `agent_entities` table with type/subtype discrimination** (union-type pattern), analogous to how `journal` stores all `JournalEntity` variants.
- Agent links use a dedicated `agent_links` table (forked from `linked_entries` pattern).
- Wake/run bookkeeping uses dedicated tables for operational correctness.

### 2.2 Schema: `agent_entities` table

This table stores all agent-domain entity variants in a single table, discriminated by `type`:

```sql
CREATE TABLE agent_entities (
  id TEXT NOT NULL PRIMARY KEY,
  agent_id TEXT NOT NULL,
  type TEXT NOT NULL,          -- 'agent', 'agentState', 'agentMessage',
                               -- 'agentMessagePayload', 'agentReport',
                               -- 'agentReportHead'
  subtype TEXT,                -- e.g. message kind: 'observation', 'action', 'toolResult'
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  deleted_at DATETIME,
  serialized TEXT NOT NULL,    -- full JSON of the typed entity
  schema_version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_agent_entities_agent_id ON agent_entities(agent_id);
CREATE INDEX idx_agent_entities_type ON agent_entities(type, agent_id, created_at DESC);
CREATE INDEX idx_agent_entities_agent_type_sub ON agent_entities(agent_id, type, subtype, created_at DESC);
```

**Why a single table instead of per-type tables:**

- Matches the proven journal-domain pattern (`journal` table stores Task, TextEntry, AiResponse, etc.).
- Simplifies sync: one entity payload type with subtype discriminator (as specified in foundation doc sync payload strategy).
- Simplifies queries: "get all entities for agent X" is one indexed scan.
- Type-specific queries use `type` + `subtype` indexes.
- Avoids schema migration complexity of N separate tables.

**Entity types stored (MVP):**

| `type` value | Dart model | Purpose |
|---|---|---|
| `agent` | `AgentEntity` | Identity, lifecycle, config, allowed categories |
| `agentState` | `AgentStateEntity` | Durable state snapshot (slots, pointers, schedule) |
| `agentMessage` | `AgentMessageEntity` | Immutable log entry (observation, action, toolResult, etc.) |
| `agentMessagePayload` | `AgentMessagePayloadEntity` | Normalized large content (report body, tool args) |
| `agentReport` | `AgentReportEntity` | Immutable user-facing report snapshot |
| `agentReportHead` | `AgentReportHeadEntity` | Latest report pointer per scope |

### 2.3 Schema: `agent_links` table

```sql
CREATE TABLE agent_links (
  id TEXT NOT NULL PRIMARY KEY,
  from_id TEXT NOT NULL,
  to_id TEXT NOT NULL,
  type TEXT NOT NULL,           -- relation type (see below)
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  deleted_at DATETIME,
  serialized TEXT NOT NULL,     -- full JSON of AgentLink
  schema_version INTEGER NOT NULL DEFAULT 1,
  UNIQUE(from_id, to_id, type)
);

CREATE INDEX idx_agent_links_from ON agent_links(from_id, type);
CREATE INDEX idx_agent_links_to ON agent_links(to_id, type);
CREATE INDEX idx_agent_links_type ON agent_links(type);
```

**Link relation types (MVP):**

| `type` value | Semantics |
|---|---|
| `agent_state` | Agent → current AgentState |
| `agent_head_message` | Agent → head message in thread |
| `message_prev` | Message → previous message (linked list) |
| `message_payload` | Message → payload entry |
| `agent_report_head` | Agent → current report head |
| `report_source_span` | Report → source message range |
| `tool_effect` | ToolResult message → affected journal entity ID |
| `agent_task` | Agent → journal-domain Task ID (cross-domain ref) |

### 2.4 Schema: `wake_run_log` table

Operational bookkeeping for idempotent wake execution:

```sql
CREATE TABLE wake_run_log (
  run_key TEXT NOT NULL PRIMARY KEY,
  agent_id TEXT NOT NULL,
  reason TEXT NOT NULL,          -- 'subscription', 'timer', 'userInitiated'
  reason_id TEXT,                -- subscription/timer/session ID
  thread_id TEXT NOT NULL,
  status TEXT NOT NULL,          -- 'queued', 'started', 'completed', 'skipped', 'failed'
  logical_change_key TEXT,
  created_at DATETIME NOT NULL,
  started_at DATETIME,
  completed_at DATETIME,
  error_message TEXT
);

CREATE INDEX idx_wake_run_log_agent ON wake_run_log(agent_id, created_at DESC);
CREATE INDEX idx_wake_run_log_status ON wake_run_log(status);
```

### 2.5 Schema: `saga_log` table

Cross-domain write tracking (simplified for MVP):

```sql
CREATE TABLE saga_log (
  operation_id TEXT NOT NULL PRIMARY KEY,
  run_key TEXT NOT NULL,
  phase TEXT NOT NULL,           -- 'journal_pending', 'journal_done', 'agent_done'
  status TEXT NOT NULL,          -- 'pending', 'completed', 'failed'
  tool_name TEXT NOT NULL,
  last_error TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE INDEX idx_saga_log_status ON saga_log(status, updated_at);
```

## 3. Dart Data Models

### 3.1 Freezed sealed union: `AgentEntity`

Following the `JournalEntity` pattern with `@Freezed(fallbackUnion: 'unknown')`:

All synced entity variants carry a `VectorClock?` assigned at creation time via
`VectorClockService`, matching the journal-domain pattern. This makes entities
sync-ready from day one.

Note: `AgentRuntimeState` is an in-memory-only class (never persisted, never synced).
It is reconstructed from `AgentState` on each agent wake. There is no persisted entity
for it — crash, device loss, or normal wake completion simply discards it.

```dart
@Freezed(fallbackUnion: 'unknown')
abstract class AgentDomainEntity with _$AgentDomainEntity {
  /// Agent identity and lifecycle
  const factory AgentDomainEntity.agent({
    required String id,
    required String agentId,  // same as id for agent type
    required String kind,
    required String displayName,
    required AgentLifecycle lifecycle,
    required AgentInteractionMode mode,
    required Set<String> allowedCategoryIds,
    required String currentStateId,
    required AgentConfig config,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
    DateTime? destroyedAt,
  }) = AgentIdentityEntity;

  /// Durable state snapshot
  const factory AgentDomainEntity.agentState({
    required String id,
    required String agentId,
    required int revision,
    required AgentSlots slots,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? lastWakeAt,
    DateTime? nextWakeAt,
    DateTime? sleepUntil,
    String? recentHeadMessageId,
    String? latestSummaryMessageId,
    @Default(0) int consecutiveFailureCount,
    @Default({}) Map<String, int> processedCounterByHost,
    DateTime? deletedAt,
  }) = AgentStateEntity;

  /// Immutable message log entry
  const factory AgentDomainEntity.agentMessage({
    required String id,
    required String agentId,
    required String threadId,
    required AgentMessageKind kind,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    String? prevMessageId,
    String? contentEntryId,
    String? triggerSourceId,
    String? summaryStartMessageId,
    String? summaryEndMessageId,
    @Default(0) int summaryDepth,
    @Default(0) int tokensApprox,
    required AgentMessageMetadata metadata,
    DateTime? deletedAt,
  }) = AgentMessageEntity;

  /// Normalized large content payload
  const factory AgentDomainEntity.agentMessagePayload({
    required String id,
    required String agentId,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    required Map<String, Object?> content,
    @Default('application/json') String contentType,
    DateTime? deletedAt,
  }) = AgentMessagePayloadEntity;

  /// Immutable report snapshot
  const factory AgentDomainEntity.agentReport({
    required String id,
    required String agentId,
    required String scope,
    required DateTime createdAt,
    required VectorClock? vectorClock,
    required Map<String, Object?> content,
    double? confidence,
    @Default({}) Map<String, Object?> provenance,
    DateTime? deletedAt,
  }) = AgentReportEntity;

  /// Latest report pointer
  const factory AgentDomainEntity.agentReportHead({
    required String id,
    required String agentId,
    required String scope,
    required String reportId,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentReportHeadEntity;

  /// Fallback for forward compatibility
  const factory AgentDomainEntity.unknown({
    required String id,
    required String agentId,
    required DateTime createdAt,
    VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentUnknownEntity;

  factory AgentDomainEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentDomainEntityFromJson(json);
}
```

### 3.2 Freezed sealed union: `AgentLink`

All agent links carry a `VectorClock?` assigned at creation, matching `EntryLink`.

```dart
@Freezed(fallbackUnion: 'basic')
abstract class AgentLink with _$AgentLink {
  const factory AgentLink.basic({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = BasicAgentLink;

  const factory AgentLink.agentState({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentStateLink;

  const factory AgentLink.messagePrev({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = MessagePrevLink;

  const factory AgentLink.messagePayload({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = MessagePayloadLink;

  const factory AgentLink.toolEffect({
    required String id,
    required String fromId,
    required String toId,  // journal-domain entity ID
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = ToolEffectLink;

  const factory AgentLink.agentTask({
    required String id,
    required String fromId,  // agent ID
    required String toId,    // journal task ID
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = AgentTaskLink;

  factory AgentLink.fromJson(Map<String, dynamic> json) =>
      _$AgentLinkFromJson(json);
}
```

### 3.3 Supporting enums and types

```dart
enum AgentLifecycle { created, active, dormant, destroyed }
enum AgentInteractionMode { autonomous, interactive, hybrid }
enum AgentRunStatus { idle, queued, running, failed }
enum AgentMessageKind {
  observation, user, thought, action, toolResult, summary, system
}

// Reuse from foundation doc
class AgentConfig { ... }
class AgentSlots { ... }
class AgentMessageMetadata { ... }
```

## 4. Agent Infrastructure

### 4.1 Database layer: `AgentDatabase`

```
lib/features/agents/
├── database/
│   ├── agent_database.dart          # Drift database class for agent.sqlite
│   ├── agent_database.drift         # SQL schema
│   ├── agent_db_conversions.dart    # Type mapping (AgentDomainEntity ↔ DB row)
│   └── agent_repository.dart        # CRUD + query repository
```

**`AgentDatabase`** is a Drift `GeneratedDatabase` managing `agent.sqlite`:
- Opened at app startup alongside `JournalDb`.
- Registered in GetIt as a singleton.
- Schema versioned independently from `db.sqlite`.

**`AgentRepository`** provides typed access:
- `upsertEntity(AgentDomainEntity entity)` — insert or update any entity variant
- `getEntity(String id)` → `AgentDomainEntity?`
- `getEntitiesByAgentId(String agentId, {String? type})` → `List<AgentDomainEntity>`
- `getAgentState(String agentId)` → `AgentStateEntity?`
- `getMessagesForThread(String agentId, String threadId, {int limit})` → `List<AgentMessageEntity>`
- `getLatestReport(String agentId, String scope)` → `AgentReportEntity?`
- `upsertLink(AgentLink link)` — insert or update link
- `getLinksFrom(String fromId, {String? type})` → `List<AgentLink>`
- `getLinksTo(String toId, {String? type})` → `List<AgentLink>`

**`AgentDbConversions`** maps between Drift rows and Freezed models:
- `toDbEntity(AgentDomainEntity) → AgentDbEntity` (extracts type/subtype/agentId for indexed columns)
- `fromDbEntity(AgentDbEntity) → AgentDomainEntity` (deserializes from JSON)

### 4.2 Wake execution model

```
lib/features/agents/
├── wake/
│   ├── wake_queue.dart              # In-memory priority queue
│   ├── wake_orchestrator.dart       # Listens to notifications, matches subscriptions
│   ├── wake_runner.dart             # Single-flight execution engine
│   └── run_key_factory.dart         # Deterministic run key generation
```

**Wake unit of execution:**

A `Wake` is the atomic unit of agent work. Each wake:

1. **Has a deterministic `runKey`** derived from:
   - Subscription wake: `SHA256(agentId | subscriptionId | logicalChangeKey)`
   - Timer wake: `SHA256(agentId | timerId | scheduledAt)`
   - User-initiated: `SHA256(agentId | sessionId | turnId)`

2. **Executes through these phases:**
   ```
   enqueue → dedupe check (runKey) → acquire single-flight lock
   → load agent + state + recent messages
   → assemble context (what changed since last wake)
   → execute workflow (LLM call + tool calls)
   → persist messages + state + report
   → release lock → emit notifications
   ```

3. **Tool calls use deterministic `operationId`:**
   ```
   actionStableId = SHA256(toolName | canonicalArgsHash | scopeSnapshot | targetRefs)
   operationId = SHA256(runKey | actionStableId)
   ```
   This ensures replays/retries never duplicate mutations.

4. **Persists terminal status** in `wake_run_log` for every run.

### 4.3 Memory model: two kinds of memory

The agent maintains two distinct kinds of persistent memory:

#### 1. Report (user-facing)

The `AgentReport` is what the agent tells the user. "Here's where the task stands."
Always viewable, always current. Contains the TLDR: status, what got done, what's
open, learnings, progress. **Rewritten each wake** — the latest report replaces the
previous one as the current view.

#### 2. AgentJournal (agent-private working notes)

An append-only log of the agent's private observations — a consultant's notebook
about this task. Accumulated across wakes, never rewritten. Examples:

- "User moved the due date for the third time (was Feb 20 → Feb 25 → Mar 1)"
- "User struggled with the OAuth integration for 2 days before completing it"
- "Priority escalated from P2 to P1 after the standup"
- "3 of 5 checklist items completed in one session — good momentum"
- "User added 'Write integration tests' — this is the only remaining blocker"

These are persisted as `AgentMessage` records with `kind: observation`. They give
the agent longitudinal awareness — it can notice patterns across wakes that a
single report snapshot cannot capture.

#### What the LLM sees on each wake

On each wake, the LLM receives:
1. **System prompt** — agent role, tool definitions, instructions
2. **Current report** — the user-facing summary (what the agent last told the user)
3. **AgentJournal** — all accumulated observation notes from prior wakes
4. **Delta** — what changed since the last wake (from trigger tokens + journal-domain reads)

The agent then:
- Calls tools as needed (within the wake, the multi-turn loop runs via `ConversationManager`)
- Appends new observation notes to the journal (things worth remembering)
- Produces an updated report

#### What is NOT replayed

The full conversation turns from prior wakes (assistant responses, tool call/result
pairs) are **not** replayed to the LLM. They are persisted as `AgentMessage` records
for the **audit trail** visible on the agent detail page, but only the observations
and the report carry forward as LLM context.

#### Within a single wake

The multi-turn tool-call loop runs via `ConversationManager` in memory. The model
calls tools, we execute them, send results back, the model continues. Each turn is
persisted as an `AgentMessage` as it happens (for durability and inspection).
At the end of the wake, the agent writes its new observation notes and updated report.

#### Bounded growth

The agentJournal grows by a small number of observations per wake. For task-scoped
agents with bounded lifetimes, this stays manageable. For long-running agents (future),
the foundation doc's memory compaction (summarize old observation spans) applies here —
but that's deferred, not needed for Task Agent MVP.

### 4.4 Incremental trigger design

The key insight for the Task Agent is **incremental awareness**. The agent does not re-analyze the entire task on every wake. Instead:

1. **Trigger payload carries change information:**
   - The notification batch contains typed tokens (e.g., `TASK`, checklist item ID).
   - The wake orchestrator passes the `logicalChangeKey` and matched tokens to the agent workflow.

2. **Agent state tracks watermarks:**
   - `AgentState.processedCounterByHost` tracks the last processed sync counter per host.
   - `AgentState.recentHeadMessageId` points to the last message the agent saw.

3. **Context assembly is differential:**
   - Load the agent's last report content.
   - Load only journal entries/checklist items that changed since last wake (using entity IDs from the trigger).
   - The LLM prompt says: "Here is the current task report. Here is what changed: [delta]. Update the report and call tools as needed."

4. **Tool calls are surgical:**
   - If a user checks off a checklist item, the agent sees only that delta.
   - The agent may call `update_checklist_items` to update the report's progress section.
   - The agent may call `set_task_title` if the change warrants a title update.
   - No full re-analysis unless the agent decides the delta is large enough.

**Integration with existing `UpdateNotifications`:**

For MVP, we use the existing `UpdateNotifications.updateStream` directly (no `NotificationBatch` envelope yet). The wake orchestrator:

1. Listens to `updateStream`.
2. Classifies tokens using existing notification constants (`taskNotification`, `aiResponseNotification`, etc.) and entity IDs.
3. Matches against registered agent subscriptions.
4. Enqueues wake jobs.

The full `NotificationBatch` + `logicalChangeKey` infrastructure from the formal model is a Phase 0B upgrade. For MVP, the run key is derived from `SHA256(agentId | subscriptionId | batchTokensHash)` where `batchTokensHash` is the sorted hash of the token set. This is not cross-device deterministic but is sufficient for single-device MVP.

### 4.5 Subscription model (MVP simplified)

For MVP, subscriptions are in-memory configurations (not persisted):

```dart
class AgentSubscription {
  final String id;
  final String agentId;
  final Set<String> matchTokenKeys;   // e.g., {taskNotification}
  final Set<String>? matchEntityIds;  // specific entity IDs to watch
  final bool Function(Set<String> tokens)? predicate;  // optional filter
}
```

The Task Agent registers a subscription for:
- `matchTokenKeys: {taskNotification}` — any task change
- `matchEntityIds: {taskId}` — the specific task it owns
- Plus linked entity IDs (checklist items, text entries linked to the task)

### 4.6 Notification integration with existing system

The existing `UpdateNotifications` emits `Set<String>` containing both semantic keys and entity IDs. The wake orchestrator uses this directly:

```
UpdateNotifications.updateStream
  → WakeOrchestrator.onBatch(Set<String> tokens)
    → classify tokens (semantic keys vs entity IDs)
    → for each subscription: check match
    → if match: derive runKey, enqueue wake
```

The orchestrator must be careful to **not wake the agent for its own writes**. This is achieved by:
- Maintaining a `Set<String> suppressedRunKeys` of recently completed runs.
- When the agent's tool calls emit notifications, the resulting tokens are tagged (via a thread-local or explicit parameter) so the orchestrator ignores them for the originating agent.

## 5. Task Agent Workflow

### 5.1 Agent kind: `taskAgent`

Configuration:
- `kind: 'taskAgent'`
- `mode: autonomous`
- `allowedCategoryIds: {task's categoryId}`
- `slots.activeTaskId: taskId`

### 5.2 Tool capabilities

The Task Agent has access to these tools (reusing existing infrastructure where possible):

| Tool name | Existing handler | Location |
|---|---|---|
| `set_task_title` | None (new — title update via `journalRepository.updateJournalEntity`) | New handler needed |
| `set_task_language` | `set_task_language` inline handler | `lotti_conversation_processor.dart` |
| `update_task_estimate` | `TaskEstimateHandler` | `task_estimate_handler.dart` |
| `update_task_due_date` | `TaskDueDateHandler` | `task_due_date_handler.dart` |
| `update_task_priority` | `TaskPriorityHandler` | `task_priority_handler.dart` |
| `add_multiple_checklist_items` | `LottiBatchChecklistHandler` | `lotti_batch_checklist_handler.dart` |
| `update_checklist_items` | `LottiChecklistUpdateHandler` | `lotti_checklist_update_handler.dart` |
| `assign_task_labels` | `LabelAssignmentProcessor` | `label_assignment_processor.dart` |

All existing handlers live under `lib/features/ai/functions/` and produce side effects in journal domain via `journalRepository.updateJournalEntity()` and `checklistRepository`. These are the established interface for AI-produced mutations and should be reused directly by the agent — not wrapped or duplicated.

The only new tool needed is `set_task_title`, which does not exist today. It should follow the same handler pattern (`processToolCall` → validate → `task.data.copyWith(title:)` → `journalRepository.updateJournalEntity`).

**Agent-side integration:**

The agent's wake workflow calls these handlers directly. The additional agent-domain bookkeeping (recording the tool call as an `AgentMessage` with `kind: action` / `kind: toolResult`, and logging the `operationId` in the saga log for idempotency) is layered on top of the existing handler execution, not inside the handlers themselves.

### 5.3 Wake workflow pseudocode

```
wake(agent, triggerTokens):
  // 1. Load current state + both memory types
  state = repo.getAgentState(agent.id)
  lastReport = repo.getLatestReport(agent.id, 'current')
  journal = repo.getMessages(agent.id, kind: observation)  // all prior notes

  // 2. Determine what changed
  taskId = state.slots.activeTaskId
  task = journalDb.getEntityById(taskId)
  linkedEntities = journalDb.getLinkedEntities(taskId)
  changedIds = triggerTokens.intersection(allRelevantIds)

  // 3. Assemble context with both memory types + delta
  context = WakeContext(
    currentReport: lastReport?.content,         // memory type 1: user-facing
    agentJournal: journal,                      // memory type 2: private notes
    task: task,
    changedEntities: filterByIds(linkedEntities, changedIds),
    allChecklistItems: getChecklistItems(task),
  )

  // 4. Run conversation using existing ConversationRepository/ConversationManager
  //    This is the same infrastructure used by ai_chat.
  //    The user message contains: current report + agentJournal notes + delta.
  //    The LLM is instructed to:
  //    - Call tools as needed
  //    - Produce an updated report
  //    - Produce new observation notes (things worth remembering)
  conversationId = conversationRepo.createConversation(
    systemMessage: taskAgentSystemPrompt,
    maxTurns: 5,
  )
  strategy = TaskAgentStrategy(
    // Uses existing handlers: TaskEstimateHandler, LottiBatchChecklistHandler, etc.
    // Wraps each call with operationId derivation + saga log
  )
  await conversationRepo.sendMessage(
    conversationId: conversationId,
    message: context.toUserMessage(),
    model: 'models/gemini-3.1-pro-preview',
    provider: resolvedProvider,
    tools: taskAgentToolDefinitions,
    strategy: strategy,
  )

  // 5. AgentMessage persistence happens per turn, not after completion.
  //    The TaskAgentStrategy persists each message to agent.sqlite as it
  //    occurs: assistant response, tool call (kind: action), tool result
  //    (kind: toolResult). This ensures durable progress — a crash
  //    mid-conversation loses at most the in-flight API call, not
  //    prior turns. ConversationManager still keeps its in-memory list
  //    for the API calls; the agent layer writes in parallel.

  // 6. Persist new observation notes (agentJournal entries)
  //    The LLM produces these as part of its response — things worth
  //    remembering for future wakes.
  for note in strategy.extractObservations():
    repo.upsertEntity(AgentMessageEntity(
      kind: AgentMessageKind.observation,
      agentId: agent.id,
      content: note,
      ...
    ))

  // 7. Extract and persist updated report
  newReport = AgentReportEntity(
    content: strategy.extractReportContent(),
    ...
  )
  repo.upsertEntity(newReport)
  repo.upsertEntity(reportHead.copyWith(reportId: newReport.id))

  // 8. Update state
  newState = state.copyWith(
    recentHeadMessageId: lastMessageId,
    lastWakeAt: now,
    consecutiveFailureCount: 0,
  )
  repo.upsertEntity(newState)
```

### 5.4 Task context assembly

The agent reads journal-domain task data via the existing `AiInputRepository`:

- `AiInputRepository.buildTaskDetailsJson(taskId)` — full task JSON with checklist
  items, log entries (text, audio transcripts, images), labels, time spent, estimate.
  Uses `AiInputTaskObject` serialization.
- `AiInputRepository.buildLinkedTasksJson(taskId)` — parent/child task context with
  their latest summaries.

This is the same context assembly used by the current task summary flow. The agent
reuses it as its read layer into journal domain — no duplication.

### 5.5 Prompt design

The agent has its own prompt, separate from the existing `taskSummaryPrompt` in
`preconfigured_prompts.dart`. It does NOT go through the `AiConfigPrompt` /
`AiResponseType` path.

**System prompt** includes:
- Agent role and personality
- Tool definitions (set_task_title, update_task_estimate, etc.)
- Instructions for producing both an updated report AND new agentJournal observations
- Guidelines for when to call tools vs when to just update the report

**User message on first wake** (no prior report):
- Full task context from `AiInputRepository`
- Linked tasks context
- Instruction: "Produce an initial report and any observations worth remembering."

**User message on subsequent wakes:**
- Current report (the agent's last user-facing summary)
- AgentJournal entries (all accumulated private observations)
- Delta: what changed since last wake (changed entities from trigger tokens)
- Full current task context from `AiInputRepository` (so the agent can cross-reference)
- Instruction: "Update the report based on what changed. Add observations if warranted. Call tools if needed."

**LLM output structure** (structured output or parsed from response):
- Updated report content
- New agentJournal observations (zero or more)
- Tool calls (handled by `ConversationManager` multi-turn loop)

### 5.6 Report format

The report follows a format inspired by the existing task summary output
(TLDR, goal, progress, remaining, learnings) but stored as structured JSON
in `AgentReportEntity.content`:

```json
{
  "title": "Implement authentication module",
  "tldr": "OAuth2 integration 60% complete. Login UI done, logout and tests remaining. Due Feb 25.",
  "goal": "Add OAuth2-based user authentication with token refresh and full test coverage.",
  "status": "in_progress",
  "priority": "P1",
  "estimate": "4h",
  "dueDate": "2026-02-25",
  "achieved": [
    "Set up OAuth provider configuration",
    "Implemented token refresh logic",
    "Built login UI with error handling"
  ],
  "remaining": [
    "Add logout flow with token revocation",
    "Write integration tests for auth endpoints"
  ],
  "learnings": [
    "Token refresh needed custom interceptor — standard library didn't support it"
  ],
  "checklistProgress": {
    "total": 5,
    "completed": 3
  },
  "lastUpdated": "2026-02-20T14:30:00Z"
}
```

This is stored in `AgentReportEntity.content` and is viewable without any LLM call.
The report format can evolve per agent kind — this is the Task Agent's format.

## 6. Management Interface

### 6.1 Service layer

```
lib/features/agents/
├── service/
│   ├── agent_service.dart           # High-level agent lifecycle management
│   └── task_agent_service.dart      # Task-agent-specific creation and config
```

**`AgentService`** provides:
- `createAgent(kind, displayName, config)` → creates Agent + initial State + registers subscriptions
- `getAgent(agentId)` → `AgentDomainEntity?`
- `listAgents({AgentLifecycle? filter})` → all agents that ever existed
- `getAgentReport(agentId, scope)` → latest report without LLM
- `destroyAgent(agentId)` → lifecycle transition to destroyed, unregister subscriptions
- `pauseAgent(agentId)` → lifecycle transition to dormant
- `resumeAgent(agentId)` → lifecycle transition to active

**`TaskAgentService`** provides:
- `createTaskAgent(taskId)` → creates a Task Agent for a specific task
- `getTaskAgentForTask(taskId)` → finds agent by `agent_task` link
- `triggerReanalysis(agentId)` → manual re-wake with full context

### 6.2 Riverpod providers

```dart
@riverpod
AgentService agentService(Ref ref) => AgentService(
  repository: ref.watch(agentRepositoryProvider),
  wakeOrchestrator: ref.watch(wakeOrchestratorProvider),
);

@riverpod
Future<List<AgentDomainEntity>> allAgents(Ref ref) async {
  final service = ref.watch(agentServiceProvider);
  return service.listAgents();
}

@riverpod
Future<AgentReportEntity?> agentReport(Ref ref, String agentId) async {
  final service = ref.watch(agentServiceProvider);
  return service.getAgentReport(agentId, 'current');
}

@riverpod
Future<AgentDomainEntity?> taskAgent(Ref ref, String taskId) async {
  final service = ref.watch(taskAgentServiceProvider);
  return service.getTaskAgentForTask(taskId);
}
```

## 7. Agent Detail Page (Inspection UI)

A dedicated page/route for inspecting an agent's state, reachable from the task detail view via a button or link.

### 7.1 What the page shows

| Section | Content | Data source |
|---|---|---|
| **Header** | Agent display name, kind, lifecycle badge (`active`/`dormant`/`destroyed`) | `AgentIdentityEntity` |
| **Current Report** | The latest task summary report rendered as structured content (title, status, progress, summary text) | `AgentReportEntity` via report head |
| **Activity Log** | Chronological list of agent messages — observations, tool calls, tool results, system events. Each entry shows timestamp, kind badge, and content preview | `AgentMessageEntity` list for agent's thread |
| **Tool Call History** | Filtered view of `action` + `toolResult` message pairs — what the agent did, whether it succeeded, which journal entities were affected | `AgentMessageEntity` filtered by `kind: action/toolResult` |
| **State** | Current agent state: last wake time, next wake time, consecutive failure count, active task ID | `AgentStateEntity` |
| **Controls** | Pause/resume, trigger re-analysis, destroy agent | `AgentService` methods |

### 7.2 Navigation

- From task detail view: a button/chip (e.g., "Agent" with a status indicator) navigates to the agent detail page for that task's agent.
- The button only appears when a Task Agent exists for the task (query via `agent_task` link).
- Back navigation returns to the task.

### 7.3 Reactive updates

The page listens to `UpdateNotifications` for the agent's entity IDs. When the agent wakes and persists new messages/reports/state, the page updates live without manual refresh.

## 8. File Structure

```
lib/features/agents/
├── README.md
├── model/
│   ├── agent_domain_entity.dart     # Freezed sealed union
│   ├── agent_domain_entity.freezed.dart
│   ├── agent_domain_entity.g.dart
│   ├── agent_link.dart              # Freezed sealed union
│   ├── agent_link.freezed.dart
│   ├── agent_link.g.dart
│   ├── agent_config.dart            # AgentConfig, AgentSlots, AgentMessageMetadata
│   ├── agent_enums.dart             # All agent-domain enums
│   └── agent_tool_call.dart         # AgentToolCall, AgentToolResult
├── database/
│   ├── agent_database.dart
│   ├── agent_database.drift
│   ├── agent_db_conversions.dart
│   └── agent_repository.dart
├── wake/
│   ├── wake_queue.dart
│   ├── wake_orchestrator.dart
│   ├── wake_runner.dart
│   └── run_key_factory.dart
├── tools/
│   ├── agent_tool_registry.dart     # Maps tool names to existing handlers in features/ai/functions/
│   ├── agent_tool_executor.dart     # Validates, delegates to handler, records agent messages + saga log
│   └── task_title_handler.dart      # New handler for set_task_title (only new tool needed)
├── workflow/
│   ├── task_agent_workflow.dart      # Context assembly, conversation orchestration, report persistence
│   └── task_agent_strategy.dart     # ConversationStrategy impl for task agent tool dispatch
├── service/
│   ├── agent_service.dart
│   └── task_agent_service.dart
├── ui/
│   ├── agent_detail_page.dart       # Full agent inspection page
│   ├── agent_report_section.dart    # Report content renderer
│   ├── agent_activity_log.dart      # Message log list
│   └── agent_controls.dart          # Pause/resume/destroy/re-analyze actions
└── state/
    ├── agent_providers.dart          # Riverpod providers
    └── task_agent_providers.dart
```

## 8. Step-by-Step Execution Plan

### Phase 0A-1: Database Schema and Models (Foundation)

1. Create `lib/features/agents/model/agent_enums.dart` with all enums.
2. Create `lib/features/agents/model/agent_config.dart` with `AgentConfig`, `AgentSlots`, `AgentMessageMetadata` as freezed classes.
3. Create `lib/features/agents/model/agent_domain_entity.dart` with the `AgentDomainEntity` sealed union.
4. Create `lib/features/agents/model/agent_link.dart` with the `AgentLink` sealed union.
5. Create `lib/features/agents/model/agent_tool_call.dart` with `AgentToolCall` and `AgentToolResult`.
6. Run build_runner to generate freezed/json code.
7. Write unit tests for serialization roundtrips (all variants).

### Phase 0A-2: Database Layer

8. Create `lib/features/agents/database/agent_database.drift` with all table definitions.
9. Create `lib/features/agents/database/agent_database.dart` (Drift database class).
10. Create `lib/features/agents/database/agent_db_conversions.dart` for type mapping.
11. Create `lib/features/agents/database/agent_repository.dart` with CRUD operations.
12. Register `AgentDatabase` in GetIt (app startup).
13. Write repository tests (CRUD for each entity type, link operations).

### Phase 0A-3: Wake Infrastructure

14. Create `lib/features/agents/wake/run_key_factory.dart` for deterministic run key generation.
15. Create `lib/features/agents/wake/wake_queue.dart` (in-memory priority queue with dedup).
16. Create `lib/features/agents/wake/wake_runner.dart` (single-flight execution with lock).
17. Create `lib/features/agents/wake/wake_orchestrator.dart` (notification listener + subscription matching).
18. Write tests for run key determinism, dedup, and single-flight behavior.

### Phase 0A-4: Tool Layer

19. Create `lib/features/agents/tools/agent_tool_registry.dart` — maps tool names to existing handlers in `lib/features/ai/functions/` (e.g., `TaskEstimateHandler`, `LottiBatchChecklistHandler`). No duplication of handler logic.
20. Create `lib/features/agents/tools/agent_tool_executor.dart` — delegates to registered handlers, then records `AgentMessage` pairs (`action` + `toolResult`) and saga log entries for idempotency.
21. Create `lib/features/agents/tools/task_title_handler.dart` — the only new handler needed (`set_task_title`), following the same pattern as `TaskEstimateHandler`.
22. Write tests for tool executor orchestration, idempotency (operation ID dedup), and error handling.

### Phase 0A-5: Task Agent Workflow

23. Create `lib/features/agents/workflow/task_agent_strategy.dart` — a `ConversationStrategy` implementation that dispatches tool calls to the existing handlers and decides continuation.
24. Create `lib/features/agents/workflow/task_agent_workflow.dart` — assembles differential context, runs the conversation via existing `ConversationRepository`/`ConversationManager`, then persists the resulting messages as `AgentMessage` records and updates the report.
24. Write tests for differential context assembly and report update logic.

### Phase 0A-6: Service Layer and Providers

25. Create `lib/features/agents/service/agent_service.dart` (lifecycle management).
26. Create `lib/features/agents/service/task_agent_service.dart` (task-specific).
27. Create `lib/features/agents/state/agent_providers.dart` and `task_agent_providers.dart`.
28. Write service tests.

### Phase 0A-7: Agent Detail Page

29. Create `lib/features/agents/ui/agent_detail_page.dart` — full inspection page with report, activity log, state, controls.
30. Create `lib/features/agents/ui/agent_report_section.dart` — structured report renderer.
31. Create `lib/features/agents/ui/agent_activity_log.dart` — chronological message list with kind badges.
32. Create `lib/features/agents/ui/agent_controls.dart` — pause/resume/destroy/re-analyze actions.
33. Write widget tests for the agent detail page.

### Phase 0A-8: Integration

34. Wire wake orchestrator into app startup (listen to `UpdateNotifications`).
35. Add manual "Create Task Agent" action in task detail view (button). This creates the agent and triggers an initial full-context wake.
36. Add "Agent" navigation chip in task detail view (visible when a task agent exists) linking to the agent detail page.
37. End-to-end integration test: create task agent → modify task → agent wakes → report updates → inspect on agent page.

## 9. Gaps and Edge Cases to Address

### 9.1 Union type checkpoint modeling

**Decision: entity variants in one table is correct.** The `agent_entities` table with `type` discriminator avoids the combinatorial explosion of per-type tables and matches the journal pattern. However:

- **Forward compatibility:** The `AgentDomainEntity.unknown` fallback handles new entity types from future schema versions gracefully (unknown variants round-trip through JSON without data loss).
- **Schema evolution:** Adding new variants (e.g., `agentSubscription`, `agentTimer`) in later phases only requires adding a new factory constructor to the sealed union + updating the conversions. No table migration needed.

### 9.2 Cross-domain reference integrity

Agent records reference journal-domain entities by ID (`taskId`, `journalEntryId`). These are **soft references** — there is no foreign key constraint across databases. Edge cases:

- **Deleted task:** If a task is deleted in the journal domain, the agent's `agent_task` link becomes a dangling reference. The agent should detect this on wake and transition to `dormant` or `destroyed`.
- **Task re-creation via sync:** If a deletion is reversed by sync conflict resolution, the agent can resume. The dangling-reference check should be non-destructive.

### 9.3 Self-notification suppression

When the agent's tool calls modify journal entities, those modifications emit notifications that could re-trigger the agent. Solutions:

- **Option A (MVP):** The wake orchestrator maintains a short-lived suppression window per agent after a run completes. Any wake triggered within that window for the same agent is deferred.
- **Option B (Better):** Tool calls tag their notification emissions with the originating `agentId`. The orchestrator filters these out for the originating agent's subscriptions.

Recommend Option A for MVP simplicity, upgrade to Option B in Phase 0B.

### 9.4 Concurrent wake coalescing

If multiple changes arrive in rapid succession (e.g., user checks off 3 items quickly), the 100ms debounce window in `UpdateNotifications` naturally batches them. The wake orchestrator should further coalesce: if a wake is already queued for an agent, merge the new trigger tokens into the existing queued wake rather than creating a second one.

### 9.5 Failure handling

- **LLM failure:** Increment `consecutiveFailureCount`, set `nextWakeAt` with exponential backoff. After N failures, transition to `dormant` and notify user.
- **Tool failure:** Record error in `toolResult` message. Agent may retry on next wake or report the failure in its report.
- **Crash during wake:** The `wake_run_log` shows `started` but never `completed`. On next app launch, a recovery scan identifies these and re-queues them (using the same `runKey` for idempotency).

### 9.6 Report head atomicity

Updating the report and the report head pointer should be in the same database transaction (both are in `agent.sqlite`, so this is straightforward with Drift's transaction support). This ensures the head always points to a valid, committed report.

### 9.7 Memory budget for MVP

For MVP, the Task Agent uses a simple memory strategy:
- Load the last N messages (configurable, default 20) as hot context.
- Load the current report as "standing knowledge."
- No compaction, no warm/cold memory tiers.
- This is sufficient for task-scoped agents where history is bounded.

## 10. What This Plan Intentionally Defers

| Deferred item | Why | When |
|---|---|---|
| `NotificationBatch` envelope with `logicalChangeKey` | MVP works with raw token sets; cross-device determinism needs this | Phase 0B |
| Full saga recovery worker | MVP uses simple idempotency checks; full recovery needs startup scan | Phase 0B |
| Persisted subscriptions and timers | In-memory subscriptions are sufficient for single-device MVP | Phase 0B |
| Memory compaction (summarization) | Task agents have bounded history; compaction is for long-running agents | Phase 0C |
| Persona/soul versioning | Not needed for task agent | Phase 1 |
| Orchestrator/attention layer | Not needed until multi-agent | Phase 1 |
| Sync payloads for agent entities | Focus on local-first first | Phase 0B |
| Provider/model policy gates | Task agent uses user's configured AI provider | Phase 0B |
| `NEED_TO_KNOW` payload projection | Task agent context is already scoped to one task | Phase 0B |
