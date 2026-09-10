### Added
- **A project's task list now shows each task's cover art.** A task with a
  picture was recognisable everywhere except inside its own project, where the
  list was text only. Its thumbnail now leads the row, cropped the way it was
  set on the task, and tasks without one are unchanged.

### Fixed
- **The project agent proposed the same change on every wake, and the
  "Proposed changes" list grew a copy each time.** A wake could not see the
  suggestions already waiting for a decision, so a project the agent thought
  should be Active collected "Update project status to Active" over and over —
  thirteen identical rows in one report, none of which the agent could take
  back. Each wake now reads its open proposals, is refused when it proposes a
  status the project already has or a change that is already on screen, and can
  withdraw one of its own suggestions that has gone stale. Withdrawals land
  together with that wake's new suggestions, so the list never blinks empty in
  between.

### Changed
- **Explore project moved into the project title row.** It sat in a band of its
  own under the title, pushing the description and the report down the page; it
  now sits in the top-right corner beside the project menu, and drops to its map
  glyph on a narrow window or at large text.
