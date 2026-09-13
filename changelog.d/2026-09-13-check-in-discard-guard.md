### Added
- **The check-in composer asks before throwing away unsaved words.** Closing
  it — with Cancel, the close button or the back gesture — while it holds
  text you have not saved, or while a recording is still running, now asks
  first and names what would be lost. Confirming discards the recording as
  well, instead of leaving it running behind the closed sheet. An untouched
  composer still closes at once.

### Changed
- **The check-in composer and the Briefing card read better at large text
  sizes.** The composer's header keeps its whole title and shortens its
  status line a word at a time — keeping the person's name — instead of
  cutting it off, and the card's status line does the same beside its age
  tag. The finished transcript is announced on one caption line with the
  word count, the recorder's clock uses the same `0:23` shape as the
  saved-audio line, the chosen feeling carries a check mark as well as its
  colour, and the desktop composer no longer leaves a blank band above its
  buttons.
- **Speech failures in the check-in composer are more honest and easier to
  recover from.** A refused microphone offers Try again on its card instead
  of a dead Dictate button; typing under a failure card that has nothing to
  retry dismisses it; a transcript that never arrived is reported as
  exactly that, and choosing to type instead keeps its Try again on one
  line rather than forgetting the recording. Re-record is only offered
  while the transcript is still unedited, so it never takes your edits with
  it. Cancel is quiet text on every screen, so the Save button is the one
  bright control.
- **The Briefing card leads with the health band, and every face has a
  quiet next step.** The status line reads "Thriving · as of 3 h ago", the
  card offers Log check-in before the first briefing and See activity while
  one is being written, and the briefing text sits at the same size as the
  rest of the card.

### Fixed
- **Loading spinners and placeholder shimmers hold still under the system's
  reduced-motion setting.**
