---
type: Feature Module
title: Recording UI
description: "Two interchangeable level visualizations over one dBFS stream, plus the controls and indicators around them."
resource: ../../../lib/features/speech/ui/widgets/recording
tags: [speech, ui, vu-meter, visualization]
status: stable
generated: { by: claude-code/fable-5.1, at: 2026-10-02T22:30:00Z }
stale_after: 2027-04-02
sources:
  - id: src
    resource: ../../../lib/features/speech/ui/widgets/recording
    title: Recording UI source
    last_modified: 2026-10-02
---

The recording UI offers **a selectable analog VU meter or an energy orb**, plus
recording controls and status indicators — all driven by **the same live dBFS
stream**.

`AnalogVuMeter` is custom-drawn: a traditional analog needle responding to audio
level in real time. The energy orb is the shader-driven alternative. Which one
renders is a user preference (*Settings → Recording Style*), and **the feed is
identical either way** — the choice is purely presentational, so neither variant
can report a different level than the other.

The dBFS values come from `AudioRecorderController`, which samples amplitude every
20 ms and derives VU through the standalone `VuMeter` sliding-window unit. See
[the speech overview](overview.md).

# Where the indicators are, and are not

| Surface | Shows |
|---------|-------|
| Recording modal | The full visualizer (VU meter or orb), elapsed time, record/stop/discard |
| Mobile recording pill | A compact live indicator |
| Desktop sidebar row | A red accent card, a pulsing dot and elapsed time — **deliberately no dBFS reaction** |
| Task and entry action bars | `GlassRecordButton`: the accent-ringed mic takes the alert fill while a session linked to *that* task or entry is recording or paused — **no level, no time** |

The desktop row is intentionally inert to level: it is ambient status in a
navigation rail, and a reacting meter there would pull attention away from
whatever the user is actually doing.

The action bars' mic
([`glass_record_button.dart`](../../../lib/features/speech/ui/widgets/recording/glass_record_button.dart))
is inert to level by construction, not just by design: it watches the
recorder's state through a selector on
`AudioRecorderState.isActiveSessionFor(linkedId)` — recording or paused, and
linked to its own task or entry — so the level and progress updates streaming
through the state during a recording rebuild neither the button nor the bar
around it. Both sticky bars render this one widget, which is what keeps the
app's lead-action mic to one look, one active state and one accessibility
story.
