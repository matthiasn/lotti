# ADR 0003: Task Agent Linked-Task Context Contract

- Status: Accepted
- Date: 2026-02-27

## Context

Task-agent wake prompts need linked-task context, but linked task summaries are
being phased out. The wake path must consume linked task-agent reports instead
and remain resilient when linked context/report resolution fails.

## Decision

1. Build linked-task context on the task-agent wake path via
   `TaskAgentWorkflow._buildLinkedTasksContextJson` (forked shape from
   `AiInputRepository.buildLinkedTasksJson`).
2. Source linked task lists from:
   - `AiInputRepository.buildLinkedFromContext(taskId)`
   - `AiInputRepository.buildLinkedToContext(taskId)`
3. Remove `latestSummary` from all linked-task rows before prompt submission.
4. Inject task-agent report fields when available:
   - `taskAgentId`
   - `latestTaskAgentReport`
   - `latestTaskAgentReportCreatedAt`
5. Resolve linked task agent by `agent_task` links sorted by:
   - primary: `createdAt` descending
   - secondary: `link.id` ascending (deterministic tie-breaker)
6. Keep failures non-fatal:
   - If linked-task context building fails, return `'{}'`.
   - If report lookup for one linked task fails, skip injection for that task.

## Context Build Sequence

```mermaid
sequenceDiagram
  participant W as "TaskAgentWorkflow"
  participant AI as "AiInputRepository"
  participant AR as "AgentRepository"

  W->>AI: "buildLinkedFromContext(taskId)"
  W->>AI: "buildLinkedToContext(taskId)"
  W->>W: "remove latestSummary from all rows"
  loop "each linked task id"
    W->>AR: "getLinksTo(taskId, type: agent_task)"
    W->>AR: "getLatestReport(link.fromId, current)"
    AR-->>W: "report or null"
  end
  W->>W: "inject taskAgentId + latestTaskAgentReport fields"
  W-->>W: "linked JSON for wake prompt"
```

## Data Shape

```mermaid
flowchart LR
  A["linked_from[] row"] --> C["remove latestSummary"]
  B["linked_to[] row"] --> C
  C --> D["add taskAgentId (if report found)"]
  D --> E["add latestTaskAgentReport (if report found)"]
  E --> F["add latestTaskAgentReportCreatedAt (if report found)"]
```

## Consequences

- Task-agent prompts no longer rely on task summaries.
- Linked-task report selection is deterministic under equal link timestamps.
- Linked-task context failures cannot abort wake setup.

## Related

- `lib/features/agents/workflow/task_agent_workflow.dart`
- `lib/features/ai/repository/ai_input_repository.dart`
