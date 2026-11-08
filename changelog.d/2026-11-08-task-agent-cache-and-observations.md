### Changed
- **Task agents write shorter observations and repeat themselves less.**
  An agent used to restate the task's status, time entries and pull requests,
  copy dictated sentences word for word, and record the same guidance on
  several updates. It is now asked to record only what a later update cannot
  read from the task itself, one fact per note. Routine notes over 280
  characters and word-for-word repeats of an earlier note are turned away.
- **Task agent updates on Mistral re-use more of their cached prompt.** The
  label and correction lists no longer sit at the top of the prompt, where
  assigning a label made the agent re-read the whole task log at full price,
  and requests now ask Mistral to keep one agent's updates together in its
  cache. Quick back-to-back updates — after stopping a timer, dictating a note
  or closing a task — can cost less and answer faster when Mistral serves
  them from its cache.
