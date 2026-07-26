# Text-to-speech

Text-to-speech reads a task's AI summary aloud, entirely on the device.

No audio and no text leaves the machine — the voice model runs locally.

## What it does for the user

- **Reads the summary aloud.** A speak control on the task card plays the agent's
  TL;DR.
- **Works offline and privately.** The model runs on-device; there is no cloud
  service and no API key.
- **Uses the app's own audio stack**, so playback behaves like every other sound
  in Lotti.

The control is currently hidden unless the feature flag is on — local voice
quality is still being evaluated.

## What it owns

The engine interface and its on-device implementation, the model assets, and the
playback wiring for spoken summaries.

## Where the code lives

```text
lib/features/tts/
```

## How it works

The engine, the platform matrix, and the targeted CocoaPods workaround that lets a
statically linked runtime coexist with dynamic frameworks are documented in the
knowledge bundle:

**→ [knowledge/features/tts.md](../../../knowledge/features/tts.md)**
