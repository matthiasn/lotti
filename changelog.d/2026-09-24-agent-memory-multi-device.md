### Fixed
- **An agent could miss an edit you made on another device.** When an agent
  on one device condensed its older memory into a summary before your edit
  from another device had arrived, the edit then counted as already
  summarized: the agent saw neither the new text nor a summary of it. The
  summary is now set aside until it is written again with the edit in it.
- **An agent could summarize the same memory on every run.** When part of
  its memory had not finished syncing, the summary it wrote was discarded
  straight away, and the next run paid for the same summary again. It now
  summarizes only up to the missing part.
