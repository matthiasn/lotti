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
    last_modified: 2026-10-19
  - id: animator
    resource: ../../lib/features/companion/animation/companion_animator.dart
    title: CompanionAnimator
    last_modified: 2026-10-19
  - id: view
    resource: ../../lib/features/companion/ui/companion_view.dart
    title: CompanionView and CompanionController
    last_modified: 2026-10-19
  - id: gesture
    resource: ../../lib/features/companion/model/companion_gesture.dart
    title: CompanionGesture and GestureName
    last_modified: 2026-10-19
  - id: reaction
    resource: ../../lib/features/companion/model/companion_reaction.dart
    title: companionReaction, CompanionCue and CompanionSass
    last_modified: 2026-10-19
  - id: arm-solver
    resource: ../../lib/features/companion/rig/arm_solver.dart
    title: solveArm and its preferred elbow
    last_modified: 2026-10-19
  - id: mouth-track
    resource: ../../lib/features/companion/animation/mouth_track.dart
    title: MouthTrack
    last_modified: 2026-10-19
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
    last_modified: 2026-10-19
  - id: spoken-track
    resource: ../../lib/features/companion/state/spoken_track.dart
    title: loadSpokenTrack and spokenTrackLoaderProvider
    last_modified: 2026-10-15
  - id: tone-reader
    resource: ../../lib/features/companion/animation/tone_reader.dart
    title: readTones, the on-device tone of each sentence
    last_modified: 2026-10-19
  - id: tone-track
    resource: ../../lib/features/companion/animation/tone_track.dart
    title: ToneTrack, the tones timed by the playhead
    last_modified: 2026-10-19
  - id: look-controller
    resource: ../../lib/features/companion/state/companion_look_controller.dart
    title: companionOutfitProvider and companionLookProvider
    last_modified: 2026-10-19
  - id: customization
    resource: ../../lib/features/companion/state/companion_customization_controller.dart
    title: companionCustomizationProvider, her stored customization
    last_modified: 2026-10-19
  - id: parts
    resource: ../../lib/features/companion/model/companion_parts.dart
    title: Skin tones, hairstyles and hair colours
    last_modified: 2026-10-19
  - id: hair-styles
    resource: ../../lib/features/companion/rig/hair_styles_painter.dart
    title: The hairstyles' painters
    last_modified: 2026-10-19
  - id: settings-page
    resource: ../../lib/features/companion/ui/settings/companion_settings_page.dart
    title: The page that customizes her
    last_modified: 2026-10-19
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

**Her face can be lopsided.** `browSkew` and `smileSkew` lift her right
brow or mouth corner (screen right) and lower the left by as much, on top of
the symmetric `browRaise` and `smile`; the mood's and the gesture's add. The
smile runs from -1 to 1, so below zero the corners turn down. A gesture's
`lids` adds to the mood's resting lids, which is how a facepalm shuts her
eyes and an eye roll half-closes them.

**An elbow may be asked for.** The arm solver keeps the most relaxed elbow
it is allowed, which hangs; hands on the hips need it out. A `GestureArm`'s
`elbow` names the direction the upper arm would rather take, and the solver
weighs its choices against that instead of the hang, inside the same rules.

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

Every track also answers `timeOf(offset)`: when the character at that offset
of its words is spoken, on the same clock as its shapes — `TextLipSync`
records the time it reaches each character, and `VoicedTextTrack` stretches
that over the voice as it does the shapes. A voice alone (`SpeechEnvelope`)
has no words and answers null. This is how her face is timed to the words.

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
  Her->>Her: ToneTrack.read(the clip's words, that track)
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
(`goalCompanionPose`), on the warm end of the [reaction
scale](#reactions): a held gesture for the verdict at a glance and a mood
for the face, because at 40 pixels the moods alone are a few pixels apart.
Doing well is a raised thumb (`celebrate` once achieved), on the way back a
clap, at risk a hand to the cheek, off track palms down — it is all right,
never a scold — and no data a hand at her ear, listening for news. Until
the health resolves she stands calm and at ready.

**What she wears.** Every host shows her as `companionLookProvider` draws
her, in `companion/state/`; `CompanionSpeaker` and the goal card's silent
bust both watch it, and no host passes a look. It is two things together:

```mermaid
flowchart LR
  DB[(SettingsDb<br/>COMPANION_CUSTOMIZATION)] -->|loaded once| C[companionCustomizationProvider<br/>skin tone · hairstyle · hair colour · outfit?]
  C -->|outfitId| O[companionOutfitProvider<br/>the chosen outfit, or a random one]
  R[companionOutfitRandomProvider] --> O
  Stage[stage palette button] -->|next| O
  Settings[Settings › Preferences › Companion] -->|set| C
  C -->|dress| L[companionLookProvider]
  O --> L
  L --> Hosts[CompanionSpeaker · GoalCompanionBust · settings preview]
```

- **The outfit** (`companionOutfitProvider`): the one chosen in her
  customization, or, with none chosen, one of `companionOutfits` (the
  grandmother's looks) drawn by `companionOutfitRandomProvider`, which a test
  or a capture pins. It is not auto-disposed, so the draw holds until the app
  closes. The stage's palette control calls `next`, stepping through the
  outfits and wrapping, for the session only; a new choice in settings
  starts over from that choice.
- **The customization** (`companionCustomizationProvider`): her skin tone,
  hairstyle, hair colour and outfit, stored as JSON under
  `COMPANION_CUSTOMIZATION` in `SettingsDb` (the keys are in
  `lib/utils/companion_settings_keys.dart`, which sync reads too). It starts at
  the default — Lotti as the videos draw her — and refines when the load
  lands; a change made before that wins. A part a newer version wrote, or an
  outfit that no longer exists, reads as the default.
- **It syncs** as the Daily OS greeting name does, last write wins:

  ```mermaid
  sequenceDiagram
    participant Page as Settings page
    participant C as Customization controller
    participant DB as SettingsDb
    participant Out as Outbox
    participant Peer as Other device
    Page->>C: set(customization)
    C->>DB: saveLocalSettingsGroup(JSON, stamp)
    C->>Out: SyncMessage.companionCustomization (debounced 250 ms)
    C->>DB: SYNCED_AT = stamp
    Out-->>Peer: message
    Peer->>Peer: saveSettingsItemsIfNewer (value, stamp, SYNCED_AT)
    Peer->>Peer: settingsNotification, controller reloads, never sends back
  ```

  A customization stored but never published — while the outbox failed — is
  published once on the next load. A reload that a `settingsNotification`
  triggers while a local save is still committing waits for the save, so the
  page never shows the value the save is replacing. "Send settings" re-sends
  it with the other preferences.
- **Dressing** (`CompanionCustomization.dress`) lays the skin tone and hair
  colour over the outfit's palette and sets its hairstyle; the outfit keeps
  its clothes and props. A deeper tone deepens plain lips, never lipstick an
  outfit paints (the rock look's red).

Every part combines with every other, and none is named after a people:
skin tones are numbered, light to deep, and a screen reader says "Skin tone
3". Five hairstyles share one dispatch, `hair_styles_painter.dart`: each has
a back layer (behind the head and body), a front layer over the forehead
whose outline also shades it, and hanging parts that trail the head's motion
by the hair lag — the locs and the bob's ends; the bun keeps its painter,
`hair_painter.dart`.

`full` is head to toe, wide enough that both wrists stay inside it with room
for the hand in every gesture (a test walks each gesture through its phases).
`bust` is head, shoulders and raised hands, square, for small sizes.

A host cues her through `CompanionController.play` (a gesture once) or keeps a
gesture up with `CompanionView.holding`, which her ticker replays whenever it
relaxes — no timer. `CompanionController.gesture` reads the gesture in play.

# Reactions

`companionReaction(approval, sass:)` is how a host says how a piece of work
went: approval from `minApproval` (-3) to `maxApproval` (+3), sass `warm`,
`cheeky` or `sassy`. Each cell is a `CompanionCue` — a mood and a gesture to
hold. Warm is encouraging whatever happened; sassy is hands on hips, slow
claps and eye rolls. Two rules hold across the table, and its tests keep
them: her smile never falls as approval rises, and warm uses none of the
sassy faces or gestures. Disapproval stops at sass: no reaction is hurt or
sad, and none is ever tied to a notification. Nothing passes a sass other
than warm yet; the coaching agent's charter is meant to choose it (plan
2026-10-12, "Revision").

# Her face on the words

While she speaks, her face follows how the words land, not only the host's
mood. `readTones` reads the clip's text — Markdown and all — into cues, one
at the first character of each line and each sentence in it, with an
approval on the reaction scale or null where the words read neither way:

- A sentence's own words decide its tone: a short English and German list
  of word beginnings and phrases ("finish", "well done", "overdue",
  "blocked", "erledigt", "überfällig"), plus emoji that read the same in any
  language (✅ 🎉 ⚠️ ❌). Praise denied ("not done") counts as a concern,
  trouble denied ("no blockers") as good news; the sum is clamped to the
  scale.
- A sentence that reads neither way takes its **section's** tone, set by the
  heading above it, so every line under "⚠️ Risks" keeps her concerned.
- A report in another language reads neither way except by its emoji; the
  agent marking tone in its own report is the later step (plan 2026-10-12,
  "Revision").

`ToneTrack.read` times each cue with the mouth's `timeOf`, so a tone starts
when the voice reaches its sentence. `CompanionSpeaker` builds it with the
mouth, from the same clip, so the two never belong to different clips, and
drops both when the utterance ends.

`CompanionView` asks the tone for the approval at the playhead each frame,
as it asks the mouth for its shape:

```mermaid
stateDiagram-v2
  [*] --> HostMood
  HostMood --> Reaction: playhead in a sentence with a tone (its gesture cued once)
  Reaction --> Reaction: the tone changes (the new reaction's gesture cued once)
  Reaction --> HostMood: a sentence with no tone, or the playhead leaves the track
```

In a reaction her mood is `companionReaction(approval, sass:).mood`; the
gesture is played once when the tone changes, not held, so her talking
gestures resume after it. `sass` is warm unless the view is given another;
no host gives one yet.

# Gotchas

- Hair has to fit the `bust` window: it leaves about 106 head units above
  the face's centre, and the bun tops out at 90. The afro is drawn wider
  than tall so its curls stop near 99; a taller style would be cut off on
  every bust (`hair_styles_painter_test.dart` measures the silhouettes).

- `CompanionPose` is rebuilt field by field in `_withTrail` to add the hair
  and hem lag; a new pose field must be carried there too.
- `SpeechEnvelope.fromWav` takes 16-bit PCM only.
- Her ticker runs for as long as she is mounted, so a widget test of any
  surface showing her pumps frames by hand; `pumpAndSettle` never settles.
- The illustration colours are deliberately not design-system tokens; the
  [design system](design_system/) governs interface colour, not a drawing's.
