---
type: Feature Module
title: Completion celebration
description: "One shared choreography with a swappable particle painter, driven by a single timeline so beats cascade rather than firing together."
resource: ../../../lib/features/design_system/components/celebration
tags: [design-system, motion, celebration, haptics]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:45:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: ../../../lib/features/design_system/components/celebration
    title: Completion celebration source
    last_modified: 2026-07-25
---

The flourish the app plays when something is finished — a task closed, a habit
completed, a checklist item checked.

**One shared choreography**: a soft glow bloom plus a particle burst, with an
optional anchor pop and a completion haptic, **driven by a single timeline so the
beats cascade instead of firing on the same frame**.

# The variant is only the painter

The particle field is selectable per content type — sparks for a closed task,
confetti for a habit, bubbles for a checklist item by default — but **everything
around it is shared**. Switching style swaps the painter and nothing else, so
timing, haptics and the glow behave identically across content types.

Each variant is deeply tunable: shape constants a painter used to hard-code —
particle count, size, reach, gravity, twinkle, sway, spin, swell — are exposed as
sliders in a per-variant playground and persisted globally.

# Gating

**Visual beats are gated** on the user's celebration switches
(*Settings → Advanced → Animations*) and on system reduce-motion. **Haptics always
fire** — the switch turns off animations, not feedback.

Every beat fires only on the **not-done → done** transition, so re-rendering a
completed item never re-celebrates it.

See [checklists](../tasks/checklists.md) for the clearest consumer, including why
the burst is fired imperatively from the tap rather than from the widget edge.
