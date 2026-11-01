### Fixed
- **The companion answered aloud in the device voice even when your Mistral
  profile names Voxtral TTS.** She took her voice from her own AI setup,
  which had no read-aloud model unless a Settings default profile was set,
  so she never spoke with Voxtral or showed the lip sync tuned to it. Her
  chat's overflow menu now has *AI profile*: pick the profile with Voxtral
  TTS and she thinks and speaks with it, on every device, or pick *Settings
  default* to have her follow the default profile again. While she follows
  it, changing the Settings default changes her voice right away, and if
  the profile you chose for her is deleted she falls back to the default.
- **The Day page briefing always used the device voice.** Tapping her in the
  Day header now speaks with the read-aloud model of the profile the Daily OS
  planner uses, and she appears on devices without the on-device voice when
  that profile has a cloud voice.
- **Questions about your journal sometimes failed with "Asking this
  failed".** When the model cited a source number it was never given, the
  whole answer was thrown away; now that citation is dropped and the answer
  is kept. When one entry could no longer be read in the categories you
  chose, the whole question failed; now that entry is left out and the
  answer says its coverage is incomplete. This affects the companion's
  journal answers and Ask in tasks, projects and categories.
