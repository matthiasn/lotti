# Agents Feature

This module implements the minimum viable agentic infrastructure for Lotti. The first agent kind is the **Task Agent** — a persistent, mostly-asleep agent that maintains a first-class task summary report and performs incremental metadata updates via tool calls.

## Overview

The agent feature is gated behind the `enableAgents` config flag. When disabled, no agent infrastructure is initialized and no agent-related UI elements appear.

### What the Task Agent Does

1. **Observes** a single task's knowledge graph (the task itself, linked entries, checklists, time entries) from the journal domain in `db.sqlite`. The agent does not own this data.
2. **Maintains** its internal operational state in a separate `agent.sqlite` database: reports, messages, wake history, and tool call records.
3. **Produces** a persistent "task summary" report viewable without LLM recompute.
4. **Calls tools** to mutate journal-domain data via existing handlers (`TaskEstimateHandler`, `TaskDueDateHandler`, `TaskPriorityHandler`, `LottiBatchChecklistHandler`, `LottiChecklistUpdateHandler`, `TaskTitleHandler`).
5. **Wakes incrementally**: sees what changed since its last wake, updates only what is affected, and persists its new state.

## Architecture

### Database (`database/`)

A separate SQLite database (`agent.sqlite`) managed by Drift:

- **`agent_database.drift`** — SQL schema with four tables: `agent_entities` (all entity variants), `agent_links` (relationships), `wake_run_log` (execution history), `saga_log` (cross-domain write tracking).
- **`agent_database.dart`** — Drift `GeneratedDatabase` class.
- **`agent_db_conversions.dart`** — Bidirectional mapping between Drift rows and Freezed models, handling type/subtype discrimination and the `updatedAt` fallback for immutable variants.
- **`agent_repository.dart`** — Typed CRUD access: entity upsert/get, link upsert/query, wake run log, saga log.

### Models (`model/`)

Freezed sealed unions following the `JournalEntity` / `EntryLink` patterns:

- **`agent_domain_entity.dart`** — `AgentDomainEntity` with 7 variants: `agent` (identity), `agentState`, `agentMessage`, `agentMessagePayload`, `agentReport`, `agentReportHead`, `unknown` (forward-compat fallback). Uses `@Freezed(fallbackUnion: 'unknown')`.
- **`agent_link.dart`** — `AgentLink` with 6 variants: `basic` (fallback), `agentState`, `messagePrev`, `messagePayload`, `toolEffect`, `agentTask`. Uses `@Freezed(fallbackUnion: 'basic')`.
- **`agent_config.dart`** — `AgentConfig`, `AgentSlots`, `AgentMessageMetadata` as Freezed data classes.
- **`agent_enums.dart`** — `AgentLifecycle`, `AgentInteractionMode`, `AgentRunStatus`, `AgentMessageKind`.

### Wake Infrastructure (`wake/`)

The wake system handles agent activation in response to data changes:

- **`run_key_factory.dart`** — Deterministic SHA-256 run key generation for subscription, timer, and user-initiated wakes. Also generates `operationId` and `actionStableId` for saga idempotency.
- **`wake_queue.dart`** — In-memory FIFO queue with run-key deduplication and token coalescing. Rapid-fire notifications for the same agent merge into one pending job.
- **`wake_runner.dart`** — Single-flight execution engine. Each agent can have at most one concurrent wake; additional requests wait or re-enqueue.
- **`wake_orchestrator.dart`** — Notification listener that matches `UpdateNotifications` tokens against agent subscriptions, applies self-notification suppression via vector clock comparison, and dispatches wake jobs.

### Tools (`tools/`)

Tool definitions and execution with safety enforcement:

- **`agent_tool_registry.dart`** — Declarative tool definitions (name, description, JSON Schema parameters) for the 6 Task Agent tools: `set_task_title`, `update_task_estimate`, `update_task_due_date`, `update_task_priority`, `add_multiple_checklist_items`, `update_checklist_items`.
- **`agent_tool_executor.dart`** — Orchestrates tool execution with **fail-closed category enforcement** (checks `allowedCategoryIds` before any handler invocation), audit message persistence, and vector clock capture for self-notification suppression.
- **`task_title_handler.dart`** — The only new handler (all others reuse existing handlers from `lib/features/ai/functions/`). Updates a task's title via `journalRepository.updateJournalEntity`.

### Workflow (`workflow/`)

The full wake cycle implementation:

- **`task_agent_strategy.dart`** — `ConversationStrategy` implementation that dispatches LLM tool calls to `AgentToolExecutor`, persists each message turn to `agent.sqlite` for durability, and extracts the structured report and observations from the LLM's final response.
- **`task_agent_workflow.dart`** — Assembles context (agent state, current report, agentJournal observations, task details from `AiInputRepository`, trigger delta), resolves a Gemini inference provider, runs the conversation via `ConversationRepository`, persists the updated report and observations, and updates agent state. Includes `conversationRepository.deleteConversation(conversationId)` cleanup in a `finally` block.

### Service Layer (`service/`)

High-level agent lifecycle management:

- **`agent_service.dart`** — `AgentService` provides `createAgent`, `getAgent`, `listAgents`, `getAgentReport`, `pauseAgent`, `resumeAgent`, `destroyAgent`. Lifecycle transitions update the identity entity and manage wake subscriptions.
- **`task_agent_service.dart`** — `TaskAgentService` provides task-specific operations: `createTaskAgent` (creates agent + state + link + subscription), `getTaskAgentForTask` (lookup via `agent_task` link), `triggerReanalysis` (manual re-wake), `restoreSubscriptions` (app startup recovery).

### State (`state/`)

Riverpod providers for dependency injection:

- **`agent_providers.dart`** — `keepAlive` providers for `AgentDatabase`, `AgentRepository`, `WakeQueue`, `WakeRunner`, `WakeOrchestrator`, `AgentService`. Auto-disposed async providers for `agentReport`, `agentState`, `agentIdentity`.
- **`task_agent_providers.dart`** — `keepAlive` provider for `TaskAgentService`, auto-disposed async provider for `taskAgent(taskId)`.

### UI (`ui/`)

Agent inspection interface:

- **`agent_detail_page.dart`** — Full inspection page with report, activity log, state, and controls.
- **`agent_report_section.dart`** — Renders the structured report (title, TLDR, status, progress, learnings).
- **`agent_activity_log.dart`** — Chronological message list with kind badges and timestamps.
- **`agent_controls.dart`** — Pause/resume, re-analyze, and destroy actions.

## Memory Model

The Task Agent maintains two kinds of persistent memory:

1. **Report** (user-facing) — Rewritten each wake. Always viewable, always current. Contains status, progress, remaining items, learnings.
2. **AgentJournal** (agent-private) — Append-only observation notes accumulated across wakes. Gives the agent longitudinal awareness.

On each wake, the LLM sees: system prompt + current report + all agentJournal observations + delta (changed entities). Full conversation turns from prior wakes are NOT replayed — they exist only as audit trail.

## Safety Boundaries

- Tool calls are scoped to `Agent.allowedCategoryIds` — **fail-closed** on scope violation.
- Inference payload is bounded to the task the agent owns + linked entities.
- All tool calls are logged as `AgentMessage` records (audit trail).
- User can pause/destroy any agent immediately via the agent detail page.
- Agent cannot create, delete, or modify entities outside its owned task's subgraph.

## File Structure

```
lib/features/agents/
├── README.md
├── model/
│   ├── agent_domain_entity.dart     # Freezed sealed union (7 variants)
│   ├── agent_link.dart              # Freezed sealed union (6 variants)
│   ├── agent_config.dart            # AgentConfig, AgentSlots, AgentMessageMetadata
│   └── agent_enums.dart             # All agent-domain enums
├── database/
│   ├── agent_database.dart          # Drift database class
│   ├── agent_database.drift         # SQL schema
│   ├── agent_db_conversions.dart    # Type mapping
│   └── agent_repository.dart        # CRUD + query repository
├── wake/
│   ├── run_key_factory.dart         # Deterministic run key generation
│   ├── wake_queue.dart              # In-memory FIFO queue with dedup
│   ├── wake_runner.dart             # Single-flight execution engine
│   └── wake_orchestrator.dart       # Notification listener + subscriptions
├── tools/
│   ├── agent_tool_registry.dart     # Tool definitions
│   ├── agent_tool_executor.dart     # Enforcement + audit + dispatch
│   └── task_title_handler.dart      # New set_task_title handler
├── workflow/
│   ├── task_agent_strategy.dart     # ConversationStrategy for task agent
│   └── task_agent_workflow.dart     # Full wake cycle orchestration
├── service/
│   ├── agent_service.dart           # Lifecycle management
│   └── task_agent_service.dart      # Task-agent-specific operations
├── state/
│   ├── agent_providers.dart         # Riverpod providers
│   └── task_agent_providers.dart    # Task agent providers
└── ui/
    ├── agent_detail_page.dart       # Inspection page
    ├── agent_report_section.dart    # Report renderer
    ├── agent_activity_log.dart      # Message log
    └── agent_controls.dart          # Action buttons
```

## Testing

Tests mirror the source structure under `test/features/agents/`:

- **Model tests** — Serialization roundtrips for all entity and link variants (46 tests)
- **Database tests** — Repository CRUD for entities, links, wake run log, saga log (46 tests)
- **Wake tests** — Run key determinism, queue dedup, single-flight, orchestrator matching (76 tests)
- **Tool tests** — Category enforcement, audit logging, vector clock capture, handler dispatch (52 tests)
- **Service tests** — Lifecycle management, task agent creation, link lookups
- **Workflow tests** — Context assembly, conversation execution, report persistence
- **UI tests** — Widget tests for the agent detail page

## Deferred Items

| Item | Reason | Phase |
|---|---|---|
| `NotificationBatch` envelope | MVP uses raw token sets | 0B |
| Full saga recovery | MVP uses idempotency checks | 0B |
| Persisted subscriptions | In-memory sufficient for single-device | 0B |
| Memory compaction | Task agents have bounded history | 0C |
| Sync payloads | Local-first focus | 0B |
| Configurable model selection | Hardcoded to Gemini for MVP | 0B |
