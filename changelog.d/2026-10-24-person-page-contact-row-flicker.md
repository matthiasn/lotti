### Fixed
- **The Call, Message and Email buttons on a person's page blinked after
  every check-in.** Each write a check-in makes — the check-in itself, its
  recording, the transcript landing, the summary, the agent's briefing —
  reloads the page, and the row of buttons under the name took each reload
  for a change of contact details: it emptied itself, asked the device again
  which numbers it can dial, and filled back in a moment later, so the page
  kept flickering after the rest of it had learned to stay put. The buttons
  now stay through a reload and are only re-checked when the person's
  contact details actually change.
- **A transcript opened with Show more on a person's timeline folded itself
  again.** Scrolling far down the history and back rebuilt the row folded,
  and the history shifted under the reader as it came back shorter. An
  opened row now stays open, at its full height, however far you scroll
  away and back.
