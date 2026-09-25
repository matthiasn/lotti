### Fixed
- **Other devices could end up with an older version of a change.** If the
  app closed or crashed just after sending an update, and the same thing was
  changed again right after it restarted, the older update was sent a second
  time a minute later, after the newer one — so a setting changed on one
  device could flip back on the others. Two updates of the same agent or link
  queued at the same moment could also lose one of them until the next
  change. Unfinished sends now go out again in their original order, and
  updates of the same item are queued one after another.
