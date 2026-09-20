### Changed
- **The People list stops cutting people's names off.** A long name was
  truncated to make room for a pill that usually just repeated the heading it
  sat under — "Not enrolled" under *Not enrolled*, "On track" under *On
  track*. Those pills are gone, the name now wraps instead of ellipsising,
  and the pills that survived are the ones carrying something no heading can:
  "5 days over" and "Due Wed". An overdue row also gains a warning glyph, so
  the one person you need to contact stands out at a glance rather than
  relying on a tint that read as inert brown in the dark theme.
- **One word for one thing on a person's page.** The button that starts the
  agent watching someone said "Mark important" while everything around it —
  the band, the pill, the summary — said "enrolled", leaving the one action a
  new user has to find as the only thing not named after it. It now reads
  "Enrol {name}", and the marker beside an enrolled person's name reads
  "Enrolled" too.
- **The person page no longer offers the same action twice.** *Log check-in*
  and the call button appeared both in the briefing card's footer and in the
  bar at the bottom of the page, each one prominent in one place and quiet in
  the other. The bottom bar now owns them, and the briefing card offers only
  what the agent itself can do — *Update now*, *Try again*, *See activity*.
- **The empty People list says what it is.** It was one sentence pinned under
  the title above a screenful of nothing; it now uses the same centred glyph
  and wording as every other empty screen in the app.

### Fixed
- **Dates and labels no longer fight each other for space.** Timestamps are
  meant to be monospaced so they line up down a column, but the whole status
  line had been set that way — which pushed "Every two weeks" and "No
  cadence" onto ragged second lines on a wide window, and made "Penguin
  Operations · Enrolled" the only monospaced text on a person's page. Only
  the date is monospaced now. The same timestamp also used to render in two
  different typefaces on one screen, which it no longer does.
