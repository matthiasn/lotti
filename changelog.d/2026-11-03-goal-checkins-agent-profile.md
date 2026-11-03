### Fixed
- **Goal check-ins were transcribed by the wrong model.** A goal whose agent
  you set to a profile such as Mistral still had its spoken check-ins
  transcribed by your default profile's model, for example Whisper, whenever
  the goal had no category. Recordings about a goal or a person now use the
  agent's profile first. After that come the person's own profile, the
  category's profile and your default profile. Dictating into a goal's or a
  person's chat follows the same order.
- **A voice note added to a goal's day reflection is now filed in the goal's
  category,** like every other check-in.
