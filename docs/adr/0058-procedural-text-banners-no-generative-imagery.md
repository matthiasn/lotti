# ADR 0058: Procedural Text Banners — No Generative Imagery

- Status: Proposed
- Date: 2026-08-08

## Context

ADR 0055/0056 designed the goal-ad channel around generated images (Nano
Banana Pro briefs, a verification pass, an extraction of the image
service). The eval harness proved the pipeline end to end the same day —
briefs stayed leakage-free through four creative escalations, and the
renders were good.

And that is exactly why this ADR exists: the proof-of-concept made the
cost visible. Generating a bespoke image for every off-track moment of
every goal of every user is real energy and water spent on decoration —
the *coaching* is the text; the image was garnish. The user's framing
(2026-08-08): be responsible, use AI only where it is the point, and make
"my fitness agent costs ~100 Wh per month" an answerable question with an
answer worth being proud of.

## Decision

1. **The goal ad is a designed text banner, rendered by Flutter.** The
   model authors the copy — `headline`, optional `cta`/`tagline`, `tone`
   (the snark/roast register of ADR 0055 stands; text is now where all
   the personality lives) — and *selects* presentation from a fixed,
   code-owned catalog: an `animationPreset` (e.g. typewriter, pulse,
   wave, marquee, glitch) and an `accentPreset` (color/gradient/shader
   background treatments from the design system). Cheesy is allowed;
   cheesy is free.

2. **No generative imagery anywhere in the channel.** `create_goal_ad`
   carries no scene brief; no image provider is called; the Nano Banana
   integration, the visual-brief composition, and the brief-match
   verification pass are removed, not flag-gated — unused code is not
   kept (repo rule). The eval image stage that validated the old pipeline
   is retired with it; its artifacts remain in the session record.

3. **Presets are code, subject to the design system.** Animation and
   accent presets are enum values whose implementations live with the
   banner widgets, use design-system tokens, respect reduced-motion, and
   degrade gracefully where fragment shaders are unavailable or unsafe
   (shaders are disabled on Linux — the virtio-GPU freeze precedent), in
   which case a preset falls back to its plain-animation form.

4. **Energy is a first-class, per-agent answer.** Melious reports
   `energyKwh` (and CO2/water) per call, and every goal-agent call is
   attributed via `AiConsumptionEvent.agentId`. Eval reports and the
   per-goal detail surface show energy alongside credits — Wh per
   goal-month as an observed estimate. Minimizing AI use is what makes
   that number small enough to be worth telling.

5. **What survives from ADRs 0055/0056 unchanged**: the entity-based
   lifecycle with rating history, wear-out detection and zero-cost
   re-runs (a re-run is now literally free — no image ever needed
   regenerating either); visible-time tracking; dismissal cool-downs;
   staleness as a contract; and the need-to-know discipline — the
   leakage lint and evals now police the banner *copy* fields, which are
   still the only model text that reaches any surface verbatim.

## Consequences

- ADR 0055 Decision 8 (headline/CTA rendered into a generated image) and
  ADR 0056's image-request boundary are superseded by this ADR; 0056's
  *principle* — third parties receive only a typed, leakage-checked
  allowlist — is retained and applies to any future outbound payload.
- The ad pipeline loses its only non-deterministic, non-free stage:
  banner creation becomes instant, offline-capable, and costless, so ad
  freshness never competes with a budget and cold-start personalization
  (ADR 0055) iterates faster.
- Per-goal cost collapses to Phase B text inference alone (~0.0024
  credits/wake observed), making the energy figure both small and
  honest.
- If generative imagery is ever revisited (e.g. a user explicitly opts
  into it), ADR 0056 is the boundary it must re-enter through.

## Related

- [ADR 0054: Deterministic-First Two-Tier Wakes](./0054-deterministic-first-two-tier-wakes.md)
- [ADR 0055: The Banner-Nudge Attention Channel](./0055-banner-nudge-attention-channel.md) — Decision 8 superseded; the rest stands
- [ADR 0056: The Need-to-Know Visual Brief Boundary](./0056-need-to-know-visual-brief-boundary.md) — dormant; the principle survives as the outbound-payload rule
