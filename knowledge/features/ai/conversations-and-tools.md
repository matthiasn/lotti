---
type: Feature Module
title: Conversations and tool calling
description: The reusable multi-turn loop behind every agent workflow, and the streaming quirks it absorbs.
resource: ../../../lib/features/ai/conversation
tags: [ai, conversation, tool-calling, streaming]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T00:00:00Z }
stale_after: 2027-01-31
sources:
  - id: conversation
    resource: ../../../lib/features/ai/conversation
    title: ConversationRepository and ConversationManager
    last_modified: 2026-07-25
---

`ConversationRepository` and `ConversationManager` provide the reusable
multi-turn loop used by every agent-style tool-calling workflow.

```mermaid
sequenceDiagram
  participant Caller as Agent workflow
  participant Repo as ConversationRepository
  participant Manager as ConversationManager
  participant Inference as InferenceRepositoryInterface
  participant Strategy as ConversationStrategy

  Caller->>Repo: sendMessage(...)
  Repo->>Manager: addUserMessage()
  loop per turn
    Repo->>Inference: generateTextWithMessages(full history)
    Inference-->>Repo: streamed text, tool chunks, usage
    Repo->>Manager: addAssistantMessage()
    Repo->>Strategy: processToolCalls(...)
    Strategy-->>Repo: continue / wait / complete
    Repo->>Manager: addToolResponse()
  end
```

Responsibilities:

- Preserve conversation history.
- Emit conversation events for the UI.
- Accumulate streamed tool calls across chunks.
- Keep Gemini thought signatures between turns.
- Re-enter the loop through a `ConversationStrategy` after tool execution.

`CloudInferenceWrapper` adapts `CloudInferenceRepository` to
`InferenceRepositoryInterface`, so cloud and local providers participate in the
same loop without the loop knowing which is which.

# The details that matter

- **Tool-call arguments are buffered by stable tool-call id or index**, so
  streamed JSON is reassembled safely rather than parsed per chunk.
- **Gemini thought signatures are stored in `ConversationManager` and replayed on
  later turns.** Dropping them breaks Gemini's reasoning continuity across a
  tool-call round trip.
- **Gemini-style multi-call chunks arriving without stable ids** get
  provider-specific handling in the repository.

The strategy layer is what makes the loop reusable: `TaskAgentStrategy`,
`ProjectAgentStrategy`, `EventAgentStrategy` and `EvolutionStrategy` each decide
which tools short-circuit locally, which are deferred as proposals, and when the
conversation is complete. See [task agents](../agents/task-agents.md) for the
richest example.
