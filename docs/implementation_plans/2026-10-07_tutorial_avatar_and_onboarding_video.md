# Tutorial Videos: Talking Avatar, ElevenLabs Narration and the Onboarding Video

Date: 2026-10-07
Status: in progress — Phases 0 and 2 done, Phase 3 builds in English and
German on Ubuntu 24.04 ARM64; Phase 1 waits for an ElevenLabs key
Branch: `feat/tutorial-avatar-prototype`
Builds on: [2026-07-21_tutorial_video_workbench.md](2026-07-21_tutorial_video_workbench.md)
Runbook: `.claude/skills/tutorial-videos/SKILL.md` · Architecture: `tools/tutorial_videos/README.md`

## Goal

From the product call (paraphrased): a face is better than a voice from
off-screen — even a cartoon character talking from a little round badge in the
corner. Start with onboarding: the very first steps, **pasting the Melious API
key, setting up the first category, and getting the first task running**.
ElevenLabs is believed to sound much better than the current voices. Build it,
then come back with options for feedback.

Concretely, the finished state is:

1. Every published tutorial video can carry **Pip** (a cartoon penguin from the
   demo world) in a corner badge, lip-syncing the narrator.
2. Narration can be rendered with **ElevenLabs** or Gemini, and one of them is
   chosen as the default after listening.
3. A new **`onboarding_first_run`** tutorial video walks a brand-new user from
   the welcome screen through Melious key → first category → first spoken task,
   in all 11 locales, desktop and mobile, published and embedded in the manual.

## Where things stand (hand-off from macOS)

Done on this branch (see the commits on `feat/tutorial-avatar-prototype`):

| Piece | Where | State |
|---|---|---|
| Avatar rasterizer + PNG encoder (stdlib-only) | `tools/tutorial_videos/tutorial_videos/avatar/raster.py` | done, tested |
| Pip, the default character; Theo, the onboarding's (2026-10-09) | `avatar/characters.py` (`CHARACTERS`), scenario `avatar:` | done, tested |
| Loudness lip-sync, 4 mouth levels | `avatar/lipsync.py` | done, tested |
| Acting: nods, tilts, brows, glances, breathing | `avatar/acting.py`, layered `avatar/render.py` | done, tested |
| Seeded blinking, pose runs | `avatar/track.py` | done, tested |
| Preview + corner overlay via ffmpeg | `avatar/render.py` | done, tested (incl. 2 real-ffmpeg tests) |
| `avatar-preview` / `avatar-overlay` commands | `avatar/cli.py`, `tutorial_videos/__main__.py` | done, tested |
| ElevenLabs TTS adapter | `tutorial_videos/tts/elevenlabs.py` | done, tested against mocked HTTP only |
| Engine factory + `--tts-engine` flag | `tts/engines.py`, `__main__.py` | done, tested |
| Per-engine voice config | `config/voices.yaml` (`engines.gemini`, `engines.elevenlabs`) | done |
| Docs | `tools/tutorial_videos/README.md` ("TTS engines", "Talking avatar (prototype)"), skill runbook | done |
| Changelog fragment | `changelog.d/2026-10-06-tutorial-video-avatar.md` | done |

Verified so far: Python unit tests (100% line + branch coverage of `avatar/`
and `tts/`), Pip rendered to preview clips, and the overlay on a plain
1920×1080 stand-in frame (frame count unchanged, badge bottom-right).

**Not verified yet** (impossible on macOS or without keys):

- a real ElevenLabs request (no `ELEVENLABS_API_KEY` was available) — the
  default voice ids `JBFqnCBsd6RMkjVDRZzb` (George) and `EXAVITQu4vr4xnSDxMaL`
  (Sarah) came from a third-party list and may not exist on the account;
- Pip on a real recorded tutorial;
- anything that records the app (`build`): it needs Xvfb, x11grab and a
  PulseAudio/PipeWire virtual microphone.

```mermaid
flowchart LR
    subgraph done [Done on macOS]
        A[avatar package\nPip + lip-sync + overlay]
        T[ElevenLabs adapter\n--tts-engine]
    end
    subgraph linux [On Linux]
        P0[Phase 0\nset up + smoke]
        P1[Phase 1\nElevenLabs live + voices]
        P2[Phase 2\navatar into real videos]
        P3[Phase 3\nonboarding video]
        P4[Phase 4\npublish + manual]
    end
    P5[Phase 5\nCI for the Python tests]
    done --> P0 --> P1 --> P2 --> P3 --> P4
    P0 --> P5
```

Phases 1 and 2 are independent of each other and can run in either order;
Phase 3 needs Phase 0 only, but should use the voice and avatar decisions from
1 and 2 before its final renders.

---

## Phase 0 — Linux set-up and smoke test

The original workbench was validated on **Ubuntu 24.04 ARM64** with PipeWire +
`pipewire-pulse`.

### 0.1 Packages and tools

```sh
# Recording, plus the Flutter Linux desktop toolchain and the libraries the
# repo's Linux CI installs (.github/workflows/flutter-linux-release.yml).
sudo apt install xvfb ffmpeg pulseaudio-utils x11-utils python3-venv \
  clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libolm3 libsecret-1-dev libjsoncpp-dev sqlite3 libsqlite3-dev keybinder-3.0 \
  mpv libmpv-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-bad gstreamer1.0-libav
# pulseaudio-utils provides pactl/paplay/parecord (they talk to pipewire-pulse)
ffmpeg -hide_banner -devices 2>&1 | grep -E "x11grab|pulse"   # both must be listed
ffmpeg -hide_banner -encoders 2>&1 | grep -E "libx264|aac"    # both must be listed
# The Matrix encryption plugin (flutter_vodozemac) compiles a Rust crate in
# every Linux build: it needs rustup on the PATH, not just a system rustc.
curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal
```

Flutter through FVM: after pulling, compare `.fvmrc` with `fvm list` and
`fvm install` the pinned SDK first — a missing SDK makes every background `fvm`
call sit on an interactive install prompt. Without root, the fvm install
script (`https://fvm.app/install.sh`) puts it under `~/fvm/bin`.

### 0.2 OpenMontage sibling checkout

Exactly as `tools/tutorial_videos/config/openmontage.pin` says:

```sh
git clone https://github.com/calesthio/OpenMontage.git ../OpenMontage
git -C ../OpenMontage checkout "$(grep ^commit= tools/tutorial_videos/config/openmontage.pin | cut -d= -f2)"
make -C ../OpenMontage setup
```

### 0.3 Secrets (`.env` at the repo root — never committed)

| Key | Needed for |
|---|---|
| `GEMINI_API_KEY` | Gemini narration (current default engine) |
| `MELIOUS_API_KEY`, `MELIOUS_BASE_URL` | transcription + task agent in every scenario; **also typed into the onboarding video** (Phase 3) |
| `ELEVENLABS_API_KEY` | `--tts-engine elevenlabs` |
| `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `R2_PUBLIC_BASE_URL` | publishing only (Phase 4) |

### 0.4 Python environment

The system Python is externally managed (PEP 668). One venv for the tool:

```sh
cd tools/tutorial_videos
python3 -m venv .venv
.venv/bin/pip install pyyaml boto3 coverage
```

`make tutorial_video` calls plain `python3`, so either activate the venv first
or call `.venv/bin/python -m tutorial_videos ...` directly.

### 0.5 Smoke test (in this order)

- [x] `cd tools/tutorial_videos && .venv/bin/python -m unittest discover -s tests`
      — everything passes; the two real-ffmpeg avatar tests now run instead of
      skipping. Only skips allowed: the existing boto3/network ones.
- [x] `.venv/bin/python -m tutorial_videos validate --scenario category_setup --locale en`
- [x] `make tutorial_video TUTORIAL_SCENARIO=category_setup TUTORIAL_LOCALE=en`
      (Gemini, no avatar) — produces `build/tutorial_videos/category_setup_en.mp4`.
      This proves the Linux box can record before anything new is layered on.
      (2026-10-08: 69.4 s, 1920×1080 at 30 fps, six steps.)
- [x] `.venv/bin/python -m tutorial_videos avatar-overlay --video build/tutorial_videos/category_setup_en.mp4`
      — produces `category_setup_en_avatar.mp4`. Watch it end to end.
      (Done: bottom right, Pip sat on the Create button — Phase 2.1 confirmed.)

Two gaps the original list had, both hit on a fresh machine: the Flutter
desktop toolchain packages, and rustup (both added above). And the Gemini
project's prepaid credit must not be empty: a depleted one answers every TTS
request with HTTP 402 `RESOURCE_EXHAUSTED`, which the Gemini adapter still
surfaces as a raw traceback rather than a `TtsError`.

If the build fails, the failure-time screenshots in `build/tutorial_videos/`
(`LOTTI_SCREENSHOT_DIR`) are the first thing to read. The runbook's
"Debugging a failing run" covers the known causes.

---

## Phase 1 — ElevenLabs: verify live, pick voices, pick the default

### 1.1 First live request

- [ ] `.venv/bin/python -m tutorial_videos tts --scenario category_setup --locale en --tts-engine elevenlabs`
- [ ] If it fails with HTTP 404 / `voice_not_found`, the default voice ids are
      not on the account: list the account's voices
      (`GET https://api.elevenlabs.io/v2/voices`, header `xi-api-key`) and put
      real ids into `config/voices.yaml` → `engines.elevenlabs.streams`.
- [ ] If it fails with 422, the response names the offending field — most
      likely a `settings` key; ElevenLabs' `voice_settings` accepts
      `stability`, `similarity_boost`, `style`, `speed`, `use_speaker_boost`.
- [ ] Clips land in `build/tutorial_videos/tts_cache/` — listen to them.

### 1.2 Voice auditions (needs the stakeholder)

The call said voice samples would be shared separately. For each candidate:

- [ ] render `category_setup` narration in `en` and `de` (the longest locale)
      with the candidate voice id;
- [ ] judge: natural German/French/Czech pronunciation (multilingual_v2 reads
      the language off the text — check it does not carry an English accent
      into other locales), pace against the video, and that the `user_voice`
      is unmistakably a different person from the narrator.

Tuning knobs, in `voices.yaml` per stream: `stability` (lower = livelier,
less consistent), `similarity_boost`, `style`, `speed`. Every change is a new
cache key, so old clips are never reused by mistake.

### 1.3 Decide the default engine

- [ ] If ElevenLabs wins, set `engine: elevenlabs` in `config/voices.yaml` and
      update `tests/test_tts.py::LoadVoicesTest.test_defaults_to_gemini_with_a_style_per_locale`
      (it pins today's default), plus `test_main.py::TtsCommandTest.test_uses_voices_yamls_default_engine`.
- [ ] Re-render every published scenario × locale with the new voices before
      publishing any of them, so the manual never mixes two narrators.
- [ ] Note the per-character cost of a full re-render (11 locales × all
      scenarios) before kicking it off.

---

## Phase 2 — Put the avatar into real videos

### 2.1 Placement on real UI (do this first — it may change the design)

**Decided 2026-10-08: top right, as the default for every device.** The badge
sat bottom-right at 22% of the video height, and on real screens that corner
is busy:

- **Desktop**: create buttons and floating action buttons can sit near the
  bottom-right — the badge may cover the very control the cursor clicks
  (check `create_task_from_audio` and `category_setup` first: both click a
  create action).
- **Mobile**: the bottom navigation runs along the bottom edge.

- [x] Render the overlay onto `category_setup` desktop and grab frames at
      each step (`ffmpeg -ss <t> -frames:v 1`): at 25 s the badge covered
      the Create button. The other scenarios and mobile still want a look
      (2.5).
- [x] The corner is configurable: `POSITIONS` in `avatar/render.py`
      (`top_right` default, `top_left`, `bottom_right`, `bottom_left`),
      `--position` on `avatar-overlay`, `--avatar-position` on `build`, each
      corner's overlay expression tested. Not per scenario: nothing asked for
      it yet, and a YAML field is a ten-line change when one does.

### 2.2 Pip must only lip-sync the narrator

`avatar-overlay` reads `<stem>.narration.wav`, which `compose.py` mixes from
the narrator clips **and the dictation clip** (the "user" speaking into the
app) — so Pip currently mouths the user's voice too.

Fixed: Pip's level track comes from the narrator clips alone, placed where
`compose.py` places them:

- [x] `avatar/narration_track.py::narration_levels(manifest, timeline, fps)`
      runs the same `timewarp.plan_segments(timeline, durations)` as
      `compose.py` and `captions.py`, and for each timeline step drops
      `frame_levels(narration_clip, fps)` at
      `round(output_time(segments, step.start) * fps)`; overlapping clips take
      the louder value; dictation clips are never read.
- [x] `avatar-overlay` gained `--manifest` and `--timeline` (defaults derived
      from the video stem by `avatar/cli.py::sidecar_paths`: the manifest is
      shared across devices, so a `_mobile` suffix is stripped for it, the
      timeline keeps the stem); `--narration` forces a WAV, and a video with
      none of those falls back to `<stem>.narration.wav`.
- [x] Tests (`tests/test_avatar_narration_track.py`, `tests/test_avatar_cli.py`):
      a clip lands at its warped offset; the dictation span stays silent and
      its clip is never opened; two overlapping clips either way round; a
      step without narration; a clip past the total; a `_mobile` stem finds
      the shared manifest; a named-but-missing build file is an error, not a
      silent fallback.

### 2.3 Loudness reference over speech only

`mouth_track` judges each frame against the 95th-percentile loudness of the
**whole** track. In a real tutorial much of the timeline can be silence
(fast-forwarded waits): if speech covers less than ~5% of frames the
reference becomes the silence level and the mouth either never opens or
opens on noise.

- [x] The reference is computed over frames above `NOISE_FLOOR` (0.01)
      only, with regression tests of mostly-silent input (speech in 3% of
      frames opens the mouth fully) and of sub-floor hiss (never opens it) —
      both re-run with the fix reverted and failing.

### 2.4 Make the avatar part of `build`

- [x] `build --avatar` (and `make tutorial_video TUTORIAL_AVATAR=1`): after
      the captions, `avatar/cli.py::overlay_in_place` renders into a
      temporary file and `os.replace`s it over `<scenario_locale>.mp4`, so
      captions, publish and the docs site need no change. Covered by
      `tests/test_main.py::BuildCommandTest` with the recording stubbed.
- [ ] Decide with the stakeholder whether the avatar becomes the default;
      until then it is opt-in.
- [x] README ("Talking avatar") and runbook updated; "prototype" dropped,
      since the sync, the corner and the build hook are no longer provisional.

### 2.5 Visual sign-off

- [ ] One desktop and one mobile video with Pip, reviewed by the stakeholder:
      size, corner, readability of the beak at 22% height, blink rate,
      whether the teal ring matches the docs site. (The first desktop cut,
      bottom-right, was reviewed on 2026-10-08 and moved Pip to the top
      right; the top-right cut and mobile are still to review.)
- [ ] Optional polish from feedback (all in `avatar/characters.py` /
      `track.py`): idle motion (a slow 1–2px bob), a slightly larger badge on
      mobile, entry/exit fade at the video's start and end.

---

## Phase 3 — The onboarding video (`onboarding_first_run`)

This is the main deliverable from the call. It records the **real** first-run
flow (`lib/features/onboarding/ui/onboarding_welcome_modal.dart`, steps
`welcome → connect → apiKey → success → recordingStyle → category → firstTask`)
in an app with no AI provider configured.

### 3.1 How the flow works today (verified in code)

- The welcome auto-shows from `MyBeamerApp` (`lib/beamer/beamer_app.dart`,
  `_showOnboardingWelcome`) when `shouldAutoShowOnboardingProvider` resolves
  `true`. The tutorial harness **forces it to `false`**
  (`integration_test/tutorial/tutorial_harness.dart`, `providerOverrides`).
- The API-key step (`onboarding_api_key_panel.dart`) runs a **live connection
  probe** against the provider as the key is typed; the Connect button only
  enables once the probe returns verified. Connecting saves the provider,
  revives its bundled inference profile, and runs the FTUE setup
  (`runFtueSetupForType`) that seeds models and profiles.
- The category step creates the chosen areas and switches on automatic
  transcription for them (`knowledge/features/onboarding.md`, "Where the
  consent flag is written").
- The first-task step (`onboarding_first_task_step.dart`) records through the
  shared capture controller — the same mic → transcription path the
  `create_task_from_audio` scenario already drives with the virtual mic — and
  structures the transcript into a real task.

### 3.2 Harness changes (`integration_test/tutorial/tutorial_harness.dart`)

- [x] `autoShowOnboarding` (default `false`) on `setUp`;
      `providerOverrides()` returns it from `shouldAutoShowOnboardingProvider`.
      Every existing scenario keeps today's behaviour.
- [x] The scenario boots with `aiConfigs: const []` — no provider, exactly
      what a first run sees.
- [x] `seedDemoWorld: false`: a genuinely empty first-run app. The empty
      Tasks tab ("No tasks match your search", "Try the demo") sits dimmed
      behind the modal and reads fine.
- [x] The onboarding metrics store is **registered by the harness** now
      (`OnboardingMetricsDb` in memory + `OnboardingMetricsRepository`, as
      `get_it.dart` wires them): the first-task structuring service reads
      the repository from getIt and the run died without it. The cadence
      writes go to the in-memory `SettingsDb`.
- [x] The onboarding flow's built-in Melious base URL
      (`ProviderConfig.defaultBaseUrls`) is `https://api.melious.ai/v1`,
      the same as `MELIOUS_BASE_URL` — the probe verified on camera.

### 3.3 Scenario YAML (`tools/tutorial_videos/config/scenarios/onboarding_first_run.yaml`, new)

Schema as documented in `create_task_from_audio.yaml`. Proposed steps (ids are
the contract with the Dart test):

| Step id | On screen | Narration intent |
|---|---|---|
| `welcome` | the welcome modal appears | what Lotti does: speak a thought, get a task |
| `choose_brain` | tap "Choose your AI brain" | Lotti needs an AI provider to understand you |
| `pick_melious` | tap the Melious tile | why Melious (one key, transcription + thinking) |
| `paste_key` | key typed into the obscured field; probe shows verified | paste your key — it stays hidden and on your device |
| `connected` | success view → continue | you're connected |
| `recording_style` | pick a style → continue | how recording looks |
| `choose_areas` | select area chip(s) → continue | categories keep areas of life apart; transcription is on for them |
| `first_task` (`dictation: true`) | tap record, user voice plays into the mic, stop | say what you need to do |
| `task_appears` | transcript → structured task (fast-forwarded wait) | Lotti turns it into a task |
| `outro` | the task is open | that's it — next: categories, checklists |

- [x] `title`, `dictionary`, `narration` and `dictation_text` for all 11
      locales: `en de fr it es cs nl ro pt da sv`. Informal register
      everywhere; **Romanian is the deliberate formal exception**. All eleven
      built desktop on 2026-10-09 (1:23–1:42 each), each ending on its task
      in the right language.
- [x] **Review changes (2026-10-09):** the recording-style step left the
      onboarding flow in the app itself — fewer choices; the VU meter stays
      in Settings → Recording Style (widgets, tests and three labels deleted,
      manual page updated in all 11 languages, changelog fragment). And the
      cursor glide is now paced by the recorded clock (`cursorGlide`, 500ms):
      the frosted-glass category screen drew so slowly under Xvfb that a
      fixed 22-frame glide took seconds. The English cut went 2:17 → 1:24.
- [x] The dictated sentence ("Order sardines for Friday's emperor penguin
      roll call, and check the zero-gravity feeder before they arrive")
      produced the task "Order Friday sardines and check zero-gravity
      feeder" with the transcript on it — a title, **no checklist**: the
      structuring kept both actions in the title. A more list-shaped
      sentence ("three things: …") may get one; decide after review.
- [x] Nothing is said about the key's value; the field only ever renders
      dots (frame at 37 s: dots + "Connection verified").

### 3.4 Scenario test (`integration_test/tutorial/onboarding_first_run_tutorial_test.dart`, new)

Model it on `category_setup_tutorial_test.dart` (boot, cursor layer, HUD,
manifest-paced `driver.step(...)`) and `create_task_from_audio_tutorial_test.dart`
(the mic: `driver.speakIntoMic`, transcript waits).

- [x] The key comes from `Platform.environment['MELIOUS_API_KEY']`, is
      entered in one go with `tester.enterText`, and the test `pumpUntil`s
      the probe's verified state before tapping Connect.
- [x] The visibility toggle is never tapped; `obscureText` is asserted
      `true` right before and after typing.
- [x] Finders read the catalogue directly (`lookupAppLocalizations(locale)`)
      instead of a hand-kept per-locale map, scoped to the step's panel
      key (`onboarding-<step>`). One trap found: the category chips lie
      under a full-size invisible `InkWell`, so their labels never
      hit-test — the chip is tapped at its label's centre without the
      `hitTestable` filter.
- [ ] Mobile: check how the welcome modal lays out at the phone's 402px
      logical width (sheet vs. dialog) and branch on
      `tutorialDeviceIsMobile()` only where the real UI differs.
- [x] The network waits (probe, FTUE setup, structuring) go through
      `pumpUntil` — **not** `pumpUntilFound`, which records no wait span:
      the first English cut used it and nothing was fast-forwarded.

### 3.5 Secret safety (the video is public)

- [ ] The key is only ever rendered as dots; check every step's frame
      before publishing (`ffmpeg -ss <t> -frames:v 1`).
- [ ] grep the build outputs (`*.timeline.json`, `*.manifest.json`, `*.vtt`,
      failure screenshots, logs) for the key value — must find nothing.
- [ ] Prefer a dedicated demo Melious key for recordings, so it can be
      rotated without touching anyone's own setup.

### 3.6 Build, review, iterate

- [x] `validate` for `en` and `de`.
- [x] `make tutorial_video TUTORIAL_SCENARIO=onboarding_first_run TUTORIAL_LOCALE=en TUTORIAL_AVATAR=1`
      (2026-10-09: 137 s, Gemini, Pip top right). Mobile still to do.
      Later on 2026-10-09 the onboarding switched to Theo (`avatar: theo`);
      the desktop locales were re-composed from their captures and given
      Theo, without re-recording.
      Then the badge learned to act (`avatar/acting.py`): nods, per-phrase
      head tilts, brow lifts, breathing, glances at the app in pauses —
      rendered as moving layers through ffmpeg `sendcmd`, still a few dozen
      drawn images per video.
- [ ] Review against the runbook's checklist: cursor glides, HUD clock
      top-centre, key obscured, transcript and task visible, narration audible
      at each step start, duration ≈ warped timeline total, Pip not covering
      what is being clicked. Seen so far: Pip covers the task page's
      top-right header icons on the final screen (nothing the cursor
      clicks, but a sign-off item for 2.5).
- [x] Then `de`, then all locales. One Romanian run came out with the
      picture a minute behind the narration: x11grab drifted 29% off the
      app's clock. `compose.py` now refuses such a capture
      (`check_capture_length`); a rebuild was in sync.

---

## Phase 4 — Publish and embed

- [ ] `make tutorial_video_publish TUTORIAL_SCENARIO=<s> TUTORIAL_LOCALE=<l>`
      for each scenario × locale, and again with `TUTORIAL_DEVICE=mobile`.
      Publishing uploads captions (`.vtt`) alongside when present.
- [ ] Embed the onboarding video with `<TutorialVideo scenario="onboarding_first_run" … />`
      in `docs-site/docs/getting-started/onboarding.mdx` and its translations
      under `docs-site/i18n/<locale>/docusaurus-plugin-content-docs/current/getting-started/onboarding.mdx`
      (see `docs-site/docs/getting-started/first-task.mdx` for the pattern).
      The `maintain-docusaurus-manual` skill covers locale parity.
- [ ] If Phase 1 changed the voices, re-publish every existing scenario so the
      manual has one narrator throughout.
- [ ] Update `tools/tutorial_videos/README.md` (scenario list, avatar no
      longer "prototype") and the changelog fragment — fragments only describe
      what a user will notice, so word it around the published videos.

---

## Phase 5 — CI for the tutorial-video Python tests

The workbench's `tests/` have never run in CI (`.github/workflows/python-tools-ci.yml`
covers other tools only).

- [ ] Add a job: Python 3.12+, `pip install pyyaml coverage`, `apt install
      ffmpeg` (so the real-ffmpeg avatar tests run rather than skip), then
      `cd tools/tutorial_videos && python -m coverage run --branch -m unittest discover -s tests`
      and fail under 100% for `tutorial_videos/avatar` and
      `tutorial_videos/tts` (`coverage report --include=... --fail-under=100`).
- [ ] No network: the TTS tests patch `urllib.request.urlopen`; keep it that way.

---

## Phase 6 — Optional: timing-accurate lip-sync

ElevenLabs offers a with-timestamps variant of the same endpoint that returns
per-character start/end times. Mapping characters to mouth shapes (vowels open,
m/b/p closed) would make the beak follow speech rather than loudness. Only
worth it if the stakeholder finds the loudness sync unconvincing in Phase 2.5;
it would feed the same per-frame mouth track, so the renderer does not change.

---

## Decisions needed from the stakeholder

| Decision | Phase | Default if nobody answers |
|---|---|---|
| ElevenLabs voices (narrator, user voice) | 1.2 | keep George / Sarah if they exist on the account |
| Default engine: ElevenLabs or Gemini | 1.3 | Gemini |
| Avatar corner per device | 2.1 | **top right** (decided 2026-10-08), overridable per run |
| Avatar on by default in every video | 2.4 | opt-in |
| Re-render existing scenarios with Pip / new voices | 1.3, 4 | only after both above are decided |
| Dedicated demo Melious key | 3.5 | ask before recording |

## Definition of done

- [ ] All 11 locales × desktop + mobile of `onboarding_first_run` built,
      reviewed, published, embedded on the onboarding manual page.
- [ ] Pip appears in every published tutorial, lip-syncing only the narrator,
      never covering the clicked control.
- [ ] One narration engine and voice pair across all published videos.
- [ ] Workbench tests green in CI with 100% coverage of `avatar/` and `tts/`.
- [ ] README, runbook and changelog fragment describe what actually shipped.

## Working rules carried over

- Run only the tests for files you touched (CI runs the rest).
- Every regression test is re-run with its fix reverted and must fail.
- `fvm flutter test`/`drive` rewrites `lib/l10n/app_localizations_*.dart` and
  touches `ios/Podfile.lock`: `git checkout --` them before committing.
- Never run more than two `fvm flutter test`/`drive` processes at once in one
  checkout (hooks-runner lock timeouts).
- No secrets in commits, logs, screenshots or published frames.
