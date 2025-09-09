# Gemini Native Client — Session Status (Streaming + Thinking)

Date: 2025-09-08
Owner: AI Assistant (handoff summary)
Scope: Current state of the Gemini streaming client, tool calls, and UI thinking presentation. Use this document alongside `2025-09-08_Gemini_API_client.md` when continuing in a new session.

## Goals (unchanged)
- Use the native Gemini API with proper thinkingConfig, streaming, and tool-calls.
- Strict policy: NEVER promote thinking content to visible text.
- Maintain streaming flow; tool-calls must emit as soon as the model requests them.
- Present thinking separately from the answer; user prefers separate “bubbles” for thinking vs. answer (thinking collapsed by default).

## What Works Now
- Streaming requests hit the correct endpoint: `/v1beta/models/{model}:streamGenerateContent`.
- Response parsing copes with chunked JSON + array wrappers (brace-depth scanner).
- Tool-call emission: functionCall parts are surfaced immediately as `toolCalls` in the OpenAI-compatible stream.
- Tool-call args fix: accumulation now replaces when both incoming and existing args are complete JSON objects (prevents `{...}{...}` concatenation errors). This removed the `FormatException` in tool processing.
- Strict thinking: thought parts (`part.thought == true`) are buffered and emitted in a single `<thinking>…</thinking>` block just before first visible text. No promotion of thinking to visible.

## What Is Not Yet Right
- UI still shows multiple thought+answer sections aggregated into a single collapsed reasoning area. The user would like genuinely separate sections (ideally separate bubbles) for each thought/answer segment.
  - Root cause: current chat UI aggregates thought blocks into a single disclosure for a message. Even though the client flushes one `<thinking>` block before visible text, subsequent thought + visible sequences in later phases of the same assistant message get merged.

## Agreed Constraints / Decisions
- Keep streaming. Do not fall back to non-streaming without explicit approval.
- Never promote thinking into visible text. It is acceptable if an assistant bubble only contains thinking.
- Thought/answer should render as distinct units, not merged into a single collapsed disclosure.

## Recommended Next Steps
1) True separation into bubbles (UI/state change)
   - Where: `ChatRepository` / `ChatMessageProcessor`.
   - Approach: Treat each emitted unit from the repo as a segment and append a new assistant message boundary per segment type.
     - When the repo flushes a `<thinking>` block, insert a new assistant message with only thinking content (rendered collapsed).
     - When a visible text delta arrives after thinking, close the prior message (if any) and emit a fresh assistant message for visible content.
     - When a tool-call is emitted, keep current behavior (execute tool) and then continue appending segments to new messages.
   - Acceptance: A transcript shows distinct collapsed thinking “bubbles” interleaved with normal assistant bubbles.

2) Keep parser minimal and strict
   - Retain the brace-depth scanner to handle chunked JSON / SSE frames.
   - Only hide parts where `part.thought == true`; never promote thoughts.

3) Logging
   - Keep concise logging (`status`, first few raw chunks, and notes: thinking flush, text delta, tool call).
   - Disable verbose logs after verification.

## Implementation Notes
- Client code (current)
  - File: `lib/features/ai/repository/gemini_inference_repository.dart`
  - Emits:
    - single `<thinking>` block (before first visible text),
    - visible text deltas,
    - toolCalls when functionCall appears.
  - Strict: never changes thought → answer.

- Tool args fix (current)
  - File: `lib/features/ai_chat/repository/chat_message_processor.dart`
  - Function: `accumulateToolCalls`
  - If both existing and incoming `arguments` are complete JSON objects, we replace the buffer with the latest; otherwise we append (for true deltas). This prevents concatenated JSON like `{...}{...}`.

- UI thinking split (code added, but still renders within one bubble)
  - Files:
    - `lib/features/ai_chat/ui/widgets/thinking_parser.dart` → `splitThinkingSegments` returns an ordered list of `ThinkingSegment` (isThinking + text).
    - `lib/features/ai_chat/ui/widgets/chat_interface.dart` → renders segments as individual sections within a single assistant message. To meet the user’s request, we must move this segmentation up a layer and create discrete assistant messages per segment.

## Proposed Work Items (next PR)
- [ ] Convert “segments per message” into “messages per segment”
  - Update `ChatRepository.sendMessage` to:
    - Buffer incoming repo deltas into segment units (thought vs. visible),
    - Append a new Assistant message per segment to the session,
    - Keep tool calls as now.
  - Ensure message timestamps/order are preserved; do not impact retry/error handlers.

- [ ] Parser hardening (small)
  - Keep brace-depth parser (works with array wrappers and SSE lines).
  - Add a guard to ignore duplicate identical functionCall{args} for same id.

- [ ] Logging cleanup
  - Remove raw chunk previews when stable; keep status/tool/thinking flush markers.

## Validation / Acceptance Criteria
- Streaming with Gemini Pro triggers:
  - early thought parts → a collapsed “thinking” bubble,
  - functionCall → tool executed; subsequent assistant messages reflect tool results,
  - visible text → separate assistant bubbles,
  - never any promotion of thought text to visible content.
- No `FormatException` from tool-call arg parsing.
- Transcript visually alternates thinking (collapsed) and answer (visible) as distinct bubbles in the correct order.

## Risks / Unknowns
- Some providers stream only thought parts for long stretches. The strict “no promotion” policy will show only collapsed reasoning bubbles until visible appears (acceptable per user).
- If a provider interleaves multiple thought blocks before any visible text, UX will show multiple collapsed bubbles back-to-back (acceptable per user).

## Quick Checklist
- [x] Streaming working
- [x] Tool-call args fix (no concatenated JSON)
- [ ] Separate bubbles for each segment (thinking vs. visible)
- [ ] Minimal logs after stabilization

---

If you pick this up in a new session, start with the “Proposed Work Items” to implement true bubble separation in `ChatRepository` and validate the thought/answer cadence end-to-end with Gemini Pro.

