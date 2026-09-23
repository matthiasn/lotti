### Fixed
- **An edit saved just before the app was closed or killed could never reach
  your other devices.** If the app stopped in the moment between saving an
  entry and queueing it for sync, that version stayed on the one device until
  you edited the entry again, and other devices could keep asking for it for
  days. The app now records which entry each change belongs to before saving
  it, and finishes the job the next time it starts: a recorded change that was
  saved is sent, and one that was not is reported as gone so other devices stop
  waiting for it. Changes left unfinished by an older version of the app carry
  no such record and are still only waited out.
- **Sync could tell other devices to stop waiting for an edit that did exist.**
  In rare cases where saving an entry hit an internal error after the entry was
  already stored, the app announced that change as never having happened. It
  now checks the stored entry first and sends it instead.
