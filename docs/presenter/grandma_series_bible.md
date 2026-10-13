# Lotti: the grandma video series bible

The reference for anyone, human or agent, continuing the Lotti presenter videos: the grandma series, its locked character rules, the episodes so far, the engine, and how to add a character without breaking her. Last updated 2026-10-13.

Code lives in `tools/tutorial_videos/presenter/` (episodes) and `tools/tutorial_videos/config/` (voices, scenarios). The engine's own manual is `tools/tutorial_videos/presenter/README.md`.

---

## 1. Working rules for this series

- **Agree before building.** A new episode, script, character or voice is the series lead's call (the contributor who directs these videos). Show a draft (script, look, voice candidates) and get a yes before rendering.
- **Voices are picked by ear.** Never change a voice without the series lead hearing the candidates first.
- **Check the rendered video, not just the inputs.** Pull frames from the finished MP4 across every section. Every app screen must stay up long enough to read while she talks about it.
- **Repo rules still apply** (`AGENTS.md`):
  - release notes go in `changelog.d/`;
  - use `fvm` for Flutter;
  - zero analyzer warnings;
  - test only the files you touched;
  - never commit secrets (the API keys live in the repo `.env`).

---

## 2. What the series is

**Lotti** is an open-source, private "system of record for your life": notes, voice, tasks, habits, agents. It lives on your own devices, with no cloud and no telemetry.

The app is named after the maker's real grandmother, Lotti (`docs/BACKGROUND.md`: she was 92, from Hamburg, and kept handwritten travel journals). **The videos never tell her personal story.** The series lead cut that on 2026-10-11.

**The series star is "Lotti", a cartoon grandmother who presents the product.** Two episodes exist so far:

| # | Production | What it is | Her look | Output |
|---|---|---|---|---|
| 1 | `pitch` | **The onboarding video.** She walks a new user through the first minute of the real app: pick an AI brain, paste a key, choose areas, dictate the first task, Laura the task agent suggests, confirm, plus interruptions and privacy. Real recorded app footage plays on a phone beside her. About 129 s. | `grandma` (onboarding outfit) | `presenter/build/lotti_pitch.mp4`, `lotti_pitch_portrait.mp4` |
| 2 | `founder` | **The investment ad.** She rides a **skateboard** down a daylight, tree-lined road the whole time, pitching the product. App screenshots appear as cards and numbers count up. On the closing name she brakes, a **rock costume** lands, the road wipes to a **cobalt sunburst poster**, and she **throws the horns**. About 128 s. | `grandma_stage` while riding → `grandma_rock` at the end | `presenter/build/lotti_founder.mp4`, `lotti_founder_portrait.mp4` |

(The production is called `founder` because a founder look-alike presented it first. The series lead replaced him with the grandma; see §5.)

**Planned next (the series lead's words):**
- "continue a series sequence of the grandma";
- **later bring other characters/avatars into the ads**;
- a future **two-hander ad**: the grandma together with the founder character, with "a thoughtful and marketable storyline".

Also on the roadmap, as a separate track (not video): an **in-app talking avatar** (`docs/implementation_plans/2026-10-12_in_app_agent_avatar.md`). It's plain Flutter/Dart, reusing the `dancing_cats` engine, and the series lead wants **customisable characters "like in a game": grandma, cat, red panda**.

---

## 3. The grandma: character bible (LOCKED unless the series lead says otherwise)

### Identity
- She is "Lotti", the grandmother the app is named after: sharp and energetic, a "grandma in tech" vibe, confident like a founder on stage.
- **She is never the app.** She talks *about* Lotti in the third person: "Lotti's listening", "not even the people who make Lotti".
  - **Never** write a line where "I" or "me" could read as the app.
  - The series lead rejected "not even me, Lotti": "the oldma should call her lotti".
- Small presenter asides about herself are fine ("I checked.", "I'll wait.", "I have seen twenty. It is not pretty."). Her life story is not.
- **Her name is spelled and spoken plain "Lotti"** in every script. No respelling ("Law-tee", "Lottie", "Lah-tee" were all tried and rejected). The series lead picked plain "Lotti": "exactly!!!!!!".

### Voice (LOCKED)
- **ElevenLabs "Eleanor"**, voice id `2qQJWjw5XdG80GreshqG`: an older British woman, gracious and authoritative.
  - Model `eleven_multilingual_v2`, stability 0.6, similarity 0.75, **style 0** (style > 0 makes stressed words jump), speed 1.0.
  - Configured in `tools/tutorial_videos/config/voices.yaml` → `engines.elevenlabs.streams.presenter`.
  - Each production sets `TTS_ENGINE = "elevenlabs"`.
- **History, so you don't repeat it:**
  - Gemini **Aoede** was the first pick, then judged **shrill** (median about 290 Hz). It's kept only as the Gemini fallback.
  - **Carol** rose on emphasised words; rejected.
  - The series lead heard seven English female voices one by one and picked Eleanor.
  - Check pitch with a YIN tracker; crude autocorrelation gives fake 400+ Hz spikes.
- **Never change her voice without the series lead hearing the candidates first.**

### Writing style (LOCKED)
- Professional, with **"1%" humour**: a handful of lines get one short, deadpan sentence ("I checked.", "No traffic, for once."). At most one touch per two lines, and never at the viewer's expense.
- One short sentence per beat. The product is the subject.
- The **ending beats of the onboarding** (summary, privacy, close) are liked as they are.
- **The investment ad never uses the first person**; it's about the product.
- Every number in the ad comes from the README:
  - 50 TLA+ models checked nightly
  - 35,000 tests at 99.9% coverage
  - 11,000 hours of the maker's work
  - EU zero-retention provider, bring your own key, or local hardware
  - cost, energy and carbon shown per request

### Looks (`tools/tutorial_videos/presenter/narrator/looks.py`)

All three outfits share **one face and hair**: grey/silver hair in a soft low bun, fair skin, round glasses, pearl earrings, laugh lines.

| Look | When | Outfit |
|---|---|---|
| `grandma` | The onboarding (episode 1) | Tailored **teal dress**, **mustard cardigan**, small scarf, dark burgundy Mary Janes. Colours are the palette module's defaults, sampled from her reference drawing. |
| `grandma_stage` | The investment ad, while riding | **Raspberry dress** (`#b8336a`), **ivory cardigan** (`#efe6d6`), **teal scarf** (`#1f7f8a`), **navy shoes**. **It must differ from the onboarding outfit** so the ad isn't "the onboarding in other words". The series lead ruled out reusing the onboarding clothes and the reference photo's clothes. |
| `grandma_rock` | The investment ad's last beat | **Red beret**, **yellow square sunglasses**, **red lips**, beads, a **red glove** on the hand that throws the horns, a **yellow top** with red piping, white shoes, disc earrings. Her face and hair stay. |

A new look is one more `Look(...)` built from `GRANDMA.colours` (or another look's) with overrides, added to `LOOKS`. The rig reads colours through `palette.use`.

### Body and motion (LOCKED: the reviewer's fixes)
- Arms are **ribbons from inside the torso** with **constrained elbows** (`narrator/arm.py`, `narrator/ribbon.py`).
  - No hinge shoulder, no "blocks of wood" arms, no outward "X" arms.
  - The thumb is grown out of the palm.
- The blueprint is the app owner's own Flutter project **`matthiasn/dancing_cats`** (its `docs/animation/`): limb ribbons, a skinned trunk, joint limits, and an anti-fold rule. **For any rig or motion work, read dancing_cats first and reuse its approach. Don't invent a new one.**
- Review arm poses with a contact sheet of every gesture.
- **Gestures** (`narrator/gestures.py`) include open_small, open_both, present_R/L, chest, chest_both, one, two, palms_down, palms_shake, think, speak, sweep, thumbs, horns, celebrate, and others. Check the file for the full list.
- She **rides** via `narrator/ride.py` with `RIDE = {"stop": (step, word, offset), "brake": s}`.
  - Push period 3.6 s.
  - `COSTUME = (step, word, offset, look)` swaps her look on a word.
  - `POSTER = True` gives the cobalt poster. **Yellow was rejected as "lousy".**

---

## 4. The engine: how an episode is made (`tools/tutorial_videos/presenter/`)

**Python + cairo**, not Flutter. Every frame is drawn in Python.

- **A production** is `narrator/productions/<name>.py`. It sets:
  - `CAST`: `Member(look, stream, place, facing, scale)`, where `stream` is a voice stream in `config/voices.yaml`;
  - `STEPS`: per line, the camera, gestures keyed to words, props and cards, gaps;
  - the phone and footage (`SHOTS`, `PHONE_SHOW`/`PHONE_HIDE`);
  - `SCENERY` (`"stage"` | `"road"`), `RIDE`, `COSTUME`, `POSTER`;
  - title and end cards (`KICKER`, `HEADLINE`, `TITLE`, `END_PILLS`);
  - layout overrides.
- **A script** is `assets/<name>/script.json`. Each step has an `id` and its `text` (captions). An optional `say` is what's actually spoken.
  - **Durations are measured, never typed.**
  - Everything in the production is keyed to a lowercased word of `text`, with `word#2` for the second occurrence.
- **Productions are chosen** with `PRODUCTION=<name>` (default `pitch`).
- **Commands** (from `tools/tutorial_videos/presenter/`):
  ```sh
  make setup                        # once: .venv, Vosk model, Rhubarb
  make all                          # narration -> words -> mouth cues -> both overlap checks -> both videos
  make video / make video_portrait  # 1920x1080 / 1080x1920
  make preview                      # half-res quick review
  make sheet T=20,40,60             # stills for review (sheet_portrait for the other frame)
  PRODUCTION=founder make shots all # the ad: fetch its product screenshots first (never committed)
  ```
- **The overlap check** (`make check` and `check_portrait`) must be clean: no hand over a card's text or over the phone's screen. Fix it with a shorter gesture or by moving a card.
- **Tests:**
  ```sh
  cd tools/tutorial_videos && PRODUCTION=<pitch|founder> PYTHONPATH=tests presenter/.venv/bin/python -m unittest tests.test_presenter tests.test_tts tests.test_tts_engines tests.test_tts_elevenlabs
  ```
- **Phone footage for the onboarding** is real app footage, recorded with:
  ```sh
  make tutorial_video TUTORIAL_SCENARIO=onboarding_first_run TUTORIAL_LOCALE=en TUTORIAL_DEVICE=mobile
  ```
  (run at the repo root). That produces `build/tutorial_videos/onboarding_first_run_en_mobile.warped.mkv`.
  - **If you re-record it, re-time `SHOTS` in `pitch.py`** from its `.timeline.json`.
  - Current timeline: welcome 0–11.5, choose_brain –17.9, pick_melious –24.8, paste_key –33.2, connected –37.6, choose_areas –48.2, first_task 48.2–67.6 (dictation 58.6–65.7), task_appears 67.6–78.7, confirm 78.7–96.0, outro 96.0–105.6.
  - Current SHOTS: speak `56.76→67.5`, laura `71.0→78.6`, confirm `91.6→98.9`.
- **The onboarding's dictated task** (realistic, no penguins) is "Call the dentist to move Thursday's appointment, and pick up milk and bread on the way home." It's in all 11 locales in `config/scenarios/onboarding_first_run.yaml`.
- **The recording modal** (the new one from main) is a red pill with a timer, found by `ValueKey('stop_recording')`. There's no "Stop" text.
- **Different system, don't confuse them:** the **tutorial-video avatars** in `tools/tutorial_videos/avatar/` (`CHARACTERS`: **Pip** the penguin by default, **Theo** for the onboarding scenario) are small corner badges on tutorial videos. They're not the grandma presenter.

---

## 5. Other characters: what exists and how to add more

### The founder (kept on purpose: DO NOT DELETE)
- **Look** `founder` in `looks.py`: a fair-skinned man in his fifties, short tousled blond hair, a short beard greying at the chin, blue-grey eyes, no glasses, a dark tee under an open blue-and-white plaid shirt, jeans, dark trainers.
- **Voice stream** `founder` in `config/voices.yaml`: Gemini **Charon**, a calm, warm keynote style. There's no ElevenLabs voice for him yet, so pick one **by ear with the series lead** when he comes back.
- **History:** he presented the investment ad first. The series lead's side said the storyline was fine but the presenter should be the humorous grandmother, and **an owner look-alike must never present as the owner**.
- He's kept for the **future two-hander ad**. When it comes, reuse the look and stream; don't redraw him.

### Adding a character (the safe path)
1. Agree the character with the series lead first: who they are, their look, their role. Don't present a real person as themselves.
2. Add a `Look(...)` to `looks.py`, reusing the rig. A new body type means rig work: read dancing_cats first.
3. Give them a voice stream in `config/voices.yaml` (`engines.elevenlabs.streams.<name>`). **Let the series lead pick the voice by ear**: play English candidates one clip at a time. ElevenLabs refuses to design child or teen voices (403 `blocked_generation`); never try to get around it.
4. Add them to the production's `CAST` with `place`/`facing`, and give each script step a `speaker`.
5. For two people on stage, the pattern to copy is SierraTuff's `family.py` (two members, `facing`, `reactions`, `to_camera`, plus the new `to_phone` look) in SierraTuff's `tool/pitch_video/` (a sibling project on the same engine family).
   - SierraTuff's engine is the same family and is **ahead of Lotti's** on several things: `Member.engine` per cast member, `to_phone` looks, phone zoom with pinned UI, aligner sound-alike folding.
   - **Port what you need; don't hand-copy blindly.** Lotti's `Member` uses `stream`; SierraTuff's uses `voice`/`style`/`engine`.

### Ideas the series lead has floated (for planning, not built)
- The grandma and the founder in one storyline-driven ad.
- Other avatars in the ads (cat, red panda, matching the in-app avatar plan).
- Keep each episode's outfit distinct, and keep her face, hair, voice and name constant.

---

## 6. State at the time of writing (2026-10-13)

- **Branch:** `feat/onboarding-guided-first-task`, rebased onto `main` on 2026-10-12.
- **Committed:** the in-app avatar plan (`docs/implementation_plans/2026-10-12_in_app_agent_avatar.md`, pushed) and this bible.
- **Still local, not committed yet:**
  - the onboarding feature work;
  - the l10n changes;
  - the tutorial-test fixes for the new recorder (`ValueKey('stop_recording')`);
  - the scenario's realistic dictation;
  - the `tools/tutorial_videos/presenter/` engine itself.
  If a path named here is missing from your checkout, that work hasn't landed yet. Ask before recreating it.
- **Latest renders** (in `tools/tutorial_videos/presenter/build/`, never committed):
  - `lotti_pitch.mp4` and `lotti_pitch_portrait.mp4` (129 s)
  - `lotti_founder.mp4` and `lotti_founder_portrait.mp4` (128.3 s)
- `make knowledge_check`'s Mermaid gate fails on a Node 18 machine (jsdom 29 needs a newer Node). That has nothing to do with this work.

---

## 7. Current scripts (so a new episode keeps continuity)

**Episode 1, onboarding (`pitch`).** Step ids: hook, first_minute, the_key, areas, speak, laura, interrupted, privacy, close.
- Opens: "Meet Lotti, a private assistant that remembers for you, so you don't have to…"
- Humour beats: "I checked.", "Go on, I'll wait.", "I have seen twenty. It is not pretty."
- `areas` mentions "the gym you keep meaning to visit".
- Closes: "Lotti. Your memory, kept by you. Free and open source, on your phone and your computer. Go on, say something. Lotti's listening."

**Episode 2, investment ad (`founder`).** Step ids: hook, built, tour, record, sync, agents, brain, proof, why, close.
- Opens: "Everything you tell your phone today ends up on somebody else's computer…"
- Key lines: "Lotti exists so that stops.", "Agents propose. You decide."
- `proof` has a `say`: "T L A plus".
- Closes: "Lotti. Open source. On your phone and your computer. Your memory, kept by you." She brakes on "Lotti", the costume and poster land, and she throws the horns on "memory".
- Title card: "A SYSTEM OF RECORD FOR YOUR LIFE" / "Your memory, kept by you."

---

## 8. Don'ts (the wrong moves to avoid)

- Don't respell "Lotti". Don't make her the app. Don't tell the real grandmother's life story.
- Don't change her voice, face, hair or name between episodes. Give each episode its own outfit instead.
- Don't reuse the onboarding outfit in an ad. Don't use a yellow poster.
- Don't delete the `founder` look or the Charon stream as "unused".
- Don't let an owner look-alike present as the owner.
- Don't hand-roll arm or rig fixes. Follow dancing_cats.
- Don't swap voices without the series lead hearing the candidates.
- Don't commit, push or open the PR without the series lead's word.
- Don't confuse the presenter grandma with the tutorial corner avatars (Pip, Theo).
- Don't claim app features or numbers the code or README doesn't back.
