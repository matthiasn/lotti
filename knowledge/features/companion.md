---
type: Feature Module
title: Companion
description: The animated character rig — a per-frame animator of springs and timed layers, mouth tracks timed by a playhead, and painters that keep only her edges in the supersampled pass.
resource: ../../lib/features/companion
tags: [companion, avatar, animation, lip-sync, custompainter, widgetbook]
status: draft
generated: { by: claude-code/opus-5.5, at: 2026-10-14T12:00:00Z }
stale_after: 2027-02-22
sources:
  - id: goal-companion
    resource: ../../lib/features/goals/ui/unified/goal_companion.dart
    title: The goal card's companion and the pose a track status gives her
    last_modified: 2026-10-17
  - id: animator
    resource: ../../lib/features/companion/animation/companion_animator.dart
    title: CompanionAnimator
    last_modified: 2026-10-14
  - id: view
    resource: ../../lib/features/companion/ui/companion_view.dart
    title: CompanionView and CompanionController
    last_modified: 2026-10-14
  - id: gesture
    resource: ../../lib/features/companion/model/companion_gesture.dart
    title: CompanionGesture and GestureName
    last_modified: 2026-10-14
  - id: mouth-track
    resource: ../../lib/features/companion/animation/mouth_track.dart
    title: MouthTrack
    last_modified: 2026-10-14
  - id: voiced-text
    resource: ../../lib/features/companion/animation/voiced_text_track.dart
    title: VoicedTextTrack
    last_modified: 2026-10-14
  - id: painter
    resource: ../../lib/features/companion/rig/companion_painter.dart
    title: CompanionPainter and the stage painters
    last_modified: 2026-10-14
  - id: supersampled
    resource: ../../lib/features/companion/rig/supersampled_painter.dart
    title: SupersampledPainter
    last_modified: 2026-10-14
  - id: speaker
    resource: ../../lib/features/companion/ui/companion_speaker.dart
    title: CompanionSpeaker
    last_modified: 2026-10-15
  - id: spoken-track
    resource: ../../lib/features/companion/state/spoken_track.dart
    title: loadSpokenTrack and spokenTrackLoaderProvider
    last_modified: 2026-10-15
  - id: playhead-clock
    resource: ../../lib/features/companion/animation/playhead_clock.dart
    title: PlayheadClock
    last_modified: 2026-10-15
---

# Companion

A drawn character, alive in a widget. In the app she stands beside the task
agent's AI summary, behind `enable_companion` (seeded off), and speaks it with
the on-device voice ([agents UI surfaces](agents/ui-surfaces.md)); the
widgetbook (`lib/widgetbook.dart`) shows all of her. Her
[README](../../lib/features/companion/README.md) covers what she looks like
and how to try her; this concept is how a frame of her is made, and how she
speaks.

She ranks just above `tts` in the layer order
(`tool/architecture/layer_guard.dart`): she imports the voice and the design
system, and every surface that shows her ranks above her. So the words she
says are always the host's — the task agent's summary, the day's plan —
and she never reaches up for data.

# The frame loop

`CompanionView` owns a `Ticker`. Each tick advances one `CompanionAnimator`
by the frame's `dt` — capped at 1/20 s, so a stall moves her one short step,
not a jump — and repaints with the returned `CompanionPose`. The pose is the
only per-frame value; look, mood, framing and the speech track arrive as
widget parameters.

```mermaid
flowchart LR
  T[Ticker tick] -->|dt ≤ 1/20 s| A[CompanionAnimator.step]
  P[playhead reader] -->|position| A
  M[MouthTrack] -->|mouthAt / loudnessAt| A
  A --> Pose[CompanionPose]
  Pose --> CP[CompanionPainter]
  CP --> SS[SupersampledPainter]
  G[CompanionStageGround] --> Out[canvas]
  SS --> Out
  V[CompanionStageVignette] --> Out
```

**Only her edges are supersampled.** `SupersampledPainter` records the figure
at `factor` × the device pixels and halves it back down with `toImageSync`.
That costs a large texture per frame, and it exists for one case: Impeller on
a GL driver without multisampling (a Linux VM), which draws paths without
anti-aliasing. So `CompanionView.platformSupersample` is 4 on Linux and 1
everywhere else, an explicit `supersample` overrides it, and with `stage: true`
the ground and vignette are painted by their own painters around her layer,
not inside the supersampled pass — gradients have no edges to alias. Her
layer sits in its own `RepaintBoundary`, so the stage does not repaint per
frame. `CompanionPainter.stage` only casts her floor shadow.

# The animator

Gestures set targets; damped springs (`Spring` in `rig/rig_math.dart`) chase
them, which gives the ease-in, the overshoot and the settle. Independent
timed layers run on top: breathing, a sway, glances, blinks, the ear flick
and the tail. Every random choice comes from one generator seeded by
`CompanionView.seed`, so a test run is reproducible.

A gesture is a `CompanionGesture` reached by `GestureName`: arm targets plus
the face and body attitude, a `hold`, and `then` — later phases by the
seconds after the start at which they take over. `play` replaces whatever is
in play.

```mermaid
stateDiagram-v2
  [*] --> Ready
  Ready --> Phase: play(name)
  Phase --> Phase: then delay reached (next phase)
  Phase --> Phase: play(other) restarts
  Phase --> Ready: hold elapsed
```

Speech drives a second machine, on whether the playhead is inside the track:

```mermaid
stateDiagram-v2
  [*] --> Silent
  Silent --> Speaking: playhead enters the track (first talking gesture 0.4 s later)
  Speaking --> Speaking: autoGestures, none in play, every 2.2–4 s (picks a talking gesture)
  Speaking --> Silent: playhead leaves the track (she blinks)
```

While speaking, a rise of the voice's loudness through 0.55 — at most every
0.75 s — kicks a nod and a hand beat. Blinks (0.2 s) and ear flicks (0.35 s)
are timed pulses, scheduled by mood-scaled random intervals; `blink()` fires
one now.

`CompanionController` is the owner's handle: `play`, `blink` and `time`
reach the attached view's animator, and are no-ops while detached. Swapping
controllers in `didUpdateWidget` detaches the old one.

# Mouth tracks

The mouth is timed by the **playhead**, never by a clock of its own: each
frame asks the `MouthTrack` for the shape and loudness at the player's
position, so a stall or a seek cannot desync the lips from the voice.

| Track | Shapes from | Loudness from |
|-------|-------------|---------------|
| `TextLipSync` | the text, letter by letter, into nine Rhubarb visemes at a fixed rate | how open the mouth is |
| `SpeechEnvelope` | the loudness (no words) | a WAV's per-frame RMS |
| `VoicedTextTrack` | the text | a WAV's envelope, which also gates the shapes |

`VoicedTextTrack` stretches the text's **spoken** span — up to
`TextLipSync.spokenLength`, the start of the closing rest every line ends
on — over the voiced part of the clip, first sound to last. Stretching the
full `length` instead would squeeze the words into the front of the voice and
close the lips early.

# Speaking with the on-device voice

`CompanionSpeaker` is `CompanionView` bound to the app-wide voice. The host
asks the voice to speak, exactly as it would without her
(`TtsPlaybackController.speak(sourceId:, text:)`), and gives her the same
`sourceId`. The voice knows nothing about her: she reads
`TtsPlaybackState`, whose `clip` carries the WAV and the words it was made
from.

```mermaid
sequenceDiagram
  participant Host as Host (AI summary card)
  participant Voice as TtsPlaybackController
  participant Her as CompanionSpeaker
  participant Loader as loadSpokenTrack
  Host->>Voice: speak(sourceId, text)
  Voice-->>Her: playing, sourceId, clip (path + words)
  Her->>Loader: the clip's path and words
  Loader-->>Her: VoicedTextTrack (or TextLipSync)
  loop every frame
    Her->>Voice: read position (never watched)
    Her->>Her: PlayheadClock carries it to now
  end
  Voice-->>Her: stopped (clip cleared)
  Her->>Her: track dropped, she falls silent
```

- **Only the start and end of an utterance pass through Riverpod.** She
  listens to one selected value — the clip while *her* source plays,
  null otherwise — so the voice's position ticks never rebuild her. Another
  source playing leaves her silent.
- **The clip is read once, off the UI isolate.** `loadSpokenTrack` reads the
  WAV and computes its loudness in `Isolate.run`, because a long summary is
  minutes of samples. A clip already deleted (the utterance ended first) or
  not 16-bit PCM falls back to `TextLipSync` on the words: the voice still
  plays, so she still talks, less exactly in time.
- **Her words are the clip's, not the screen's.** The host's text can change
  while the voice is still synthesizing — the summary card expands, or a new
  report lands — so she never takes words from the host: the clip carries the
  text it was synthesized from.
- **A late load never lands.** Each utterance start or end bumps a counter;
  a load that finishes for an utterance that is over is dropped.
- **The playhead is carried between reports.** The player reports its
  position in coarse steps. `PlayheadClock` carries the latest report forward
  by the time since it arrived, times the playback speed, and starts again
  from every report — at most `maxLead` (250 ms) past it, so a stalled player
  stops her mouth instead of letting it run on through the words. Each
  utterance gets a fresh clock: two clips both open at zero, and a clock that
  still held the first one's zero would start the second at its full lead.

She has five hosts, each with its own framing:

| Host | Framing | Box | Utterance (`sourceId`) |
|---|---|---|---|
| AI summary card (`agents/ui/ai_summary_card.dart`, placed by `agents/ui/ai_summary_card/companion_report_layout.dart`) | `full` beside the summary on a card body at least `CompanionPlacement.besideMinWidth` wide; `bust` in the header's badge tile below that | `ControlSizes.companionCard` high in a `CompanionSlot` as wide as the `bust` window, the rest of the `full` frame overhanging into the gutters; the badge tile at `ControlSizes.avatar`, whose tap opens her `full` framing on the stage, full screen (`agents/ui/ai_summary_card/companion_stage_page.dart`) | the task id |
| Day page header ([Daily OS](daily_os_next/ui-surfaces.md#the-day-briefing)) | `bust` | `ControlSizes.avatar` square | `day-briefing:<yyyy-MM-dd>` |
| Onboarding welcome and first task ([onboarding](onboarding.md#the-companion)) | `full` in the welcome hero, `bust` on the first task | the hero frame's height; `ControlSizes.avatarHero` square | `onboarding-companion` |
| Goal card on the Goals list (`goals/ui/unified/unified_goal_card.dart`, via `goals/ui/unified/goal_companion.dart`) | `bust`, silent `CompanionView` | `ControlSizes.avatarCompact` tile on the goal's status wash, in place of the persona monogram | none — goals have no read-aloud |
| Goal agent's read card (`goals/ui/pages/goal_agent_detail_page_cards_part.dart`, placed by the shared `CompanionReportScaffold`) | as the AI summary card: `full` beside the read on a wide card, `bust` in the header's badge tile below that, in the goal's pose | as the AI summary card; the bust's tap opens her full-screen stage | `goal-report:<agentId>` (`goalReportSpeechSourceId`) |

On the goal card and the goal agent's read card her pose carries the
goal's `GoalTrackStatus`
(`goalCompanionPose`): a held gesture for the verdict at a glance and a mood
for the face, because at 40 pixels the moods alone are a few pixels apart.
Doing well is a raised thumb (`celebrate` once achieved), on the way back a
clap, at risk a hand to the cheek, off track palms down — it is all right,
never a scold — and no data a hand at her ear, listening for news. Until
the health resolves she stands calm and at ready.

`full` is head to toe, wide enough that both wrists stay inside it with room
for the hand in every gesture (a test walks each gesture through its phases).
`bust` is head, shoulders and raised hands, square, for small sizes.

A host cues her through `CompanionController.play` (a gesture once) or keeps a
gesture up with `CompanionView.holding`, which her ticker replays whenever it
relaxes — no timer. `CompanionController.gesture` reads the gesture in play.

# Gotchas

- `CompanionPose` is rebuilt field by field in `_withTrail` to add the hair
  and hem lag; a new pose field must be carried there too.
- `SpeechEnvelope.fromWav` takes 16-bit PCM only.
- Her ticker runs for as long as she is mounted, so a widget test of any
  surface showing her pumps frames by hand; `pumpAndSettle` never settles.
- The illustration colours are deliberately not design-system tokens; the
  [design system](design_system/) governs interface colour, not a drawing's.
