### Fixed
- **An interrupted database upgrade could leave the journal half-migrated.**
  If the app was killed while upgrading its database, the steps already
  applied stayed while the version number did not advance, and the next
  launch would try to apply them again. The whole upgrade now either
  completes or rolls back to the version that was running.
