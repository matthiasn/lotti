### Fixed
- **Recordings transcribed automatically in a task now get the same
  corrected text and summary as transcribing them by hand.** When a category
  ran speech recognition in the task context on its own, the recording kept
  the engine's raw text, with dictionary terms still misspelled, and no
  summary appeared unless the summary was also set to run automatically. It
  now goes through the same step as the AI menu: the transcript is corrected
  against the speech dictionary, written once, and summarized.
