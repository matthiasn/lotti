# Agents Architecture

This feature provides persistent, sync-aware agents for Lotti, centered on:

1. Task Agents (production path): wake on task changes, run tool calls, and keep a durable report.
2. Template Evolution Sessions: chat-driven directive evolution with versioned template history.

The system is enabled only when `enableAgents` is true.

## Runtime Scope

- Journal domain (`db.sqlite`): source-of-truth task/checklist/time data.
- Agent domain (`agent.sqlite`): agent identities, state, messages, reports, template versions, wake runs.
- Inference path: template-selected model (`models/gemini-3-flash-preview` default), resolved via AI config.

### Task Context Assembly (Current)

- Task agent wake prompts include:
  - current task JSON context
  - current report + recent observations
  - linked task context
- Linked task context for agents is built directly in
  `TaskAgentWorkflow._buildLinkedTasksContextJson` (forked from
  `AiInputRepository.buildLinkedTasksJson` for the wake path), and injects
  `latestTaskAgentReport` from each linked task's associated task agent (via
  `agent_task` links + `agentReportHead`).
- Linked-task `latestSummary` payloads are stripped before prompt submission
  and are not used for Task Agent execution.
- MTTR chart inputs resolve linked tasks with de-duplicated task fetches to
  avoid repeated journal lookups for shared task links.

## High-Level Architecture

```mermaid
flowchart LR
  UI["Task/UI Surfaces"] --> INIT["agentInitializationProvider"]
  INIT --> ORCH["WakeOrchestrator"]
  ORCH --> WF["TaskAgentWorkflow"]
  WF --> CONV["ConversationRepository"]
  CONV --> MODEL["Inference Provider (Gemini/OpenAI compatible)"]
  MODEL --> STRAT["TaskAgentStrategy"]
  STRAT --> EXEC["AgentToolExecutor"]
  EXEC --> TOOLS["Task Tool Handlers"]
  TOOLS --> JOURNAL["Journal Repository/DB"]

  STRAT --> CSB["ChangeSetBuilder"]
  CSB --> SYNC["AgentSyncService"]
  SYNC --> AGENTDB["AgentRepository -> agent.sqlite"]
  SYNC --> OUTBOX["Sync Outbox"]

  WF --> SYNC

  CSUI["ChangeSetSummaryCard"] --> CSSVC["ConfirmationService"]
  CSSVC --> DISP["TaskToolDispatcher"]
  DISP --> TOOLS
  CSSVC --> SYNC

  TEMPLATEUI["Template UI"] --> EVO["TemplateEvolutionWorkflow"]
  EVO --> MODEL
  EVO --> AGENTDB
```

## Call Trees

### 1) Subscription Wake (Task Change -> Agent Run)

```mermaid
flowchart TD
  A["UpdateNotifications.localUpdateStream"] --> B["WakeOrchestrator._onBatch(tokens)"]
  B --> C["match subscriptions + suppression + throttle"]
  C --> D["WakeQueue.enqueue/mergeTokens"]
  D --> E["WakeOrchestrator.processNext()"]
  E --> F["WakeOrchestrator._drain()"]
  F --> G["WakeOrchestrator._executeJob(job)"]
  G --> H["wakeExecutor callback (_wireWakeExecutor)"]
  H --> I["TaskAgentWorkflow.execute(...)"]
  I --> J["ConversationRepository.sendMessage(...)"]
  J --> K["TaskAgentStrategy.processToolCalls(...)"]
  K --> L{"Tool deferred?"}
  L -->|No| M["AgentToolExecutor.execute(...)"]
  M --> N["Task handlers + Journal writes"]
  L -->|Yes| O["ChangeSetBuilder.addItem(...)"]
  O --> P["Respond: 'Proposal queued'"]
  I --> Q["ChangeSetBuilder.build() → persist ChangeSetEntity"]
  I --> R["persist report/messages/state via AgentSyncService"]
  R --> S["WakeOrchestrator marks wake_run status"]
  S --> T["Persisted throttle update -> UpdateNotifications.notify(fromSync: true)"]
```

### 1b) Change Set Confirmation (User -> Tool Dispatch)

```mermaid
flowchart TD
  A["ChangeSetSummaryCard"] --> B{"Confirm or Reject?"}
  B -->|Confirm| C["ConfirmationService.confirmItem()"]
  C --> D["Re-read fresh ChangeSetEntity"]
  D --> E["TaskToolDispatcher.dispatch()"]
  E --> F["Task handler executes + Journal write"]
  F --> G["Persist ChangeDecisionEntity"]
  G --> H["Update item status → confirmed"]
  B -->|Reject| I["ConfirmationService.rejectItem()"]
  I --> J["Persist ChangeDecisionEntity"]
  J --> K["Update item status → rejected"]
  H --> L["UpdateNotifications.notify()"]
  K --> L
  L --> M["Provider rebuild → UI refreshes"]
```

### 2) Manual Reanalysis (Agent Detail -> Immediate Run)

```mermaid
flowchart TD
  A["AgentControls._triggerReanalysis()"] --> B["TaskAgentService.triggerReanalysis(agentId)"]
  B --> C["WakeOrchestrator.enqueueManualWake(reason: reanalysis)"]
  C --> D["clearThrottle + remove queued subscription jobs for agent"]
  D --> E["WakeQueue.enqueue(manual job)"]
  E --> F["WakeOrchestrator.processNext()"]
  F --> G["TaskAgentWorkflow.execute(...)"]
```

## Sequence Diagrams

### A) Task Edit -> Orchestrated AI Run (with deferred tool confirmation)

```mermaid
sequenceDiagram
  participant U as User
  participant T as Task UI
  participant N as UpdateNotifications
  participant O as WakeOrchestrator
  participant W as TaskAgentWorkflow
  participant C as ConversationRepository
  participant M as Model Provider
  participant CSB as ChangeSetBuilder
  participant ADB as Agent Repository

  U->>T: Edit task/checklist
  T->>N: Emit changed entity tokens
  N->>O: _onBatch(tokens)
  O->>O: Match subscription, apply suppression/throttle
  O->>O: Enqueue/merge wake job
  O->>O: processNext -> _executeJob
  O->>W: wakeExecutor(agentId, runKey, triggers, threadId)
  W->>C: sendMessage(system+context+tools)
  C->>M: LLM request
  M-->>C: tool calls / final assistant content
  C->>CSB: Deferred tool → addItem(toolName, args)
  CSB-->>C: "Proposal queued for user review."
  Note over W,CSB: End of wake
  W->>CSB: build(syncService)
  CSB->>ADB: Persist ChangeSetEntity (pending)
  W->>ADB: Persist thought/report/observations/state
  W-->>O: WakeResult
  O->>ADB: Update wake_run status
  O->>N: notify({agentId}, fromSync: true)
```

### A2) User Confirms Change Set

```mermaid
sequenceDiagram
  participant U as User
  participant Card as ChangeSetSummaryCard
  participant Svc as ConfirmationService
  participant Disp as TaskToolDispatcher
  participant J as Journal Repository
  participant ADB as Agent Repository
  participant N as UpdateNotifications

  U->>Card: Tap "Confirm all" or per-item ✓
  Card->>Svc: confirmItem(changeSet, index)
  Svc->>ADB: Re-read fresh ChangeSetEntity
  Svc->>Disp: dispatch(toolName, args, taskId)
  Disp->>J: Execute handler (persist mutation)
  J-->>Disp: ToolExecutionResult
  Disp-->>Svc: success
  Svc->>ADB: Persist ChangeDecisionEntity
  Svc->>ADB: Update item status → confirmed
  Svc-->>Card: result
  Card->>N: notify({agentId})
  N-->>Card: Provider rebuild → UI refreshes
```

### B) Template Evolution Chat (UI -> LLM -> Versioning)

```mermaid
sequenceDiagram
  participant U as User
  participant EUI as EvolutionChatPage
  participant S as EvolutionChatState
  participant EW as TemplateEvolutionWorkflow
  participant C as ConversationRepository
  participant M as Model Provider
  participant TS as AgentTemplateService
  participant ADB as Agent Repository

  U->>EUI: Open evolve template
  EUI->>S: build(templateId)
  S->>EW: startSession(templateId)
  EW->>TS: load template/version/metrics/history/context inputs
  EW->>C: createConversation + initial sendMessage
  C->>M: LLM call (tools: propose_directives, record_evolution_note)
  M-->>EW: proposal + notes via strategy
  EW->>ADB: persist evolution session + notes
  U->>EUI: Approve proposal
  EUI->>S: approveProposal()
  S->>EW: approveProposal(sessionId)
  EW->>TS: createVersion(...)
  EW->>ADB: mark session completed
```

## Module Responsibilities

- `wake/`: subscription matching, throttling, queueing, single-flight dispatch, wake-run status.
- `workflow/`: context assembly + LLM orchestration (`TaskAgentWorkflow`, `TemplateEvolutionWorkflow`), change set building (`ChangeSetBuilder`), tool dispatch extraction (`TaskToolDispatcher`).
- `tools/`: declarative tool registry + execution policy/audit wrappers + task tool handlers.
- `service/`: lifecycle APIs for agents/templates, subscription restoration, template versioning/metrics, change set confirmation (`ChangeSetConfirmationService`).
- `sync/`: transaction-aware outbox buffering for agent entity/link writes. All change set operations go through sync for cross-device consistency.
- `state/`: Riverpod DI + read models + initialization wiring + change set providers.
- `ui/`: settings/templates/instances/detail/evolution screens + change set confirmation card (`ChangeSetSummaryCard`).

## Architecture Decision Records

Current-state architecture stays in this README. Decision rationale and
evolution history live in ADRs:

- [`docs/adr/README.md`](../../../docs/adr/README.md)
