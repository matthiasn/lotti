### Fixed
- **Retrying a failed sync item no longer sends an outdated change.** When an
  item in the sync outbox had failed and a newer change to the same thing was
  sent afterwards, tapping Retry used to send the old value again, and other
  devices could end up with it. The newer send now settles the older failure
  with it. Saving several changes to the same item in quick succession also
  no longer risks one of them being skipped. Queuing a change for sync is
  faster, because it no longer has to look up earlier sends first.
