### Fixed
- **Goal check-ins recorded and played back, but were only transcribed when
  stopped from the recording sheet.** A check-in stopped from the sidebar's
  Stop button or the floating recording indicator — after the sheet had been
  dismissed — was saved on the goal and never transcribed, with no failure
  shown. Transcription now runs wherever the recording ends, still under the
  goal's automatic-updates switch, and a switched-off goal records a visible
  decline with Retry.
- **The desktop Logbook offered no way to create a linked entry.** The split
  view's detail pane had dropped its floating action button as a duplicate of
  the list's, but the list's button only creates standalone entries. The
  detail pane's button is back, creating entries linked to the open one.
