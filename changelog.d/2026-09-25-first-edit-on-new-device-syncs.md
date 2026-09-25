### Fixed
- **The first edit of an entry on a newly set up or reinstalled device was
  lost.** A fresh device's first change to each entry, link or agent record
  it had synced from elsewhere looked identical to the version it replaced.
  The device itself discarded the edit to an entry, and other devices ignored
  it, with no error and no conflict. Such an edit is now saved and syncs to
  your other devices. When another device changed the same entry at the same
  time, the two versions now show up as a conflict you can resolve, instead
  of one of them being dropped silently.
