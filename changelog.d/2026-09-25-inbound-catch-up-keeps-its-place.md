### Fixed
- **Sync no longer skips messages when a catch-up is interrupted.** After
  being offline, a device catches up on what other devices sent. If that
  catch-up stopped early — a network error, a crash, a very large backlog —
  or newer messages arrived while it ran, the device could resume from past
  the part it had not fetched yet and never apply those messages; they only
  came back if another device happened to resend them. A catch-up now keeps
  its place until it has fetched everything, and a message that fails to save
  when it arrives is fetched again instead of being dropped.
- **Incoming sync no longer stalls after a database hiccup.** A single
  database error while applying incoming changes stopped all further
  processing until the app restarted. Processing now pauses briefly and
  carries on.
