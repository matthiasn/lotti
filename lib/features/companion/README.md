# Companion

Lotti, the grandmother who presents the app in the pitch videos, drawn live in
Flutter: a character who can sit in the app and talk, instead of only
appearing in a video.

**Status: proof of concept, shown in the widgetbook only.** Nothing in the app
shows her yet. The plan she comes from, and the phases still ahead (the chat,
the Daily OS briefing, a mood read from the record, character choice), is
[docs/implementation_plans/2026-10-12_in_app_agent_avatar.md](../../../docs/implementation_plans/2026-10-12_in_app_agent_avatar.md).

## What it does

- **She is alive.** She breathes, sways a little, blinks, and glances about,
  with her hair and hem trailing the motion.
- **She gestures.** The 19 gestures of the videos (wave, present, point,
  think, clap, celebrate, horns, and so on), each with its face and posture.
  Her elbows come from a constrained arm solver, so her arms never cross into
  an X or bend backwards.
- **She talks.** The mouth follows a `MouthTrack` on a playhead the owner
  supplies, so a stall or a seek never puts it out of step with the voice:
  - `SpeechEnvelope`: a 16-bit PCM WAV's loudness, the format the on-device
    voice (`lib/features/tts/`) writes;
  - `TextLipSync`: the words alone, read into the nine Rhubarb mouth shapes;
  - `VoicedTextTrack`: both, the words' shapes timed and gated by the voice.
- **She has moods** (`calm`, `bright`, `busy`, `frazzled`, `sleepy`) that show
  on her face and in her breathing, never as guilt.
- **She has looks**: everyday (teal dress, mustard cardigan), stage (raspberry
  dress, ivory cardigan) and rock (beret, yellow sunglasses, beads, a red
  glove). A look is data: a palette and a few switches.

## Where the code sits

| Directory | What |
|---|---|
| `model/` | The data: looks and their palettes, poses, gestures, hand and mouth shapes, moods |
| `rig/` | Drawing: the arm solver, the limb ribbon, the frames a pose resolves into, and one painter per body part, composed by `CompanionPainter` |
| `animation/` | Motion: `CompanionAnimator` turns time, a mood, gestures and speech into a pose per frame; the mouth tracks |
| `ui/` | `CompanionView`, the live widget, and its `CompanionController` |
| `widgetbook/` | The widgetbook folder "Companion" |

Per-frame values never leave `CompanionView`'s state: its `Ticker` steps the
animator and repaints. What changes rarely (look, mood, what she says) comes
in as widget parameters.

She is drawn through `SupersampledPainter`, 4 samples per pixel by default,
because Impeller on a GL driver without multisampling (as in a Linux VM)
draws paths without anti-aliasing: her outline would show stair steps that
crawl as she moves. `stage: true` stands her on the pitch videos' dark stage
(`rig/stage_painter.dart`).

## Where she comes from

The pitch videos draw her with a Python/cairo rig
(`tools/tutorial_videos/presenter/narrator/`). This feature is a port of that
rig's design and motion to Dart, one module to one file: `character.py` →
`rig/body_painter.dart` and `rig/head_painter.dart`, `face.py` →
`rig/face_painter.dart`, `arm.py` → `rig/arm_solver.dart`, `motion.py` →
`animation/companion_animator.dart`, and so on. The colours are illustration
colours (her skin, hair and clothes), not interface colours, so they do not
come from the design system's tokens.

## Trying her out

Run the widgetbook (`fvm flutter run -d <device> -t lib/widgetbook.dart`) and
open **Companion → Lotti (grandma)**:

- **Playground**: the look, mood, framing, stage and smoothing as knobs, a
  line to say, and a button per gesture;
- **Talking with a voice (WAV)**: give it a 16-bit PCM WAV path (and, for
  better mouth shapes, its words), press Play, and she says it out loud;
- **Looks**, **Moods** and **Chat avatar sizes** side by side.
