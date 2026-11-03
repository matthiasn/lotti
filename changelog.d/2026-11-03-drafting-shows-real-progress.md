### Changed
- **"Drafting your day" now shows what the planner is actually doing.** The
  rotating lines ("Placing deep work first…") and the stage chips used to run on
  a timer, whatever the agent was doing. They now follow the real wake: which
  step it's in and for how long, the model it uses, tokens in and out, time per
  step, the tools it called, and, when an attempt fails, "Attempt 2 of 5" with
  the reason and a countdown to the retry.

### Fixed
- **A day plan could sit queued while an audio note was being transcribed in
  the background.** Planning now starts right away instead of waiting for the
  transcription to finish.
