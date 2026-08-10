# Reusable Chat Interface — Requirements (Phase 4)

- Status: First goal-chat slice shipped 2026-08-11. The shared component now
  projects the newest fifty durable user/reply rows, retains per-agent drafts,
  sends through a `userMessage` wake, renders whole-turn waiting and inline
  retry, and lives as a pushed phone page / desktop peer pane. Voice,
  compound-cursor paging, search, inline nudge cards, epoch expansion and the
  evolution-chat migration remain open requirements below.
- Consumers, in adoption order: **goal chat** (new), **evolution chat**
  (migrates), future eval-review / day-agent surfaces.
- Grounding: today the only real chat is `EvolutionChatPage`
  (in-memory messages, session-bound); the durable agent log is rendered
  only by the read-only `AgentConversationLog`. No code bridges the two —
  that bridge is this component.

Requirements are numbered REQ-NN; "must" is normative.

## 1. Purpose & scope

- REQ-01 The component renders an **ongoing conversation with a durable
  agent**: scrollable history, composer, voice input, inline rich cards.
  It must be feature-agnostic — no goal- or evolution-specific types in
  its core API.
- REQ-02 One conversation = one agent identity (+ optional thread scope).
  Multi-agent inboxes are out of scope.

## 2. History model — projection, not session

- REQ-03 The visible history must be a **persisted projection over the
  durable agent log** (`AgentMessageEntity`), not an in-memory session:
  closing and reopening the chat resumes exactly where it left off, on
  any device, because the entities sync.
- REQ-04 The projection must be **decoupled from model context** (the
  user's core requirement): what the user scrolls is not what the model
  is prompted with. Compaction/epoch folding (ADR 0057) must never remove
  anything from the visible history.
- REQ-05 Projection whitelist, supplied per consumer as a pure function
  over entity kinds/metadata: user messages; agent replies (which are
  `reply_to_user` **tool calls**, not a new message kind — no schema
  change); consumer-registered inline entities (goal chat: `goalNudge`
  ads with status badges, forever); sparse localized lifecycle markers.
  Hidden by default: thoughts, observations, tool results, summaries,
  internal system turns.

## 3. Message taxonomy & card registry

- REQ-06 Renderers are registered per message/entity kind (card
  registry). Unknown kinds must degrade to a **text fallback** rendering
  of their payload — a ten-year-old history must never render a blank
  bubble because a kind was retired.
- REQ-07 Cards must be reproducible from synced entities alone (no
  device-local state); media-bearing cards keep the gradient-fallback +
  file-watcher pattern for late-arriving bytes.

## 4. Composer

- REQ-08 Text composer with send; disabled-with-reason while the agent's
  turn is in flight. Draft text survives navigation away and back.
- REQ-09 Sending must append a durable user message and trigger a
  `WakeReason.userMessage` wake (throttle-bypassing, like
  `transcriptionComplete`) — the chat does not own an inference loop.

## 5. Voice

- REQ-10 Voice input reuses the shared toolkit (promote the evolution
  widgets into `lib/features/ai_chat`: `AgentMessageInput`,
  `AgentVoiceControls`, `AgentTranscriptionProgress`): record → chunked
  transcription with partial transcript streaming into the field; mic
  fills the composer, **never auto-sends**.
- REQ-11 TTS of agent replies is optional and flag-gated
  (`TtsPlaybackController.speak`). **Known gap, must be resolved before
  TTS ships in chat: there is no TTS↔recorder barge-in interlock** —
  starting the mic must stop playback, and playback must refuse to start
  while recording.

## 6. Turn lifecycle & streaming

- REQ-12 v1 is **await-whole-turn** (evolution-chat parity): a waiting
  indicator derives from the wake-run status, not from a socket.
- REQ-13 The API must leave room for token streaming later (message
  models carry a `pending/complete` state), but streaming ships only
  behind `enableAiStreamingFlag` once traced end-to-end.
- REQ-14 A failed turn must surface as a retryable error bubble carrying
  the wake-run error class — never a silently dropped message.

## 7. Pagination & scale

- REQ-15 Reverse list, compound-cursor pagination (~50/page) over the
  lexicographic pair `(createdAt, stableEntityId)` — a bare timestamp
  cursor skips or repeats messages that share a createdAt — with lazy
  payload hydration. Must stay responsive on a **ten-year history**
  (tens of thousands of rows): no full-log reads on open (ADR 0057's
  bounded-read invariant applies to the UI too).
- REQ-16 Epoch summaries render as collapsible dividers ("2027 Q3 —
  fold"); expanding pages the raw span beneath, which is retained per
  ADR 0057's keep-everything default.
- REQ-17 Extract `StickToBottomChatList` from the evolution chat as the
  shared scroll substrate (two consumers = legitimate reuse): pinned to
  bottom on new content only when already at bottom; unread affordance
  otherwise.

## 8. Search

- REQ-18 In-conversation text search over the projection (entity-backed,
  so it works across devices); results navigate the paged list. Semantic
  search stays on the agent side (`search_memory`) — the UI must be able
  to render "the agent searched its memory" as a lifecycle marker.

## 9. Accessibility

- REQ-19 Every bubble/card exposes semantics (role, author, time,
  content; images use the ad's `altText`). Dynamic type respected;
  reduced-motion honored (no auto-scroll animations); all interactive
  elements ≥44 px; focus order follows visual order.

## 10. Design tokens & theming

- REQ-20 All visual values from design-system tokens
  (`tokens.spacing.*`, `tokens.typography.styles.*`); zero hard-coded
  spacing/font values. Theme-reactive without rebuild-flash; background
  refresh must never flash established history (stale-while-revalidate).

## 11. Localization

- REQ-21 All static chrome (composer hints, lifecycle markers, error
  bubbles, rating strip labels) localized in **every** catalog per the
  localization convention; informal register (Romanian exception).
  Agent-generated content is data, not localized.

## 12. Persistence & sync

- REQ-22 Rendering state (collapsed epochs, drafts) is device-local;
  everything content-bearing comes from synced entities. The component
  must tolerate out-of-order entity arrival (vector-clock world) by
  ordering on `createdAt` + stable tiebreak, and re-sorting on late
  arrivals without scroll jumps.

## 13. Consumer-specific hooks (goal chat)

- REQ-23 Inline ad cards with status badge and rating strip; tapping an
  ad's rating prompt writes the nudge rating (ADR 0055 Decision 7);
  entry via banner tap deep-links (`bottomNavSafeNavigatorOf` push +
  beamer deep link, evolution precedent).
- REQ-24 The goal chat header must always be able to show the current
  goal statement (spec head read) — "what is my goal right now" never
  requires scrolling or inference.

## 14. Migration plan

- REQ-25 Phase 1: build the component; goal chat is the first consumer.
  Phase 2: evolution chat migrates — its GenUI surface variant becomes a
  registered card kind; its in-memory model is replaced by the projection
  (its durable session entities already exist). Phase 3: retire
  `EvolutionChatMessage` and the bespoke list. During migration, **no
  dependencies from the new component onto evolution-chat internals**
  (repo rule: new code never depends on code slated for replacement).

## 15. Non-goals (v1)

- Token-level streaming UI (flag-gated later; REQ-13).
- TTS barge-in (blocked on the interlock; REQ-11).
- Multi-agent conversation, group threads, message editing/deletion
  (append-only log), read receipts.
- Push-notification entry points (ADR 0055: banner-only channel).
