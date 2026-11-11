# ADR 0163: Chat Surfaces Are A2UI v1.0, Drawn by `a2ui_flutter`

- Status: Accepted
- Date: 2026-11-11
- Concepts: [front agent](../../knowledge/features/front_agent.md), [templates, souls and evolution](../../knowledge/features/agents/templates-souls-evolution.md)
- Evaluation: [companion rich UI against Flutter GenUI](../evaluations/2026-11-10_companion_rich_ui_genui.md)

## Context

Two chats draw generated UI. The evolution chat drew cards through the
`genui` package. The companion drew cards and charts from a format of its
own, and before that from a regex over her Markdown, which showed plain
links whenever she worded a list differently.

`genui` is discontinued. pub.dev names `a2ui_flutter` as its replacement,
with `a2ui_core` and `a2ui_agent`. The two cannot be installed together:
`genui` pins `a2ui_core` 0.1, and `a2ui_flutter` needs 0.7.

## Decision

1. **Both chats draw A2UI v1.0 surfaces with `a2ui_flutter`.** `genui` is
   removed. Each chat has a catalog of its own components, built on Lotti's
   design-system widgets; the package's Material basic catalog is not used.
2. **The model composes and references. It never passes data to a
   component.** A component names an entity by id, or a result of a lookup
   the turn made. The app resolves it: a card reads its entity live, and a
   lookup's component is bound (`@path`) to what the app wrote into the
   surface's data model from that lookup. The model reads data through its
   tools, so its words can be about it.
3. **The model asks for UI through a tool call.** The app builds the A2UI
   message. The model does not write A2UI in its text.
4. **A component that cannot be drawn is never substituted, and never
   costs the answer.** The companion drops it, names it in the tool result
   and logs it. The evolution bridge draws nothing and tells the model why.
5. **Cards do not depend on the model remembering a component.** A list of
   task links in the companion's words is drawn as cards when the reply is
   read. Tasks a due lookup found, and lookup components she did not place,
   are appended.
6. **A companion reply is stored as one v1.0 `createSurface` message.** One
   message processor per conversation replays the stored messages. Replies
   stored before this draw her words and what they carried.
7. **Interactions come back as A2UI actions** on the processor's `onAction`:
   the evolution cards' choices, and the companion's quick replies.

## Consequences

- The evolution chat checks a card's data against its schema before drawing.
  A card with required fields missing used to be drawn empty; it is now
  refused, and the model is told which fields.
- The stored reply format follows A2UI. A later protocol version needs a
  reader for v1.0 messages or a migration.
- `a2ui_flutter` is new (0.3.0) and its changelog breaks often. Upgrades
  need care; the catalogs and the bridge are the only code that touches it.
- Point 3 is under review. A voice-first companion wants her prose streamed
  so speech can start early, which a single tool call does not allow.
  `a2ui_agent` parses A2UI from a streamed reply. Changing the transport
  would amend this ADR; points 1, 2 and 4 to 7 do not depend on it.
