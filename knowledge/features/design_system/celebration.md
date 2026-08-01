---
type: Feature Module
title: Completion celebration
description: "One shared choreography with a swappable particle painter, driven by a single timeline so beats cascade rather than firing together."
resource: ../../../lib/features/design_system/components/celebration
tags: [design-system, motion, celebration, haptics]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:45:00Z }
stale_after: 2027-02-08
sources:
  - id: src
    resource: ../../../lib/features/design_system/components/celebration
    title: Completion celebration source
    last_modified: 2026-08-01
---

What the celebration *is* belongs to
[its README](../../../lib/features/design_system/components/celebration/README.md).
This concept covers how it is built.

# One timeline, not four animations

Glow bloom, particle burst, anchor pop and haptic are driven from a **single
timeline** rather than started independently. That is what makes the beats
cascade instead of firing on the same frame — and it is why a consumer cannot
get the sequencing subtly wrong by wiring the pieces itself.

# The variant is only the painter

The particle field is selectable per content type, but **everything around it is
shared**: switching style swaps the painter and nothing else, so timing, haptics
and the glow behave identically across content types.

That boundary is the reason a new content type is cheap. Adding one means
supplying a painter, not re-deriving a choreography — and it means a timing fix
lands everywhere at once instead of in whichever variants someone remembered.

Each variant is deeply tunable: shape constants a painter used to hard-code —
particle count, size, reach, gravity, twinkle, sway, spin, swell — are exposed as
sliders in a per-variant playground and persisted globally.

Each variant is deeply tunable: shape constants a painter used to hard-code —
particle count, size, reach, gravity, twinkle, sway, spin, swell — are exposed as
sliders in a per-variant playground and persisted globally.

# Gating

**Visual beats are gated** on the user's celebration switches
(*Settings → Advanced → Animations*) and on system reduce-motion.

**Those gates do not suppress haptics** — turning animations off leaves the
feedback. But haptics are not unconditional either: there is a **separate**
haptics preference, and consumers honour it by passing `onCelebrate: null` when
it is off (`checklist_card.dart`, `desktop_task_header_meta.dart`). So the
accurate rule is *animation switches never silence haptics; the haptics switch
does.*

Every beat fires only on the **not-done → done** transition, so re-rendering a
completed item never re-celebrates it.

See [checklists](../tasks/checklists.md) for the clearest consumer, including why
the burst is fired imperatively from the tap rather than from the widget edge.
