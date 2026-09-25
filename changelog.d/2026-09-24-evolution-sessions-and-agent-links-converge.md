### Fixed
- **A 1-on-1 whose proposal you approved could show as abandoned.** If another
  device started a 1-on-1 for the same agent shortly after you approved one,
  its cleanup of "stale" sessions could win on every device. The approved
  session then counted as abandoned in the history and in the approval rate,
  and fed a negative signal into the next ritual. An approved 1-on-1 now stays
  approved on every device.
- **A failed approval could leave the new directives in effect, or create a
  second personality version on retry.** The new version was saved before the
  rest of the approval. If a later step failed, the change was already in use
  while the 1-on-1 still looked open, and retrying a personality approval
  saved it again. An approval now saves everything together or nothing.
- **A removed agent link could come back on another device.** When a device
  received a removal before the link it removed, or lost the removal and
  asked for it again, it kept the link. Linking a capture item to a task again
  after another device had unlinked it could also leave the devices
  disagreeing. Removed links now stay removed, and a new link wins everywhere.
