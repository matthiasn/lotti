---
type: Feature Module
title: Recording UI
description: "Two interchangeable level visualizations over one dBFS stream, plus the controls and indicators around them."
resource: ../../../lib/features/speech/ui/widgets/recording
tags: [speech, ui, vu-meter, visualization]
status: stable
generated: { by: claude-code/fable-5.1, at: 2026-10-05T12:00:00Z }
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

Every recorder is one studio layout, `RecordingStage` in
[`recording_controls.dart`](../../../lib/features/speech/ui/widgets/recording/recording_controls.dart),
top to bottom:

- **Status** — `RecordingStatus`, a red dot and *Recording*, or a quiet dot
  and *Paused*. Only where the host has no status line of its own
  (`showStatus`): the recording sheet and the check-in page's dock show it,
  the check-in composer does not, because its header already says so.
- **The look the user chose** — `RecordingLevelVisualizer`, the orb or the
  meter. On a light surface the orb sits on a *lit pool*: a radial gradient
  from the brightest surface at the centre through the orb's glint at the
  ring to nothing, so its light has something to glow against.
- **The running time** — `RecordingClock`, a regular heading in the UI face
  with tabular figures, so the digits never shift, in the neutral ink.
- **The level line** — `RecordingLevelLine`, the level bars from
  [`live_waveform.dart`](../../../lib/features/speech/ui/widgets/recording/live_waveform.dart)
  across the sheet, fading out at both ends: accent under the orb, neutral
  under the meter, the pair the user chose the look from in onboarding. It
  keeps a short window of normalised levels (`normaliseDbfs`, in
  [`recording_levels.dart`](../../../lib/features/speech/state/recording_levels.dart))
  while the take runs and holds it still while paused, so it reads as speech
  over time where the orb and meter read the level now. Daily OS Capture and
  the onboarding previews draw the same bars from the same helpers.
- **The transport row** — `RecordingTransportControls`: discard ✕ and
  pause ⏸ / resume ▶ as quiet rings either side of one filled red Stop disc,
  the only colour in the row. Before a take starts the sheet puts its record
  button in this slot.
- **A footer** — the sheet's speech-recognition option, or the check-in's
  *audio saved as you go*.

The pictures (orb or meter, and the level line) are one semantics label the
host names; the sheet makes it a live region, the check-in hosts do not,
because their status line already announces each transition.

The orb takes its colours by role from one palette,
[`AiVoiceOrbPalette`](../../../lib/features/ai/ui/animation/ai_voice_orb_palette.dart),
built from the tokens of the surface it sits on — the recording sheet, Daily OS's
voice button and onboarding's style previews all use it. The shader draws light:
its body is the accent, its glints the brightest parts, a soft halo around each
strand. On a dark surface the palette is the accent, white glints and the accent
deepened for the halo, as the orb always was. On a light surface the energy must
still read *lighter*, so the glint is the accent's hue at the dark theme's
lightness, the halo the lit teal between them, and the shader's `uLightSurface`
narrows and softens the halos and glints — every light-surface change written as
`mix(dark, light, L)`, so dark mode is unchanged to the pixel. The text ink once
fed the glints, which on a light sheet drew the peaks as black strands. There the
recorder's clock takes the neutral ink, leaving the teal to the live parts.

The dBFS values come from `AudioRecorderController`, which samples amplitude every
20 ms and derives VU through the standalone `VuMeter` sliding-window unit. See
[the speech overview](overview.md).

# Where the indicators are, and are not

| Surface | Shows |
|---------|-------|
| Recording modal | The whole `RecordingStage`: status, VU meter or orb, elapsed time, level line, record / discard–Stop–pause, speech recognition |
| Check-in page dock | The same stage, embedded in place by `CheckInInlineRecorder` with its own status line |
| Check-in composer | The same stage without the status line, which the composer's header carries |
| Mobile recording pill | A compact live indicator |
| Desktop sidebar row | A red accent card, a pulsing dot and elapsed time — **deliberately no dBFS reaction** |
| Task, entry and event action bars | `GlassRecordButton`: the accent-ringed mic takes the alert fill while a session linked to *that* task, entry or event is recording or paused — **no level, no time** |

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
