### Fixed
- **Goal check-ins took minutes to transcribe, or never did, on a model you
  never picked.** When a goal's category set up no automatic transcription,
  its spoken check-ins skipped your inference profiles altogether and went to
  whichever speech model ranked first — the on-device one when installed,
  which could take minutes or fail. They now use the goal's category profile,
  and your default inference profile when the category has none that can
  transcribe.
- **People check-ins ignored the person's category.** Spoken check-ins about a
  person always used the default profile. They now use the profile of the
  person's category first, like goals, and fall back to the default.
- **Dictating into a goal's or a person's chat used a different model.** Voice
  input in those chats, and in a goal's "About this goal" sheet, picked its own
  speech model instead of the one in your profiles. It now uses the same
  profile as the check-ins, and a speech-to-text model's words get the same
  speech-dictionary correction afterwards.
