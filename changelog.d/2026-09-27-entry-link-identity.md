### Fixed
- **A link you removed could come back.** If you linked the same two entries
  on two devices while they were offline, each device kept its own copy of
  the link. Removing it on one device then left the other copy in place, and
  the next sync put the link back on the device where you removed it. Both
  devices now treat it as one link, so a removal sticks everywhere. Links
  already duplicated this way sort themselves out the next time they sync.
