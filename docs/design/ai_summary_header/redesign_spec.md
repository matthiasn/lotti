# AI summary card header — redesign spec (v5, calm synthesis)

Distilled from the multi-agent panel review of v1–v4. The auto-iteration kept
*adding* structure (a four-band model, overline state words, extra tokens) to
satisfy expert critiques and **regressed the user scores** (calm-sensitive
users dropped to 5–6). v5 keeps the genuinely load-bearing fixes and rejects
the chrome: **calm by default, one obvious focal control.**

## Host (verified against the code)

Target `TldrHeader` in `lib/features/agents/ui/ai_summary_card/tldr_section_part.dart`,
used by `AiSummaryCard` (rendered at `task_detail_pane.dart:365` and
`task_form.dart:43`). Playback binds to **`TtsPlaybackController`**
(`lib/features/tts/state/tts_playback_controller.dart`); this **replaces** the
legacy MLX `_speakSummary` path in `ai_summary_card.dart`. (The panel's claim of
`ai_response_summary.dart` as host was wrong — that is the journal AI-response
card, not the task header.) Tokens only: `tokens.colors.aiCard.*`,
`tokens.spacing.*`, `tokens.typography.*`, `tokens.radii.*`. No new tokens
unless a measured contrast failure forces one — then stop and ask.

## Structure (the existing three regions, kept calm)

    +-----------------------------------------------------------------+
    |  ✦  AI summary                     [Thinking…]   ( ▶ )   ⌄      |   <- identity + control row
    |     Laura · inspect                                             |
    |  TL;DR markdown — comfortable measure, 1.55 line height          |   <- body
    +-----------------------------------------------------------------+

1. **Identity (leading, unchanged in spirit):** sparkle badge + "AI summary"
   (subtitle2, titleText) + agent-name link (caption, metaText, underlined,
   tappable → internals). Name row ≥44px tall hit target.
2. **Control row (trailing), two clearly-separate concerns with a gap of
   `tokens.spacing.step3` between the groups:**
   - **Agent status** (mutually exclusive, existing behaviour, refined):
     idle → one "Run now" icon button; running → a compact **labelled
     "Thinking…" pill** with a small indeterminate ring (a *labelled* chip, so
     it never reads as audio loading); wake scheduled → run-now + countdown
     pill (tabular figures) + cancel.
   - **Playback (the single focal control):** one filled **circular play/stop
     button**, 44×44 hit target / ~36px visible circle, accent fill with an
     onAccent-contrast glyph.
     - idle/ready → **play triangle**.
     - preparing (downloadingModel / synthesizing) → a subtle indeterminate
       ring around the same circle; tooltip "Preparing audio". Distinct in
       size/placement from the agent "Thinking" ring.
     - playing → **square stop** glyph + a thin **determinate progress arc**
       around the circle (position/duration from the controller).
     - **Not available → simply not rendered** (no TL;DR, engine unsupported,
       or `enable_supertonic_tts` off). Hiding a dead control is calmer than a
       greyed one; the flag already gates the whole affordance.
3. **Body (unchanged):** TL;DR markdown + the left-anchored "Read more / Show
   less" pill. Expand stays in the body, not the control row.

## State honesty (panel's real finding, kept simple)

`TtsPlaybackController` routes **both** natural end and user stop to
`stopped` (sourceId=null) — it cannot distinguish them. So the header shows
**no "Finished" beat**: when playback ends either way, the button returns to
the idle play triangle. We do not invent a state the model can't represent.

**Cross-source:** the button reflects play/preparing/progress only when
`state.isActiveFor(thisTaskId)`; for any other source it shows idle play. Two
visible cards never both animate for one utterance.

## Accessibility

- Play/stop and every icon control: ≥44×44 hit target (today's are 28×28).
- **Shape + label, never color alone:** play = triangle, stop = square, plus
  `Semantics(button: true, label: 'Play summary' | 'Stop' | 'Preparing audio')`;
  announce on state change (deuteranopia-safe).
- Reduced motion: rings/arcs render static when `MediaQuery.disableAnimations`.
- Dynamic Type: token styles scale; the control row wraps to a second run
  rather than truncating.
- Contrast: verify accent / metaText on `aiCard.background` and accent on
  `accentSoft` meet WCAG 2.2 AA at build; if short, fix at the token (ask
  first). No asserted ratios here — measure, don't claim.

## Spacing

All from `tokens.spacing`; the ad-hoc `EdgeInsets.fromLTRB(14,14,8,10)` and
magic `SizedBox`es are removed in favour of `step` values and a single
space-between row.

## Out of scope (explicitly rejected from v4)

No four-band model, no overline "state words", no separate full-width status
caption line, no new `completed`/`endedNaturally` state, no added tokens.
Proposals / history / open-internals remain body-level, not in the header.
