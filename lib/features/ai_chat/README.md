# AI chat

AI chat lets the user ask questions about their own work and get an answer
grounded in what actually happened — "what did I finish last week?", "what
patterns show up in this area?", "where did the time really go?".

It is a conversation, not an agent: it answers when asked and does not act on its
own.

## What it does for the user

- **Answers questions about real history.** The assistant can pull summaries of
  the tasks worked on in a date range, rather than guessing from a pile of raw
  text.
- **Lets the user choose the model.** Each chat session has an explicitly chosen
  model — nothing is picked silently.
- **Streams the answer.** Text appears as it is generated, and the UI stays
  responsive even while the assistant is assembling a data request behind the
  scenes.
- **Takes voice input.** A question can be spoken instead of typed, transcribed
  in one batch pass.
- **Keeps sessions light.** Recent sessions are available for the current run of
  the app, and creating or discarding one costs nothing.

Chat history is **not** stored permanently yet — sessions live for the app's
lifetime.

## What it owns

Session and message state for the chat UI; per-session model selection; streaming
assistant output including tool-calling turns; the task-summary retrieval tool;
and batch transcription for chat input.

It does not own provider configuration or routing ([ai](../ai/README.md)), agent
wake cycles or memory ([agents](../agents/README.md)), or durable transcript
persistence.

## Where the code lives

```text
lib/features/ai_chat/
├── models/ · repository/ · services/
└── ui/
```

## How it works

The two controllers, the in-memory session model, the turn flow with concurrent
tool accumulation, and the single batched retrieval tool are documented in the
knowledge bundle:

**→ [knowledge/features/ai_chat.md](../../../knowledge/features/ai_chat.md)**
