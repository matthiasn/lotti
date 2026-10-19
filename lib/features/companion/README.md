# Companion

Lotti, the grandmother who presents the app in the pitch videos, drawn live in
Flutter: a character who can sit in the app and talk, instead of only
appearing in a video. A cat and a red panda can stand in for her: the same
rig, another species.

**Status: first appearance, behind a flag.** With **Companion**
(`enable_companion`, Settings › Advanced Settings › Config Flags) and **AI
summary playback** on, she stands beside a task's AI summary and speaks it
when its read-aloud control is pressed, sits in the Day page header,
briefing the day when tapped, and greets a new user in onboarding. Everywhere
else she is in the widgetbook only. The plan she comes from, and the branches
still ahead (a mood read from the record, character choice, talking back,
nudges), is
[docs/implementation_plans/2026-10-12_in_app_agent_avatar.md](../../../docs/implementation_plans/2026-10-12_in_app_agent_avatar.md).

## What it does

- **She is alive.** She breathes, sways a little, blinks, and glances about,
  with her hair and hem trailing the motion.
- **She gestures.** The 19 gestures of the videos (wave, present, point,
  think, clap, celebrate, horns, and so on), and six sassy ones of her own
  (hands on hips, a wagging finger, a shrug, a facepalm, a slow clap, an eye
  roll), each with its face and posture. Her elbows come from a constrained
  arm solver, so her arms never cross into an X or bend backwards; a gesture
  may ask for the elbows out, as hands on the hips do.
- **She speaks with the app's voice.** `CompanionSpeaker` shows her speaking
  whatever the on-device voice (`lib/features/tts/`) plays for one source:
  the host asks the voice to speak, as it would without her, and gives her
  the same source. She takes the words with the clip from the voice, so they
  are always the ones being played. She owns none of the words she says.
- **She talks.** The mouth follows a `MouthTrack` on a playhead the owner
  supplies, so a stall or a seek never puts it out of step with the voice:
  - `SpeechEnvelope`: a 16-bit PCM WAV's loudness, the format the on-device
    voice (`lib/features/tts/`) writes;
  - `TextLipSync`: the words alone, read into the nine Rhubarb mouth shapes;
  - `VoicedTextTrack`: both, the words' shapes timed and gated by the voice.
- **Her face follows the words.** While she reads, each sentence's tone —
  praise, neither, or something that needs work, read on the device from its
  words, its emoji and its section's heading (`ToneTrack`) — gives her the
  matching reaction, timed by the same playhead as her mouth.
- **She has moods** (`calm`, `bright`, `busy`, `frazzled`, `sleepy`) that show
  on her face and in her breathing, never as guilt.
- **She reacts.** `companionReaction` rates a piece of work from -3 to +3,
  warm, cheeky or sassy, and gives a mood and a gesture to hold: a thumbs up
  or a celebration at the top, a raised brow, an eye roll or hands on the
  hips below. Seven more moods carry it (`proud`, `delighted`, `smug`,
  `skeptical`, `unimpressed`, `disappointed`, `stern`), some of them
  lopsided: one brow up, a smirk. Disapproval is sass, never hurt. The goal
  card uses its warm end.
- **She has looks**: everyday (teal dress, mustard cardigan), stage (raspberry
  dress, ivory cardigan), rock (beret, yellow sunglasses, beads, a red
  glove), garden (sage and straw), lavender (lavender and dove grey) and
  winter (navy and red). A look is data: a palette and a few switches.
- **She dresses for the session.** In the app she wears one of her outfits,
  drawn at random the first time she is shown and kept on every screen until
  the app closes (`companionOutfitProvider`); the palette button on her
  full-screen stage changes into the next one.
- **A person makes her their own.** In Settings › Preferences › Companion
  (shown with the flag) they pick her skin tone (six, numbered, never named
  after a people), her hairstyle (bun, curls, afro, locs, bob), her hair
  colour (silver, white, grey, black, brown, auburn, pink, lavender, blue)
  and an outfit she always wears, or "Surprise me". Every part combines with
  every other. The choice is stored and synced to the person's other devices
  (`companionCustomizationProvider`), the most recent change winning.
- **She can be an animal.** A look names its species (`CompanionSpecies`):
  the grandmother, a silver tabby cat (`cat`, `cat_rock`) or a red panda
  (`red_panda`, `red_panda_bookish`). An animal keeps her skeleton, gestures,
  moods and mouth, and swaps the hair for ears, the face for a furred head
  with a muzzle and whiskers, the shoes for paws, and gains a tail that
  swings while an ear flicks now and then. The red panda's head is drawn
  bigger.

## Where the code sits

| Directory | What |
|---|---|
| `model/` | The data: looks and their palettes, poses, gestures, hand and mouth shapes, moods, the reaction scale, and the parts a person dresses her in (`companion_parts.dart`, `companion_customization.dart`) |
| `rig/` | Drawing: the arm solver, the limb ribbon, the frames a pose resolves into, and one painter per body part, composed by `CompanionPainter`; the animals' head and tail in `animal_head_painter.dart` and `tail_painter.dart`; her hairstyles in `hair_styles_painter.dart`, the bun in `hair_painter.dart` |
| `animation/` | Motion: `CompanionAnimator` turns time, a mood, gestures and speech into a pose per frame; the mouth tracks; `PlayheadClock`, the playhead between a player's reports |
| `state/` | `loadSpokenTrack`: the mouth for a clip the voice plays, read once off the UI isolate; the session's outfit, her stored customization, and `companionLookProvider`, the two together |
| `ui/` | `CompanionView`, the live widget, and its `CompanionController`; `CompanionSpeaker`, the view bound to the on-device voice; `settings/`, the page that customizes her |
| `widgetbook/` | The widgetbook folder "Companion" |

Per-frame values never leave `CompanionView`'s state: its `Ticker` steps the
animator and repaints. What changes rarely (look, mood, what she says) comes
in as widget parameters.

She is drawn through `SupersampledPainter`, 4 samples per pixel on Linux and
none elsewhere, because Impeller on a GL driver without multisampling (as in
a Linux VM) draws paths without anti-aliasing: her outline would show stair
steps that crawl as she moves. Beside the summary she is framed head to toe,
both hands in view in every gesture; in the Day header, as a bust. `stage: true` stands her on the pitch
videos' dark stage (`rig/stage_painter.dart`).

## Where she comes from

The pitch videos draw her with a Python/cairo rig, the presenter engine. It
is not part of this repository: the module names below are that engine's,
for orientation, not paths here. This feature is a port of that rig's design
and motion to Dart, one module to one file: `character.py` →
`rig/body_painter.dart` and `rig/head_painter.dart`, `face.py` →
`rig/face_painter.dart`, `arm.py` → `rig/arm_solver.dart`, `motion.py` →
`animation/companion_animator.dart`, and so on. The colours are illustration
colours (her skin, hair and clothes), not interface colours, so they do not
come from the design system's tokens.

## Trying her out

Run the widgetbook (`fvm flutter run -d <device> -t lib/widgetbook.dart`) and
open **Companion → Lotti (grandma)**, **Cat** or **Red panda**; each has the
same use cases, its look knob limited to its own looks:

- **Playground**: the look, mood, framing, stage, smoothing and sass as
  knobs, a line to say (her face follows it), and a button per gesture;
- **Talking with a voice (WAV)**: give it a 16-bit PCM WAV path (and, for
  better mouth shapes, its words), press Play, and she says it out loud;
- **Looks**, **Moods**, **Reactions** (every approval at every sass) and
  **Chat avatar sizes** side by side.

How a frame of her is made, the animator's states and the mouth tracks:
[knowledge/features/companion.md](../../../knowledge/features/companion.md).
