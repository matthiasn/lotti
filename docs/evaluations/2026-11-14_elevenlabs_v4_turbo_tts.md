# ElevenLabs v4 Turbo for reading aloud

*Evaluation, 2026-11-14, against `main` at `f1c06323fe` (1.1.101) with the
streamed playback of #5084. All timings are live calls from the build
machine; nothing here is a vendor figure unless it says so.*

Reading aloud felt slow. This document measures why, compares ElevenLabs'
new **Eleven v4 Turbo** (`eleven_v4_turbo`) with `eleven_v3`, `eleven_v4`,
the two v2 models lotti already offers and Mistral's Voxtral, and records
what the same change adds to the app.

**Short version.** The wait was never the model: lotti asked every cloud
voice for a *whole* clip and played it once it had arrived, so the wait grew
with the text — up to 4 s on Voxtral, 6 s on v3 or v4. Streamed, every
model starts within 0.7 s, and **v4 Turbo's first audio arrives 130–200 ms
after the request, whatever the length of the text** — ElevenLabs' ~150 ms
claim holds from here. In lotti, which starts once two seconds of audio
are written, the clip is **playable after 0.29–0.43 s** (when a device
player then sounds it was not measured, §10). v4 Turbo is also
the most expressive of the models measured (§5). **Recommendation: adopt v4
Turbo, streamed, as the ElevenLabs read-aloud model** (§9). It is in this
change: ElevenLabs now streams through #5084's pipeline, and v4 Turbo is
the first curated ElevenLabs model.

## 1. What lotti does today

| Voice | How it is asked | What the listener waits for |
|---|---|---|
| On-device Supertonic (`SupertonicOnnxEngine`) | synthesizes the whole text locally | the whole synthesis; not measured here (§10) |
| Voxtral, `main` | `POST audio/speech`, whole WAV in JSON | the whole clip |
| Voxtral, #5084 | `stream: true`, server-sent WAV pieces into a `GrowingSpeechClip` | two seconds of audio, or the end of a shorter clip |
| ElevenLabs, `main` | `POST text-to-speech/{voice}?output_format=wav_24000` | the whole clip |
| ElevenLabs, this change | `POST …/stream?output_format=pcm_24000` into the same `GrowingSpeechClip` | as Voxtral streamed |

Which voice speaks is the *Read aloud* slot of the profile that resolves for
the surface ([TTS concept](../../knowledge/features/tts.md#which-voice-speaks)).
An ElevenLabs model is chosen by `model_id` alone, so A/B testing two models
is switching that slot, or `--models a,b` in the benchmark.

## 2. Method

- **Tool:** [`tool/benchmarks/tts_latency.dart`](../../tool/benchmarks/tts_latency.dart),
  `dart:io` only; one warm `HttpClient`, as the app keeps one. Raw results:
  [`all_modes.json`](tts_latency_2026-11-14/all_modes.json) (3 runs of every
  cell), [`streamed_playable.json`](tts_latency_2026-11-14/streamed_playable.json)
  (2 further runs of the streamed cells, with the point lotti starts playing).
- **Texts** (fixtures, nothing personal): *short* "Nothing is overdue." (19
  characters), *conversational* (111), *long* (452, ~28 s of audio).
- **Voice:** Sarah (`EXAVITQu4vr4xnSDxMaL`) for ElevenLabs; the first English
  preset for Voxtral, as lotti's default resolves.
- **First audio** is the first byte of audio — past the WAV header — after
  the request was sent. **Playable in lotti** is when two seconds of audio
  had arrived (`GrowingSpeechClip.playableBytes`), or the stream ended.
  **Pre-roll needed** is the longest a player started at the first byte would
  have starved; it was 0 ms in every streamed run, for every model.
- **Baseline:** a warm `GET /v1/models` took 204–233 ms, so the 130 ms first
  audio of the fastest models is at the network floor from this machine.
- No server-side caching: the first run of each identical request was as
  fast as the later ones, and the audio lengths differ run to run.

## 3. Latency

### 3.1 What the listener waits for (medians)

Whole clips: the full request. Streamed: *playable in lotti*.

| Voice | Mode | Short | Conversational | Long |
|---|---|---|---|---|
| Voxtral (`main`) | whole | 469 ms | 1,023 ms | 3,893 ms |
| Voxtral (#5084) | streamed | 354 ms | 500 ms | 506 ms |
| Multilingual v2 (`main` default) | whole | 199 ms | 332 ms | 992 ms |
| Multilingual v2 | streamed | 226 ms | 302 ms | 526 ms |
| Flash v2.5 | whole | 132 ms | 210 ms | 589 ms |
| Flash v2.5 | streamed | 152 ms | 212 ms | 216 ms |
| v3 | whole | 991 ms | 2,307 ms | 6,265 ms |
| v3 | streamed | 850 ms | 901 ms | 902 ms |
| v4 | whole | 675 ms | 1,734 ms | 6,330 ms |
| v4 | streamed | 690 ms | 1,096 ms | 1,110 ms |
| **v4 Turbo** | whole | 281 ms | 797 ms | 2,583 ms |
| **v4 Turbo** | **streamed** | **287 ms** | **396 ms** | **433 ms** |

### 3.2 Time to first audio byte (medians, min–max of 3)

| Model | REST (whole) | HTTP stream | Whole stream done |
|---|---|---|---|
| **v4 Turbo** | 278 / 778 / 2,522 ms | **132 / 140 / 158 ms** (128–200) | 279 / 782 / 2,562 ms |
| v4 | 674 / 1,719 / 6,241 ms | 590 / 693 / 674 ms | 716 / 1,916 / 6,438 ms |
| v3 | 989 / 2,260 / 6,135 ms | 527 / 468 / 606 ms | 790 / 2,124 / 6,534 ms |
| Flash v2.5 | 127 / 205 / 558 ms | 131 / 139 / 145 ms | 142 / 249 / 573 ms |
| Multilingual v2 | 196 / 309 / 927 ms | 195 / 306 / 540 ms | 205 / 376 / 904 ms |
| Voxtral | 469 / 1,023 / 3,893 ms | 317 / 267 / 330 ms | 424 / 884 / 3,783 ms |

(short / conversational / long.) Unstreamed, the server sends nothing until
the clip is made, so "first audio" equals "whole". v4 Turbo makes audio
about eleven times faster than it plays (28 s in 2.4 s), v4 and v3 four to
five times; all stay ahead of playback once started.

### 3.3 Against the 150 ms claim

Met, streamed: 128–200 ms over 15 runs at all three lengths. Not met
unstreamed — no model can, as the clip has to exist first. In lotti the
clip is playable ~150–280 ms after the first byte, because playback
waits for two seconds of audio. That lead was chosen for Voxtral before
these numbers existed; since audio never ran short in any run, a shorter
lead for v4 Turbo would make it playable at ~0.2 s. It is left at two
seconds until a growing file has been heard on a device (§10).

### 3.4 Cost

The `character-cost` header per request: v4 Turbo and Flash v2.5 4 / 24 /
99, v4, v3 and Multilingual v2 8 / 49 / 199 — **v4 Turbo costs half of v4,
v3 and the current default.** Voxtral reports none.

## 4. Streaming text in

Lotti sends the whole text in one request; its texts are already complete
when they are spoken (a summary, a report, her stored answer). Feeding text
in as a model writes it needs ElevenLabs' WebSocket:

- `wss://…/v1/text-to-speech/{voice}/stream-input` **refuses v3, v4 and
  v4 Turbo**: "Model 'eleven_v4_turbo' is not supported on the
  text-to-speech websocket endpoint. Use the text-to-dialogue websocket
  endpoint instead." (HTTP 400, live). `multi-stream-input` answers the same.
- `wss://…/v1/text-to-dialogue/stream-input` takes them: voices registered
  first (`{"voices": [id]}`), text as `{"inputs": [{"text", "voice_id"}]}`,
  `{"close_socket": true}` to finish; `audio` and `is_final` come back.

Measured with the text fed a word every 60 ms, as a model would write it,
from the first word sent:

| Model | Socket | First audio (short / conv. / long) | Done (long) |
|---|---|---|---|
| **v4 Turbo** | text-to-dialogue | **278 / 524 / 580 ms** | 5,252 ms |
| v4 | text-to-dialogue | 823 / 1,069 / 1,241 ms | 6,933 ms |
| v3 | text-to-dialogue | 719 / 879 / 980 ms | 12,318 ms |
| Flash v2.5 | text-to-speech | 314 / 1,419 / 1,526 ms | 5,311 ms |
| Multilingual v2 | text-to-speech | 392 / 1,693 / 1,726 ms | 5,494 ms |

So progressive input works on v4 Turbo with first audio about half a second
after the first word, and the speech keeps pace with the text (the long
text takes 4.6 s to feed). **Not built in the app.** Where it would help is
the companion, which could start speaking before her reply has finished
streaming — but her first words arrive only a fraction of a second before
the turn ends, she is spoken from her stored answer, and her doors' answers
must exist before she is spoken
([front agent](../../knowledge/features/front_agent.md#her-voice)), so the
gain is a fraction of a second against a second transport. Reported by
others and not checked here: the dialogue socket has no message to stop a
synthesis once sent, closes after 20 s without a message, and takes one
voice per connection on v4 Turbo.

## 5. Expressiveness

Nobody listened on the build machine. Two checks stand in, and the clips
are for listening ([`tts_listening_samples.py`](../../tool/benchmarks/tts_listening_samples.py),
[`tts_samples_prosody.py`](../../tool/benchmarks/tts_samples_prosody.py),
[results](tts_latency_2026-11-14/expressiveness_samples.json)).

- **Audio tags are acted, not read.** v3, v4 and v4 Turbo were sent
  `[sighs] Okay... three tasks slipped again this week. [warmly] But
  honestly? That's fine. … [excited] and that was the hard part!`; the
  others, the same without tags. A Voxtral transcript of every clip has the
  words and none of the tags, and the tagged clips run 10.1–10.6 s against
  7.6–7.9 s untagged — the sighs and pauses are performed.
- **Pitch range** (F0 of voiced frames, standard deviation in semitones —
  a common prosody proxy; a simple autocorrelation tracker, so octave
  errors can inflate it):

| Model (Sarah, same line) | F0 spread | 10–90 % range |
|---|---|---|
| **v4 Turbo** | **4.79 st** | 12.8 st |
| v4 | 4.77 st | 11.4 st |
| Voxtral (its default voice) | 4.00 st | 10.8 st |
| Flash v2.5 | 3.96 st | 9.8 st |
| Multilingual v2 | 3.80 st | 10.5 st |
| v3 | 3.63 st | 10.2 st |

v4 Turbo and v4 move the voice about a quarter more than the v2 models, v3
and Voxtral on the same text and voice; v4 Turbo is not a reduced v4 on this
measure. German, read by v4 Turbo: 4.5–5.2 st across three voices, against
3.9 st for Multilingual v2.

## 6. Candidate voices

The key used here lacks the `voices_read` permission, so voice labels could
not be read from the API; the descriptions are ElevenLabs' premade-library
ones. Each id was checked live to speak.

| Voice | Id | Character | F0 spread, v4 Turbo (EN / DE) |
|---|---|---|---|
| **Sarah** | `EXAVITQu4vr4xnSDxMaL` | young adult, American, soft and reassuring — a calm default for summaries | 4.79 / 4.47 st |
| **George** | `JBFqnCBsd6RMkjVDRZzb` | middle-aged, British, warm narrator — reports and long answers | 5.77 / 4.89 st |
| **River** | `SAz9YHcvj6GT2YYXdXww` | American, gender-neutral, relaxed — fits a companion of no fixed gender | 4.89 / 5.16 st |

All are premade, so every account has them, and every ElevenLabs voice
speaks all 94 of v4 Turbo's languages. Other premade ids that spoke with
this key: Alice `Xb7hH8MSUJpSbSDYk0k2`, Matilda `XrExE9yKIg1WjnnlVkGX`,
Lily `pFZP5JQG7iQjIQuC4Bku`, Brian `nPczCjzI2devNBz1zQrb`, Daniel
`onwK4e9ZLuTAKqWW03F9`, Jessica `cgSgspJ2msm6clMCkdW9`, Laura
`FGY2WhTYpPnrIDTdsKH5`, Charlie `IKne3meq5aSn9XLyUdCD`, Callum
`N2lVS1w4EtoT3dr4eOWO`, Liam `TX3LPaxmHKxFdv7VOQHJ`, Will
`bIHbv24MWmeRgasZH58o`, Eric `cjVigY5qzO86Huf0OWal`, Chris
`iP95p4xoKVk53GoZ742B`, Roger `CwhRBWXzGAHq8TQ4Fs17`, Aria
`9BWtsMINqrJLrRacOk9x`. The legacy Rachel (`21m00Tcm4TlvDq8EBNlg`) and Bill
are gone (404).

## 7. Privacy and data flow

What leaves the device, only when the surface's profile names an ElevenLabs
*Read aloud* model — nothing reaches a cloud voice otherwise:

- **To `api.elevenlabs.io`:** the text being read (a summary, a report, a
  query answer, her reply), the voice id and the model id; the key in the
  `xi-api-key` header. Voice previews send the sample sentence. Catalog
  requests (`GET models`, `GET voices`) carry no content.
- **Never:** the user's own audio (this is speech out, not in), other
  entries, or anything when *Prepare chat audio automatically* is on — it
  never calls a cloud voice. Streaming changes how the answer comes back,
  not what is sent.
- **On the device:** the audio is a temporary WAV, written while it arrives,
  deleted on stop, error or disposal; one finished clip is kept for an
  instant replay and deleted with the next speech. A stopped stream's part
  is deleted. Logs hold text lengths, ids, byte counts and timings — never
  the text, the key or the audio.
- **Falling back** goes one way: from a cloud voice to the on-device one
  (no cloud voice for the language, or the provider unreachable with the
  model installed). Never from one provider to another.

The opt-in already exists and is per surface: the *Read aloud* slot of a
profile. A second global switch would duplicate it, so none was added.
ElevenLabs documents a zero-retention mode (`enable_logging=false`) for
enterprise accounts; whether to send it is an account question, not checked
here.

## 8. The key

The app does **not** read `.env` for this key. A key read from `.env` at
build time ends up in every Flathub and Android binary — `envied`'s
obfuscation is reversible — and would be shared by every user. ElevenLabs is
already an inference provider: each user enters their own key under
Settings → AI, it is sent only as the request header, and the clients never
log it. The `.env` key is read only by the benchmark tools, which never
print it.

**This key cannot list voices** (`voices_read` missing: "The API key you
used is missing the permission voices_read"), so lotti's catalog fetch fails
with it and a read aloud reports the provider's words. A key used in the
app needs *Text to Speech*, *Voices: read* and *Models: read*.

## 9. Recommendation

1. **Adopt `eleven_v4_turbo`, streamed, for ElevenLabs.** The fastest start
   of the expressive models (0.29–0.43 s in lotti, flat with length), the
   widest pitch range measured, 94 languages, 10,000 characters per
   request, and half the cost of the current default. In this change.
2. **Do not adopt v3.** Slow to start (playable after 0.85–0.9 s, three
   times v4 Turbo; only v4 is slower), 5,000 characters
   per request, no text-to-speech socket, narrowest pitch range here.
3. **v4 (not Turbo)** only where a second's wait does not matter; it is not
   more expressive than v4 Turbo on this measure and costs twice as much.
4. **Keep Voxtral streamed** (#5084) as the EU-hosted voice: 0.35–0.51 s in
   lotti, a smaller pitch range.
5. **Keep the on-device voice** as the default and the offline fallback.

What the code does now (`ElevenLabsTtsService.synthesizeStream`):

```dart
final uri = CloudTtsHttp.endpoint(
  baseUrl,
  'text-to-speech/${Uri.encodeComponent(voiceId)}/stream',
).replace(queryParameters: const {'output_format': 'pcm_24000'});
// …
await for (final chunk in _http.sendStreamed(request, description: d)) {
  if (chunk.isEmpty) continue;
  if (bytes == 0) yield wavHeader(24000); // lengths 0xFFFFFFFF until whole
  bytes += chunk.length;
  yield chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
}
```

`CloudSpeechSynthesizer` streams any `StreamingCloudTtsClient`, so nothing
else changed for ElevenLabs to stream. Retries are left to the user's tap:
the clients already type every failure (`isRetryable`), and a read aloud
repeated automatically would send the text twice.

## 10. Not verified

- **By ear.** No audio output on the build machine. Listen for the start of
  a growing file and for v4 Turbo's tags and voices; a stall would be
  logged as "Speech played faster than it arrived".
- **The on-device voice's latency.** The Supertonic model (398 MB) is not
  installed here; it synthesizes the whole text before playing.
- **Mobile networks.** All runs from one wired machine; a phone's first
  audio adds its round trip.
- **Android and Linux playback of the growing file.** It goes through the
  same `media_kit` path as before, unchanged by this evaluation.
