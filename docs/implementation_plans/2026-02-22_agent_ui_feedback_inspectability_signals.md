# Implementation Plan: Enhancing UI Feedback, Inspectability, and Signal Orchestration

## Context

The foundational agentic layer is in place (PRs #2683–#2690), providing a Drift-based agent database, WakeOrchestrator with deterministic run keys, AgentToolExecutor with audit logging, and a basic UI. Three gaps remain:

1. **No running-state feedback** — `AgentRunStatus` enum exists but is never exposed to the UI. Users cannot tell if an agent is actively running.
2. **Limited inspectability** — The activity log shows message kind badges and timestamps, but tool call details (arguments, results) and LLM conversation turns are not viewable.
3. **Lost concurrent signals** — If a signal arrives while the agent is already running, the `WakeQueue.mergeTokens` coalesces it into the current queued job, but if no job is queued (the agent is mid-execution with an empty queue), the signal is effectively lost because the drain loop has already passed.

---

## Part 1: UI Layout & Running-State Feedback

### 1.1 Expose running state via a Riverpod provider

Add a `StreamController` inside `WakeRunner` that emits events when agents start/stop running. Create `agentIsRunningProvider` backed by this stream.

### 1.2 Task page agent chip — spinner + spacer

Move agent chip outside Wrap for right-alignment. Show spinner when agent is running.

### 1.3 Agent detail page — running spinner

Add running indicator in app bar next to lifecycle badge.

### 1.4 Localization

Add labels to all ARB files.

---

## Part 2: Inspectability Enhancements

### 2.1 Persist tool call details

Modify `_recordMessage` in `AgentToolExecutor` to persist tool arguments and output as payloads.

### 2.2 Persist user message in workflow

Persist the assembled user message as an `agentMessage` before sending to LLM.

### 2.3 Enhanced activity log UI

Improve expansion content for action/toolResult cards with formatted content.

### 2.4 Thread-based conversation grouping

Add tabbed view (Activity / Conversations) on agent detail page. Create `AgentConversationLog` widget with thread-grouped display.

---

## Part 3: Signal Orchestration (Concurrency Handling)

### 3.1 Post-execution re-drain

After a job completes, schedule a delayed `processNext()` (30s) to pick up deferred signals. Use a single `Timer` field to deduplicate.

### 3.2 Cleanup

Add timer cancellation to `stop()` method.

---

## Files to modify

| File | Changes |
|------|---------|
| `lib/features/agents/wake/wake_runner.dart` | Add `StreamController`, `runningAgentIds` stream, `dispose()` |
| `lib/features/agents/wake/wake_orchestrator.dart` | Add `_pendingDrainTimer`, `_schedulePostExecutionDrain()`, update `stop()` |
| `lib/features/agents/state/agent_providers.dart` | Add `agentIsRunningProvider` |
| `lib/features/agents/tools/agent_tool_executor.dart` | Add payload persistence to `_recordMessage`, update call sites |
| `lib/features/agents/workflow/task_agent_workflow.dart` | Persist user message as agentMessage |
| `lib/features/tasks/ui/header/task_header_meta_card.dart` | Spinner on chip when running |
| `lib/features/agents/ui/agent_detail_page.dart` | Add running spinner in app bar, refactor to tabbed layout |
| `lib/features/agents/ui/agent_activity_log.dart` | Enhance expansion content for action/toolResult cards |
| `lib/features/agents/ui/agent_conversation_log.dart` | **NEW** — Thread-grouped conversation view |
| `lib/l10n/app_*.arb` | New labels |
| Tests for all modified files | |

## Implementation order

1. WakeRunner stream + provider
2. Task page layout + spinner
3. Agent detail page spinner
4. Tool executor payload persistence
5. User message persistence in workflow
6. Activity log UI enhancements
7. Conversation log widget
8. WakeOrchestrator post-execution drain
9. Localization
10. Tests
