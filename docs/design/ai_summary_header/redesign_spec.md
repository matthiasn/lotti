# AI summary card header — redesign spec (v1, for panel review)

Scope: the header of the AI summary card on a task (`TldrHeader` +
`TldrBody`). It carries the agent's **TL;DR**, the **agent status/control**
cluster, and a new **Supertonic TTS playback** control. Built only from
`tokens.colors.aiCard.*`, `tokens.spacing.*`, `tokens.typography.*`,
`tokens.radii.*`.

## Layout

Single header row that wraps to a second run on narrow cards; body below.

    ┌───────────────────────────────────────────────────────────────┐
    │  ✦  AI summary                    [ Thinking… ◷ ]  ( ▶ )   ⌄   │
    │     Task Laura · inspect                                        │
    ├───────────────────────────────────────────────────────────────┤
    │  TL;DR markdown — comfortable measure, 1.55 line height         │
    └───────────────────────────────────────────────────────────────┘

- **Identity (leading):** 24×24 rounded sparkle badge (accentSoft fill,
  accent glyph) + two stacked lines — "AI summary" (subtitle2, w600,
  titleText) and the agent name (caption, metaText, underlined, tappable →
  agent internals). The whole name row is a ≥44px-tall hit target.
- **Agent status/control (trailing-left), mutually exclusive:**
  - idle, no wake → single "Run now" icon button.
  - running → a **labelled "Thinking…" chip** with a small indeterminate ring
    (accent). Deliberately a labelled chip, not a bare spinner, so it reads as
    *agent activity* and never looks like audio loading.
  - wake scheduled → Run-now icon + countdown pill (tabular figures) + cancel
    icon.
- **Playback (the focal control, trailing-right):** a filled **circular
  play/stop button**, 44×44 hit target / 36px visible circle, accent fill with
  an onAccent-contrast glyph:
  - idle → play triangle.
  - preparing (downloading model / synthesizing) → indeterminate ring *around*
    the circle ("Preparing audio"); distinct in size/placement from the agent
    "Thinking" ring.
  - playing → morphs to a **square** stop glyph with a thin **determinate
    progress arc** around the circle (position/duration).
  - disabled (no TL;DR or engine unavailable) → reduced opacity, non-actionable,
    tooltip explains why.
- **Expand:** "Read more / Show less" pill (existing pattern).

## Spacing & type
- Outer padding from `tokens.spacing` (step4 horizontal, step3 vertical); the
  ad-hoc `EdgeInsets.fromLTRB(14,14,8,10)` and magic `SizedBox`es are removed.
- Identity ↔ cluster via space-between; cluster item gap `tokens.spacing.step2`.
- All text via `tokens.typography` (subtitle2, caption). No raw fontSize/weight.

## Accessibility targets
- Every interactive control ≥44×44 hit target (today's icon buttons are 28×28).
- Shape-not-color: play = triangle, stop = square, plus semantic labels — never
  color alone (deuteranopia-safe).
- Semantics: play button `button: true`, label `Play summary` / `Stop` /
  `Preparing audio`, `enabled` reflects availability; live-region announce on
  state change.
- Reduced motion: rings render static when `MediaQuery.disableAnimations`.
- Dynamic Type: token styles scale; the row wraps rather than truncates.
- Contrast: verify accent-on-aiCard.background and accent-on-accentSoft meet
  WCAG 2.2 AA (≥4.5:1 text, ≥3:1 UI) in light + dark; fix at the token if short.

## Agent-activity vs audio distinction
The agent "Thinking…" chip (labelled, left of the focal control) and the audio
play/stop circle (filled, right) are visually and semantically separate; both
may show at once without ambiguity.
