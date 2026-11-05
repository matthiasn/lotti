# Onboarding

Onboarding is a new user's first few minutes with Lotti. Its whole job is to get
them to one moment: speak a thought, and watch it become a structured task.

## What it does for the user

- **Explains the promise, then delivers it.** A short welcome, then connecting an
  AI provider, then the live voice-to-task moment — not a tour of menus.
- **Lets the user make her theirs.** An optional step before the key: her
  outfit, skin tone, hair and hair colour, saved as they are picked and
  editable later in Settings › Companion.
- **Lets the user hear the voices.** An optional step plays a sample of each
  voice she can have: on the device, Mistral's Voxtral, and ElevenLabs.
- **Says what it takes: one API key.** The connect step leads with one
  recommended provider, Mistral, whose single key covers thinking,
  transcription and the voice; the others sit behind a disclosure.
- **Never traps anyone.** "Look around first" persists nothing and keeps the
  offer available later.
- **Does not nag.** The welcome auto-shows a small number of times within a fixed
  window and then stops. Completing it retires the offer entirely.
- **Has a face.** The companion leads it, whether or not she is switched on
  elsewhere: she introduces herself on the welcome, recommends the one key,
  then waves the user on, listens while they record, thinks while the task is
  structured and celebrates when it lands. Her lines are speech bubbles. Where the on-device voice is already installed
  she says the headlines aloud; on a first run, she is silent.
- **Can be replayed on purpose.** Settings › Onboarding reopens it any time.
- **Sets up areas with real consent.** Creating the first areas is also where
  automatic transcription and image analysis are switched on — because the user
  has just connected a provider and chosen those areas. An area where automation
  was previously switched off is left alone.

A separate Daily OS walkthrough teaches the day-planning ritual; it is still
behind a flag and off by default.

## What it owns

The welcome and connect flow; the first-capture experience; the auto-show trigger
and re-show cadence; the Settings replay entry; the recording-style preference
page Settings routes to; and the onboarding metrics store and its funnel
derivations.

## Where the code lives

```text
lib/features/onboarding/
├── model/ · repository/ · state/
└── ui/
```

Metrics live in their own database, `onboarding_metrics.sqlite`, and never sync.

## How it works

The flow, why measurement has a dedicated store, the cadence rules, and where the
AI consent flag is written are documented in the knowledge bundle:

**→ [knowledge/features/onboarding.md](../../../knowledge/features/onboarding.md)**
