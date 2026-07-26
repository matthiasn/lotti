# Completion celebration

The flourish the app plays when something is finished — a task closed, a habit
completed, a checklist item checked: a soft glow bloom, a particle burst, an
optional anchor pop, and a haptic.

The particle style varies by content type — sparks, confetti, bubbles — but the
choreography around it is shared, and each variant is tunable through a
playground.

Visual beats respect the user's animation switches and system reduce-motion. Those
switches never silence the haptic — but a separate haptics preference does, and
consumers honour it by passing `onCelebrate: null`.

## How it works

The single-timeline choreography, the painter-only variant boundary, and the
gating rules are documented in the knowledge bundle:

**→ [knowledge/features/design_system/celebration.md](../../../../../knowledge/features/design_system/celebration.md)**
