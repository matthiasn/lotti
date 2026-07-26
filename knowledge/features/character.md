---
type: Feature Module
title: Character animation
description: "A deterministic pure-Dart 2D skeletal animation engine, where the same clip and time always resolve the same frame."
resource: ../../lib/features/character
tags: [character, animation, skeletal, deterministic]
status: draft
generated: { by: claude-code/opus-5, at: 2026-07-26T04:15:00Z }
stale_after: 2027-03-08
sources:
  - id: src
    resource: ../../lib/features/character
    title: Character animation source
    last_modified: 2026-07-26
---

Programmatic 2D skeletal animation: a rigged character — skeleton plus face —
driven by **procedural, data-driven** motion cycles (walk, run, sit, jump) and an
expressive face (smile, frown, surprise, blink).

**The engine is pure Dart and deterministic**: the same `(clip, time)` always
resolves the same frame, so the live widget and the offline film-strip renderer
produce **identical pixels**.

That determinism is the design's load-bearing property. It is what makes the
animation testable at all — a frame can be rendered offline and compared — and
what lets a preview and the running app agree without sharing a frame clock.

**This is a proof of concept.** The full design, including the offline AI-assisted
SVG → rig pipeline and a low-end `drawAtlas` runtime, lives in the implementation
plan under `docs/implementation_plans/`.
