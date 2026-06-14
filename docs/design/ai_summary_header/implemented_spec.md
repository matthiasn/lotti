# AI summary card header — AS IMPLEMENTED (for final validation)

This describes the header as actually shipped in code (TldrHeader +
AiSummaryCard + TtsPlayButton), wired to TtsPlaybackController. Judge THIS, not
an aspirational spec.

## Identity (leading)
- 22px sparkle badge (accentSoft fill, accent glyph).
- "AI summary" — subtitle2, weight 600, aiCard.titleText.
- Agent-name link — caption, aiCard.metaText, underlined, tappable (opens agent
  internals). The name row is a ≥44px-tall tap target.

## Control row (trailing, a space-between Wrap that drops to a second run only
when it genuinely can't fit)
- Agent status (mutually exclusive):
  - running → a labelled "Thinking…" pill (accentSoft fill, hairline border, a
    12px ring + the word "Thinking…" in accent). A labelled chip, not a bare
    spinner, so agent activity never reads as audio loading.
  - idle, no scheduled wake → a single "Run now" refresh icon button.
  - scheduled wake → run-now (play) icon + a tabular-figure countdown pill +
    a cancel (×) icon.
- Playback — TtsPlayButton, the focal control:
  - 44×44 hit target around a 36px filled-accent circle with the dark
    aiCard.background color as the glyph (high contrast; clearly stands out on
    the dark card).
  - idle → play triangle; playing → stop square + a thin determinate progress
    arc (position/duration); preparing (model download / synthesis) → an
    indeterminate ring; reduced-motion renders that ring static.
  - Shape + a semantic label ("Play summary" / "Stop" / "Preparing audio")
    distinguish states — never color alone.
  - Rendered only when the feature flag is on AND there is a TL;DR AND the
    on-device engine is supported (macOS); otherwise it is simply absent.
- "Read more / Show less" pill (unchanged).

## Body
- TL;DR markdown, comfortable measure, 1.55 line-height.

## Behaviour
- Tapping play calls TtsPlaybackController.speak(sourceId: taskId, text: tldr);
  the button reflects play/preparing/progress only when this task is the active
  source (so multiple cards never animate for one utterance). Natural end and
  user stop both return it to the idle play triangle. A synthesis failure
  surfaces an error toast.

## Tokens & a11y
- All spacing from tokens.spacing; all type from tokens.typography; all color
  from tokens.colors.aiCard. Header padding is token-based (step4/step3).
- ≥44pt targets on the focal control; reduced-motion respected; Dynamic Type
  scales via tokens; the row wraps rather than truncating.
