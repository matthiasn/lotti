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
- **With Mistral Large 4 as the companion's model, every message failed with
  "That didn't send".** She asks for fully predictable answers, which Mistral
  Large 4 refuses because it always reasons first. The app now leaves that
  setting out for Large 4, so she answers.
- **With a Mistral model, a longer question to the companion failed with
  "That didn't send".** She marks which words of your message go where by
  counting characters, and Mistral miscounted them, so every attempt was
  refused. She now places your words by the words themselves when the count
  is off, and still never drops any of them.
- **A chat with the companion, a goal or a person said "That didn't send"
  while the answer was still on its way, and kept saying it after the
  answer came.** After the app's agent runtime restarted itself at startup,
  every send was reported as failed at once. Sends now wait for the real
  answer, and the words you sent leave the input box as soon as you send
  them.
- **New answers scroll into view.** A chat now follows the newest message
  as it grows, including cards that arrive after the reply, unless you have
  scrolled up to read.
- **The waiting dots move.** While an answer is on its way, the three dots
  pulse, so it is clear something is coming.
