# Character / Dance — Architecture Decision Records

A **self-contained** ADR series for the `character` feature (the chibi-cat rig,
the dance-to-track demo, the camera director, and the choreography encoding).

This series is **deliberately separate** from the repository-wide `docs/adr/`
index and is numbered from `0001` with a `CHAR-` prefix. The character/dance
subsystem is expected to be extracted into its own package; keeping its decision
records beside the code means they travel with it. **Do not merge this series into
the Lotti ADR index, and do not renumber it to continue that sequence.**

## File naming

- `CHAR-NNNN-short-title.md` — `NNNN` zero-padded, increasing within *this*
  series only.

## Template

Each ADR contains: `Status`, `Date`, `Context`, `Decision`, `Consequences`,
`Related` (optional).

## Index

- [`CHAR-0001-dance-choreography-encoding-and-move-library.md`](./CHAR-0001-dance-choreography-encoding-and-move-library.md)
  — **Accepted/implemented.** How dance dynamics are encoded (the Laban-Effort
  layer over keyframed accents), the move-library/notation-as-score model, and
  which Afrobeats moves the catalog encodes (and which were dropped, and why).
  Its **Implementation outcome** section records the as-built reality: all six
  moves shipped and panel-certified ≥9.0/10, authored as separate hand-keyed
  clips (a deliberate divergence from the planned `AfrobeatsMove`-compilation),
  plus the reusable engine toolkit that grind produced (`danceHeadBobScale`,
  `supportFootWorldAnchor`, `easeOutBack` IK overshoot, the forearm sleeve band)
  and the keyframe-sampling constraint that shaped it.

## Related research

Background fan-outs preserved under [`../research/`](../research/):

- `2026-06-27-movement-notation-synthesis.md` — movement-notation, Laban Effort,
  animation-principle, and polyrhythm synthesis.
- `2026-06-28-afrobeats-dance-moves.md` — per-move, count-accurate keying notes
  with side-on feasibility flags and sources.
