### Changed
- **Purging deleted entries and rebuilding search no longer slow down on a
  large journal.** Both used to read the journal in a way that grew more
  expensive with every page, and paused on purpose between steps to make
  progress visible. They now walk the journal in fixed-size chunks and
  report progress as they go.
