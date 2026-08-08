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

7. **Tap-through asks for a rating; top-rated ads are reusable.** Opening an ad's conversation
   presents a lightweight rating prompt (the tap already proved engagement — that is the moment
   to ask). Ratings are appended to the `goalNudge` row as a history (`{rating, ratedAt}` per
   run), which turns the ad archive into a labeled library of what actually lands with this
   user. Two uses:
   the agent's wake facts summarize top-/bottom-rated briefs so future `create_goal_ad` calls
   steer toward proven concepts, and a sufficiently high-rated ad may be **re-run as-is** —
   re-activating the existing entity and its already-generated image at zero image-generation
   cost — instead of generating a new one. Reuse is a first-class lifecycle move
   (`active → retired → active` re-entry with a fresh `staleAt`), not a copy; the row keeps its
   full rating and display history. **Every run is rated**: a re-run prompts for a fresh rating
   on its next tap-through — the rating trajectory is what detects wear-out (an ad that slides
   from 5 to 2 across re-runs retires from the library; a single frozen rating would hide
   that). Skipping a prompt is always allowed; within the same run the skipped prompt is not
   nagged again, but the next re-run asks anew.
   Alongside the explicit rating, **exposure is measured implicitly**: the banner widget reports
   visibility sessions, accumulated onto the row as `totalVisibleMs`, `impressionCount`,
   `firstShownAt`/`lastShownAt` (LWW-merged per device, summed for display). An ad dismissed
   after 40 minutes of accumulated visibility failed differently from one dismissed in two
   seconds — visible-time-to-action is the denominator every effectiveness ratio needs, and it
   also weights the rating library (a five-star ad seen once means less than a four-star ad
   that earned its rating over many impressions).

8. **[Superseded by ADR 0058.]** ~~The ad is a designed banner — headline and CTA render IN the image.~~ The ad is a designed *text* banner rendered procedurally by the app; no image is generated. Original text kept for the record: (Revised same day:
   text-free images read too tame; a real ad has type.) The composed prompt instructs a
   polished advertising-banner layout and passes the model-authored `headline` and optional
   `cta` verbatim as the only sanctioned text — both are leakage-checked tool arguments, so no
   personal data rides along (ADR 0056 holds: the boundary is *which fields* travel, and these
   two carry no user data by construction). All *other* readable text, digits, logos and
   watermarks stay banned. `headline`/`altText` remain stored on the entity regardless, so
   history rendering, semantics labels and any future theming never depend on pixels.

9. **Past ads are part of the conversation history.** Ads render inline (compact card + status
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
  without new instrumentation — the lifecycle timestamps are the instrument, and explicit
  ratings (Decision 7) add a labeled signal on top of the behavioral one.
- The rating library shifts image spend downward over time: the more history a goal accumulates,
  the more often a wake can re-run a proven ad instead of paying for a new generation.
- **Cold-start blandness is expected and acceptable.** A fresh goal agent produces generic
  (if snarky) ads because it knows nothing about this user's taste yet — that is the design,
  not a defect to be prompt-engineered away. Personality comes from the feedback loop
  (per-run ratings, dismissal latency, visible time, recorded tone preferences), which is
  where investment belongs; the prompt only sets the floor.

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
- [ADR 0058: Procedural Text Banners — No Generative Imagery](./0058-procedural-text-banners-no-generative-imagery.md) — supersedes Decision 8
