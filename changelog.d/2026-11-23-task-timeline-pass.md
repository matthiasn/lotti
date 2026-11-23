### Changed
- **A task's linked entries are easier to read, and the audio player is
  half the height.** The player is now one row everywhere it appears: play,
  the waveform, one time label (the length at rest, the position while it
  plays) and the speed. A recording's transcript starts about 30 pixels
  higher, and a faster or slower speed is no longer shown in red.
- **What the AI made of a recording or a photo says what it is.** The
  "2 AI responses" header, its connector line and the indent are gone. Each
  result is named instead (*Summary*, *Image analysis*, a prompt's own
  title) and uses the card's full width, so there is more room for its text
  on a phone.
- **A collapsed recording shows whose words you are reading.** An AI
  summary line is violet with the AI mark; the opening of your own
  transcript stays in plain ink.
- **The Timer, Audio, Images and Code filters are plain chips.** They no
  longer each have a colour of their own, and they match the sort control
  beside them.
- **Photos in the timeline have rounded corners and no black bars**, and
  are at most 400 pixels tall; tap one to see it in full. Long text keeps a
  comfortable line length on wide windows.

### Fixed
- **Switching off every filter no longer leaves an empty list.** It now
  says *No entries match* and offers *Clear filters*.
- **AI results that fail to load say so**, instead of the entry looking as
  if nothing had been made of it.
- **The waveform no longer flickers back to a plain bar** while it reloads.
