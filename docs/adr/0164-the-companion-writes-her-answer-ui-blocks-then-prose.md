# ADR 0164: The Companion Writes Her Answer — UI Blocks, Then Prose

- Status: Accepted
- Date: 2026-11-12
- Concepts: [front agent](../../knowledge/features/front_agent.md)
- Supersedes: point 3 of [ADR 0163](0163-chat-surfaces-are-a2ui-drawn-by-a2ui-flutter.md), for the companion

## Context

ADR 0163 had the companion ask for UI through a tool call,
`reply_to_user(message?, components?)`. Two things were wrong with it.

- **Her words had two places.** A model filled `message` and a `Text`
  component with the same sentence, which was then shown twice and spoken
  twice. Each rule for telling the two apart lost words in some other case.
- **A tool call cannot be spoken as it arrives.** A voice-first companion
  wants her prose as a stream, so speech can start on the first sentence.
  Arguments of a tool call are one JSON value.

`a2ui_agent` parses A2UI out of a model's message and offers two formats:
A2UI JSON in a fenced block, and Express notation, where a component is a
call by position. Express is a proposal to the A2UI standard, not yet part
of it; it is the library's default. Live against the three models the
companion runs on (Mistral Large 4, DeepSeek V4.1 Flash, GLM 5.3 Flash; 5
scenarios, 4 runs each), Express with two examples was read in every run.
JSON reached the same only after extra rules about the root and ids.

## Decision

1. **Her answer is the message she writes, not a tool call.** The
   `reply_to_user` tool is gone. A turn ends on `dispatch`, `ask_user`, or
   a message with prose.
2. **UI first, then prose.** Every UI block comes before her words, so the
   screen can be drawn before she speaks.
3. **One channel for words.** Her prose is what is spoken and what the
   conversation keeps. A `Text` component is a label that is shown and not
   spoken. A `caption` is an accessibility label only.
4. **She writes Express.** It is compiled to A2UI v1.0 before anything is
   stored, so what is stored and drawn is the standard (ADR 0163, point 6).
   Express exists only in the prompt and in `front_reply_stream.dart`.
5. **What she may write is a catalog of its own**, flat and without data:
   ids and lookup placements (ADR 0163, point 2). The render catalog stays
   the one that draws stored surfaces.
6. **Nothing she writes wrongly costs the answer.** A block that cannot be
   read and a component that cannot be drawn are left out and logged with
   counts. Only a message without prose is not an answer.
7. **No switch.** There is one way to answer.

## Consequences

- A lookup answer is still two provider calls. The second is told to
  answer, not to dispatch, when the lookup was made for an answer.
- If Express changes or is dropped from the standard, the prompt snippet
  and one parser file change. Stored replies do not.
- The prose is not yet shown or spoken while it streams: the turn is read
  when it ends. Progressive display and per-sentence speech build on this
  transport.
- The evolution chat keeps its tool call. ADR 0163's point 3 still holds
  there.
