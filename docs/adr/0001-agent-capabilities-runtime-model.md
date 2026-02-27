# ADR 0001: Agent Capabilities Runtime Model

- Status: Accepted
- Date: 2026-02-27

## Context

Agent Capabilities now includes persistent task agents and template evolution
sessions. The system must stay robust under app restarts, cross-device sync,
and bursty task updates while remaining testable and easy to evolve.

## Decision

1. Keep two persistence domains:
   - Journal domain (`db.sqlite`) for task/checklist source-of-truth
   - Agent domain (`agent.sqlite`) for agent identity/state/messages/reports,
     template versions, and wake runs
2. Execute task agents through a single orchestration path:
   - `WakeOrchestrator` manages subscription matching, suppression, throttling,
     and queue/drain execution
   - `TaskAgentWorkflow` owns context assembly, conversation execution, tool
     routing, and sync-aware persistence
3. Build linked-task context from linked task-agent reports:
   - Use `latestTaskAgentReport` from linked task agents
   - Strip `latestSummary` from linked task payloads before prompt submission
4. Keep state-layer wiring provider-first:
   - Riverpod providers assemble orchestrator/workflow/runtime dependencies
   - GetIt access is isolated behind dependency providers where needed

## Architecture Snapshot

```mermaid
flowchart LR
  UI["Task UI"] --> INIT["agentInitializationProvider"]
  INIT --> ORCH["WakeOrchestrator"]
  ORCH --> WF["TaskAgentWorkflow"]
  WF --> CONV["ConversationRepository"]
  CONV --> MODEL["Inference Provider"]
  WF --> EXEC["AgentToolExecutor"]
  EXEC --> JOURNAL["Journal Repository and DB"]
  WF --> SYNC["AgentSyncService"]
  SYNC --> AGENTDB["AgentRepository and agent.sqlite"]
  SYNC --> OUTBOX["Sync Outbox"]
```

## Wake Call Tree

```mermaid
flowchart TD
  A["UpdateNotifications.localUpdateStream"] --> B["WakeOrchestrator._onBatch"]
  B --> C["WakeOrchestrator.processNext"]
  C --> D["WakeOrchestrator._drain"]
  D --> E["WakeOrchestrator._executeJob"]
  E --> F["wakeExecutor callback"]
  F --> G["TaskAgentWorkflow.execute"]
  G --> H["ConversationRepository.sendMessage"]
  H --> I["TaskAgentStrategy.processToolCalls"]
  I --> J["AgentToolExecutor.execute"]
  J --> K["Task handlers"]
  G --> L["AgentSyncService.upsertEntity and upsertLink"]
  L --> M["AgentRepository writes"]
```

## Wake Sequence

```mermaid
sequenceDiagram
  participant T as "Task UI"
  participant N as "UpdateNotifications"
  participant O as "WakeOrchestrator"
  participant W as "TaskAgentWorkflow"
  participant C as "ConversationRepository"
  participant M as "Model Provider"
  participant J as "Journal Repository"
  participant A as "AgentRepository"

  T->>N: "Emit changed tokens"
  N->>O: "_onBatch(tokens)"
  O->>O: "match + suppress + throttle + enqueue"
  O->>O: "processNext and _executeJob"
  O->>W: "wakeExecutor(agentId, runKey, triggers, threadId)"
  W->>C: "sendMessage(system + context + tools)"
  C->>M: "LLM request"
  M-->>C: "tool calls and assistant text"
  C->>J: "tool side-effects via handlers"
  W->>A: "persist report/messages/state"
  W-->>O: "WakeResult"
  O->>A: "update wake_run status"
```

## Consequences

- Task-agent context reflects the latest durable agent output instead of summary
  snapshots that are being phased out.
- Wake behavior is deterministic and easier to reason about because matching,
  suppression, throttle timing, and drain execution are centralized.
- Cross-device behavior remains consistent because all agent writes flow through
  `AgentSyncService`.
- Test harnesses can override runtime wiring at provider boundaries without
  rewiring global runtime setup.

## Related

- `lib/features/agents/README.md`
- PR `#2710`
