### Changed
- **The People list stops cutting people's names off.** A long name was
  truncated to make room for a pill that usually just repeated the heading it
  sat under — "Not enrolled" under *Not enrolled*, "On track" under *On
  track*. Those pills are gone, the name now wraps instead of ellipsising,
  and the pills that survived are the ones carrying something no heading can:
  "5 days over" and "Due Wed". An overdue row also gains a warning glyph, so
  the one person you need to contact stands out at a glance rather than
  relying on a tint that read as inert brown in the dark theme.
- **The list leads with the person you actually owe.** Each band is ordered
  by what that band is about — the longest overdue first, the nearest
  deadline first — so the person the summary card names is the first one
  under the heading instead of somewhere further down it.
- **The summary card above the list is a door now.** It named who lapses
  next and how many people are due, then did nothing — you had to go and
  find them. Each half opens what it is about: the count opens the person
  who has been waiting longest, the sentence opens the one it names.
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
- **The chat button on a person's page appears only when there is something
  to chat to**, and wears the same sparkle the rest of the app uses for its
  assistant rather than the speech bubble that means "send this person a
  message".
- **The empty People list says what it is.** It was one sentence pinned under
  the title above a screenful of nothing; it now uses the same centred glyph
  and wording as every other empty screen in the app.

### Fixed
- **Dates and labels no longer fight each other for space.** Timestamps are
  meant to be monospaced so they line up down a column, but the whole status
  line had been set that way — which pushed "Every two weeks" and "No
  cadence" onto ragged second lines on a wide window, and made "Penguin
  Operations · Enrolled" the only monospaced text on a person's page. Only
  the date is monospaced now, at the size of the words around it. The same
  timestamp also used to render in two different typefaces on one screen,
  which it no longer does.
- **The check-in log stopped cutting its own detail off.** Every row's
  summary line ran out of room and broke mid-word, losing how long you spoke
  and what the check-in holds. The line now has the full width, and how it
  felt sits with the topics underneath.
- **"Next time" no longer shows the date of last time.** The card about what
  to raise at the next conversation was headed with the timestamp of the
  previous one, unlabelled — so its only date named the opposite of what the
  card is about.
- **A person's colour no longer means anything it should not.** Avatar
  colours were drawn from the same palette as the app's warnings and
  buttons, so someone who was simply not being tracked could appear in the
  exact orange used for "overdue", or in the colour that elsewhere means
  "you can tap this". They now come from a set of their own.
- **The summary card shows the date it is about.** Squeezed onto one
  wrapped line, the day was the part that got cut — so the card hid the
  single fact the groups below it do not already state. The person and the
  day now sit on lines of their own.
- **The call and record buttons say what they do** wherever the row has room
  for the words, instead of being a bare handset and a bare microphone.
- **A paused reminder stopped shouting.** The quietest card on the page — a
  note that a reminder is asleep — wore the most saturated outline on it, and
  showed its time on a different clock from every other time on the page.
