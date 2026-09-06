### Fixed
- **Dismissing an AI-suggested next step did not make it go away.** The
  suggestion stayed on the list with a strikethrough, so a project you had
  triaged looked exactly as long as one you had not. A dismissed suggestion now
  leaves the list immediately. Nothing is lost: it moves to the band's history,
  which opens under the remaining suggestions, and that is where it can be
  restored.
- **The task count on a project could show the wrong number.** The blue badge
  beside "Project Tasks" was a fixed-size circle, so a project with 153 tasks
  read as "15", with the digits sitting off-centre. The badge now grows to fit
  the number and stays centred.
- **The Project Tasks header was laid out wrong.** The sort control and
  "Add task" floated in the middle of the row instead of sitting against the
  right edge, and the total estimate was wedged between the heading and its
  count. The header now reads as the title with its count on the left and the
  estimate, sort control and "Add task" together on the right, all on one line.
- **Month headings cut the task card's outline open.** Each collapsible group
  heading painted over the card's left and right edges, leaving the card border
  visibly interrupted at every group. The outline is now continuous.
- **AI analyses on image and audio entries were set too large.** An analysis
  nested inside an entry card was rendered bigger than the entry's own text and
  padded like a top-level card. It now matches the text editor's size and sits
  in a tighter card.

### Added
- **Swipe to decide the project agent's proposed changes.** Proposed changes on
  a project page now swipe like the ones on a task page and like the suggested
  next steps beside them — right to confirm, left to reject, with the action
  named on the band the swipe reveals.
