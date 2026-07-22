---
name: tutorial-videos
description: Build, debug, extend, localize, or publish the automated tutorial videos — the workbench that drives the real Linux app under Xvfb (virtual mic, live Voxtral transcription, task-agent proposals), records the screen, narrates with Gemini TTS, fast-forwards waits, composes MP4s via OpenMontage, and uploads finished videos to Cloudflare R2 for docs-site embedding. Use when asked to "build/regenerate the tutorial video(s)", add a tutorial scenario, add a tutorial locale, fix a broken tutorial run, adapt the pipeline, or upload/publish a video.
argument-hint: "<what to do, e.g. 'build de+en', 'add scenario X', 'debug the failing run'>"
---

# Tutorial Video Workbench

Architecture and rationale live in `tools/tutorial_videos/README.md` — read
it first. This skill is the operational runbook.

## Build videos

```sh
make tutorial_video TUTORIAL_LOCALE=de                       # one locale (~5-8 min)
make tutorial_video TUTORIAL_LOCALE=de TUTORIAL_DEVICE=mobile # phone-shaped window, `_mobile`-suffixed output
make tutorial_videos_all                                     # all TUTORIAL_LOCALES
```

`TUTORIAL_DEVICE` (`desktop`|`mobile`, default `desktop`) picks the capture
window size — see the README's "Desktop vs. mobile" section for the
breakpoint rationale and the `tutorialDeviceIsMobile()` test hook.

Preconditions (fail fast if missing):
- `.env` at repo root with `GEMINI_API_KEY`, `MELIOUS_API_KEY`,
  `MELIOUS_BASE_URL`. If absent, the keys can be extracted from the dev
  app's `ai_config.sqlite` provider rows (never print or commit them).
- Sibling `../OpenMontage` checkout at the commit pinned in
  `tools/tutorial_videos/config/openmontage.pin`, bootstrapped via
  `make -C ../OpenMontage setup`.
- `Xvfb`, `ffmpeg`, `pactl`, `paplay`, `x11-utils` installed; Flutter via
  `fvm`.

Output lands in `build/tutorial_videos/<scenario>_<locale>.mp4`. Verify with
frame extraction (`ffmpeg -ss <t> -frames:v 1`) and check: cursor visible and
gliding, HUD clock top-center, transcript/proposals on screen, narration
audible at step starts (`volumedetect`), duration ≈ warped timeline total.

## Publish to R2

```sh
make tutorial_video_publish TUTORIAL_SCENARIO=create_task_from_audio TUTORIAL_LOCALE=de
```

Uploads `build/tutorial_videos/<scenario>_<locale>.mp4` to Cloudflare R2 at
`tutorial-videos/<scenario>_<locale>.mp4` and prints its public r2.dev URL —
this is the URL the docs-site `TutorialVideo` component builds from
`TUTORIAL_VIDEO_BASE_URL`/`tutorialVideoBaseUrl`. Full one-time Cloudflare
setup (API token, enabling the bucket's public r2.dev URL) and the `.env`
variable list are in the README's "Publishing to Cloudflare R2" section —
read it before the first publish.

`boto3` (needed only by publish, not by build/tts/validate) is not installed
into the system Python on this host (PEP 668). Either run publish through
`tools/tutorial_videos/.venv` (`.venv/bin/python3 -m tutorial_videos publish
--scenario ... --locale ...`, created via `python3 -m venv .venv &&
.venv/bin/pip install boto3 pyyaml`), or install `boto3` into whatever
Python `make tutorial_video_publish` resolves to.

## The pipeline in one paragraph

`python3 -m tutorial_videos build` (run from `tools/tutorial_videos/`) does:
Gemini-TTS pre-pass (cached by content hash → durations manifest) → Xvfb +
virtual-mic null sink + ffmpeg x11grab capture → `fvm flutter drive` runs
`integration_test/tutorial/<scenario>_tutorial_test.dart` against the real
app (penguin demo world + Melious/Voxtral/Qwen agent config seeded, UI
language via `MANUAL_LANGUAGE` settings row) → the test emits
`timeline.json` (step boundaries, wait spans, zero epoch) → `timewarp.py`
plans fast-forward segments for the waits (narration never overlaps) →
`compose.py` warps the capture and drives the pinned OpenMontage headlessly
(narration placement + mux) → ffprobe validation.

## Debugging a failing run

1. The run log tail shows the failing step and a `Diagnostics:` line
   (current route, detail stack, key widget presence).
2. **Look at the failure screenshot first**:
   `build/tutorial_videos/failure_<context>.png` is captured at the moment of
   every timeout — it almost always explains the failure instantly.
3. Reproduce faster without video: run the same test via `flutter drive`
   directly (see the doc comment in
   `integration_test/tutorial/tutorial_harness.dart` for the env contract);
   Xvfb + sink setup must match `session.py`.
4. Common causes, in order of historical frequency: a finder matching an
   offstage duplicate (scope to the visible page + `.hitTestable()`), a
   scroll helper given a non-vertical scrollable, a modal/dialog blocking
   the UI (onboarding, discard-recording), the agent's
   `automaticUpdatesEnabled` flag not sticking (set-and-verify), cloud
   latency beyond a `pumpUntil` timeout.

## Adding a locale

1. Add the locale's text to
   `tools/tutorial_videos/config/scenarios/<scenario>.yaml`: `title`,
   `dictionary`, every step's `narration`, the dictation step's
   `dictation_text`. Write informal register (du/tu) per repo l10n rules;
   keep the penguin vocabulary.
2. Add per-stream `style` lines for the locale in `config/voices.yaml`
   (style prompts in the target language — Voxtral/Gemini behave better).
3. `python3 -m tutorial_videos validate --scenario <s> --locale <l>` must
   pass, then build. The app UI localizes itself via `LOTTI_MANUAL_LOCALE`
   (same mechanism as manual screenshots; for a wholly new app locale, run
   the `add-flutter-docusaurus-locale` skill first).
4. Localized finder strings in the test (`localized(en:, de:)` /
   `manualScreenshotText`) need the new locale only if its UI labels are
   used as finders — prefer keys over text finders where possible.

## Adding a scenario

1. New YAML in `config/scenarios/<name>.yaml` — schema documented in
   `create_task_from_audio.yaml` (unique step ids, exactly one
   `dictation: true` step, per-locale text, `min_duration` floors).
2. New `integration_test/tutorial/<name>_tutorial_test.dart` built on
   `TutorialAppHarness` + `TutorialDriver`. Copy the structure of
   `create_task_from_audio_tutorial_test.dart`:
   - one `driver.step(id, action)` per YAML step, ids matching exactly;
   - interactions via `driver.tapLikeUser` (cursor glide), waits via
     `driver.pumpUntil*` (records fast-forwardable wait spans), scrolling
     via `driver.scrollIntoView` with a **vertical** scrollable finder;
   - anything that must be SEEN gets asserted via visible widgets, not just
     the DB;
   - wire the `diagnostics` and `onTimeout` hooks for failure screenshots.
3. Iterate with builds; expect the first runs to fail — read the failure
   screenshots, they carry the answer.

## Non-negotiable gotchas

The full list with rationale is in the README's "Hard-won constraints" —
the ones that bite hardest: `flutter drive` not `flutter test` (no window
otherwise); `GDK_BACKEND=x11` + empty `WAYLAND_DISPLAY` (or the app opens on
the real desktop); Voxtral prompts in the audio's language (else it
translates); `automaticUpdatesEnabled` set-and-verify (initial wake clobbers
early writes); 16ms pump cadence during holds (else animations render
choppy); timeline starts after startup settles; assert transcript keywords,
not exact strings.

## Adapting / extending

- **Compositor changes**: all OpenMontage API usage is isolated in
  `tutorial_videos/om_compose_driver.py`; bump the pin in
  `config/openmontage.pin` deliberately and re-verify determinism
  (compose twice, compare `ffmpeg -f framemd5` of the streams — never file
  hashes).
- **TTS vendor**: implement the `TtsEngine` protocol (`tts/base.py`) next to
  `tts/gemini.py`; voices/styles per locale in `config/voices.yaml`.
- **Speed/pacing knobs**: `timewarp.py` (`MAX_SPEED`, lead-in, narration
  gap); per-step floors in the scenario YAML.
- **Character overlay (future)**: render transparent PNG frames via the
  character film-strip harness and composite as an extra layer keyed to
  `timeline.json` step ids.
