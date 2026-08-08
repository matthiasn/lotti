# ADR 0055: The Banner-Nudge Attention Channel

- Status: Proposed
- Date: 2026-08-08

## Context

ADR 0019 and ADR 0023 frame agent attention as **scheduled calendar time, not interruption**: a
fitness agent asks the planner for workout blocks; nothing pushes at the user. Goal agents add a
deliberately different second channel: when the user is off-track, the agent shows a visual "ad"
— potentially humorous, persona-flavored — prominently inside the app. This is persuasion at the
moment the user is already looking, not an interrupt. That departure deserves its own record.

Two facts make the boundary easy to hold today: OS push is off by default behind
`enable_notifications`, and notification-tap deep links are written but never consumed
(`notification_service.dart` initializes without a response callback) — there is no push-to-chat
routing to be tempted by.

## Decision

1. **Banner-only, in-app, never push (v1).** The ad channel renders only inside the app.
   Revisiting push later requires reopening this ADR and building tap routing; the durable
   synced notification inbox would be the substrate.

2. **An ad is data: the `goalNudge` entity.** One append-only row per generated ad; status is
   mutated in place through a typed lifecycle:
   `draft → ready → active → dismissed | retired | expired | superseded | failed` — the *user
   dismisses*, the *agent retires* (goal back on track, habit checked off), the *clock expires*
   (default lifetime 72 h or goal-satisfying completion, whichever first), a newer ad
   *supersedes*, generation/verification *fails*. Each terminal status keeps its timestamp.
   Dismissal is an LWW status write that syncs like any entity — **dismissal is data the agent
   reads** deterministically at its next wake (dismissal counts, time-to-dismiss, cool-down
   state).

3. **Staleness is a contract, not a hope.** `staleAt` bounds how long an ad may claim to be
   current; goal-relevant events pull it forward — checking off the gym habit re-wakes the agent
   (ADR 0054 subscription) whose wake facts then retire the now-stale "go to the gym" ad. A
   wrong banner that lingers is treated as a defect of the contract, not of the model.

4. **Respect mechanics, not budget mechanics.** Dismissing an ad suppresses new ads for that
   goal for 24 h (wake-fact enforced). Near-identical regeneration is prevented by a
   `briefDigest` dedupe key. There are **no spending caps** (cost policy is
   monitoring-per-goal, ADR 0054 Decision 8); these mechanics exist so the channel stays
   respectful, which is what keeps it effective.

5. **Quiet-by-default surfaces.** The banner widget renders nothing when no active ad exists
   (the `KnowledgeNudge` contract). v1 mounts: the Daily OS day page nudge stack and the habits
   tab; multiple active ads render as a manual-swipe carousel with position dots (no
   auto-advance; reduced-motion respected). An app-shell structural band (the demo-banner
   pattern) is documented as an escalation surface and deliberately not built in v1.

6. **Tap opens the conversation; dismissal is explicit.** Tapping the ad opens the goal agent's
   chat (pushed over the bottom nav); a separate 44 px dismiss affordance (and swipe) writes the
   dismissal. The two intents are never conflated on one gesture.

7. **All copy is composited on-device.** The generated image contains no readable text (brief
   contract, ADR 0056); `headline`/`caption` are overlaid by the UI from entity fields. This
   keeps personal/goal wording out of the image provider, makes past ads render correctly in the
   conversation history forever, and keeps text accessible (semantics labels) and theme-aware.

8. **Past ads are part of the conversation history.** Ads render inline (compact card + status
   badge) in the goal chat's timeline projection, permanently — the scrollable history of all
   interactions includes every banner the agent ever ran.

## Consequences

- The product gains a second attention channel with an explicit boundary to the first: claims
  buy *calendar time* through the planner (ADR 0023, future); nudges spend *screen presence*
  inside the app, bounded by staleness, dismissal cool-downs, and quiet-by-default surfaces.
- Because ads are synced entities referencing a `JournalImage`, cross-device display is free;
  the image file may land after the entity on a second device, so banner rendering keeps the
  gradient-fallback + file-watcher repaint pattern.
- Ad effectiveness becomes measurable later (dismissal latency, tap-through, status at expiry)
  without new instrumentation — the lifecycle timestamps are the instrument.

## Non-Goals

- Push notifications, OS notification-tap routing, badges.
- Auto-advancing or animated attention-grabbing carousels.
- Cross-app or web delivery of ads.

## Related

- [ADR 0019: Attention Negotiation Protocol](./0019-attention-negotiation-protocol.md)
- [ADR 0023: Durable Domain Agents and Time Negotiation](./0023-durable-domain-agents-and-time-negotiation.md) — the "attention = calendar time" stance this channel deliberately complements
- [ADR 0053: Goal-Driven Agents — Per-Goal Durable Producers](./0053-goal-driven-agents-per-goal-producers.md)
- [ADR 0054: Deterministic-First Two-Tier Wakes](./0054-deterministic-first-two-tier-wakes.md)
- [ADR 0056: The Need-to-Know Visual Brief Boundary](./0056-need-to-know-visual-brief-boundary.md)
