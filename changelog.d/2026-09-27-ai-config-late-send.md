### Fixed
- **A slow sync could put an older AI setting back on your other devices.**
  When sending an edit to a provider, model, prompt or profile timed out on a
  poor connection, the app tried again and went on to send newer edits — but
  the first attempt could still arrive late, after a newer edit, and the
  other devices then kept the older value. Every AI setting now travels with
  a version stamp, and a device keeps whichever version is newest, however
  late an older copy arrives. A deleted setting also no longer comes back
  from a copy that was sent before the deletion.
