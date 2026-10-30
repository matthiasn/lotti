# Text-to-speech

Text-to-speech reads task summaries, goal reports and query answers aloud —
with the on-device voice, or with the cloud voice an inference profile names.

By default nothing leaves the machine: the voice model runs locally. A text
goes to a provider only when the profile behind the surface names a
read-aloud model, and only when the user presses play.

## What it does for the user

- **Reads the summary aloud.** A speak control on the task card plays the agent's
  TL;DR.
- **Reads a query answer aloud.** Each saved answer has a speak action when
  text-to-speech is enabled; leaving the chat or hiding its content stops it.
- **Works offline and privately.** The on-device model needs no cloud service
  and no API key.
- **Speaks with a profile's cloud voice.** A profile's *Read aloud* slot can
  name Voxtral TTS on Mistral; summaries and answers then speak in the task's
  language with that language's voice — the user's pick in Speech settings,
  else its first female voice. Speech settings list the user's own languages
  first, and every voice can be heard before it is picked. The voice list is
  cached, so it still works offline once fetched; speech itself needs the
  network.
- **Uses the app's own audio stack**, so playback behaves like every other sound
  in Lotti.

The control is currently hidden unless the feature flag is on — local voice
quality is still being evaluated.

## What it owns

The engine interface and its on-device implementation, the model assets, the
cloud voice client with its cached voice catalog, the per-language voice
choices, and the playback wiring for spoken content. Which profile a surface
uses, and its read-aloud slot, belong to the AI feature.

## Where the code lives

```text
lib/features/tts/
```

## How it works

The engine, the platform matrix, and the targeted CocoaPods workaround that lets a
statically linked runtime coexist with dynamic frameworks are documented in the
knowledge bundle:

**→ [knowledge/features/tts.md](../../../knowledge/features/tts.md)**
