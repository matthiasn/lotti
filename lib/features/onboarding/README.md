# Onboarding

Onboarding is a new user's first few minutes with Lotti. Its whole job is to get
them to one moment: speak a thought, and watch it become a structured task.

## What it does for the user

- **Explains the promise, then delivers it.** A short welcome, then connecting an
  AI provider, then the live voice-to-task moment — not a tour of menus.
- **Never traps anyone.** "Look around first" persists nothing and keeps the
  offer available later.
- **Does not nag.** The welcome auto-shows a small number of times within a fixed
  window and then stops. Completing it retires the offer entirely.
- **Can be replayed on purpose.** Settings › Onboarding reopens it any time.
- **Sets up areas with real consent.** Creating the first areas is also where
  automatic transcription and image analysis are switched on — because the user
  has just connected a provider and chosen those areas. An area where automation
  was previously switched off is left alone.

A separate Daily OS walkthrough teaches the day-planning ritual; it is still
behind a flag and off by default.

## What it owns

The welcome and connect flow; the first-capture experience; the auto-show trigger
and re-show cadence; the Settings replay entry; and the onboarding metrics store
and its funnel derivations.

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

**→ [knowledge/features/onboarding/](../../../knowledge/features/onboarding/)**
