# AI Streaming Toggle & UI Smoothness

## Goals

- Reduce UI jank during AI inference by avoiding token-by-token streaming where it isn’t valuable.
- Default to non-streaming responses for task-related prompts; render once when ready.
- Keep chat streaming (task list chat stays token-by-token) for conversational feel while preserving
  responsiveness.

## Context & Prior Work

- Current AI chat pipeline streams tokens through `ChatRepository` → `ChatSessionController` and
  renders incrementally.
- Providers: OpenAI-compatible, Gemini, Ollama, etc., all exposed via `CloudInferenceRepository`.
- UI sluggishness is observed when streaming (scroll/jank on desktop/mobile).
- Config flags already exist and are surfaced in `Settings > Flags`; AI settings live under
  `features/ai` and `ai_chat`.

## Proposed Behavior

- **Default**: Non-streaming requests for task-related AI prompts; UI updates once per response
  unless the streaming flag is enabled.
- **Task list chat modal**: Streaming **always on** (not controlled by the flag) to keep the live
  chat feel.
- **Flag**: `enable_ai_streaming` controls streaming for non-chat/task prompts only; default **false
  **.
- **Per-surface policy**:
  - Task-context prompts (task summaries, checklist updates, label suggestions, TL;DR, etc.):
    non-streaming by default; respect flag to allow streaming if explicitly enabled.
  - AI chat modal (tasks list chat): always streaming.

## Workstreams

1) **Config & UX**
  - Add `enable_ai_streaming` flag (init + flags page + l10n) that governs non-chat/task prompts
    only.
  - Copy: “Stream AI responses for task actions. Turn off to buffer responses and keep the UI
    smoother.”

2) **Runtime Wiring**
  - Thread a `streamResponse`/`stream` boolean through AI entry points:
    - Task-related AI flows (checklist updates, label assignment, task TL;DR, etc.): non-streaming
      by default; if flag on, allow streaming.
    - Chat modal: streaming on (current behavior).
  - Ensure thinking/reasoning handling still works (hidden reasoning stays hidden) in both modes.

3) **UI/State Handling**
  - Non-streaming: show a single loading state/spinner, then render the full response.
  - Streaming (chat): retain typing indicator and chunked updates.
  - Guard: truncate/size limits remain enforced (ChatStreamUtils).

4) **Instrumentation & Perf**
  - Add lightweight timing logs around inference (queued/start/done) to compare streaming vs
    buffered.
  - Consider rate-limiting parallel AI calls if multiple prompts fire.

5) **Testing**
  - Unit: Task flows honor the flag; non-streaming path concatenates content and processes tool
    calls; streaming path still works when flag enabled.
  - Widget: Chat UI still streams; task flows render single-burst responses without flicker; loading
    indicator clears on completion.
  - Integration: Task AI actions complete without streaming by default; chat remains streaming.

## Risks & Mitigations

- Some providers may regress latency without streaming; accept in exchange for UI smoothness (chat
  still streams).
- Tool-call orchestration must still work in non-streaming mode—ensure accumulation isn’t tied to UI
  streaming.
- Longer wait perception in non-streaming mode: mitigate with a clear progress indicator.

## Open Questions

1) Confirm surfaces: which exact task-related prompts should be controlled by the flag (checklist
   updates, label suggestions, task summaries, TL;DR, others)? => all of those
2) Any mobile-only tweaks (e.g., always non-streaming on mobile)? => no
3) Any per-session overrides needed for chat, or is “always streaming” sufficient there? => 
   always on is sufficient

## Rollout

- Implement behind flag, default off for task prompts, on (if agreed) for chat modal.
- Regenerate l10n and run analyzer/tests before shipping.
