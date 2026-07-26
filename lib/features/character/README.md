# Character

A 2D animated character rendered from a rig — a skeleton plus a face — driven by
procedural motion cycles rather than pre-rendered frames.

**This is a proof of concept**, not a shipping surface.

## What it does

- **Animates from data.** Walk, run, sit and jump cycles are computed, not
  authored frame by frame.
- **Has an expressive face.** Smile, frown, surprise and blink.
- **Renders identically everywhere.** The same clip at the same time always
  produces the same frame, so a live view and an offline film-strip render match
  exactly.

## Where the code lives

```text
lib/features/character/
```

The full design — including the offline AI-assisted SVG-to-rig pipeline and a
low-end runtime — lives in
[docs/implementation_plans/](../../../docs/implementation_plans).

## How it works

The determinism property and why it is load-bearing are documented in the
knowledge bundle:

**→ [knowledge/features/character.md](../../../knowledge/features/character.md)**
