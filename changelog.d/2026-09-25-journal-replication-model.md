### Fixed
- **A deleted entry no longer comes back after syncing.** A late copy of an
  older version could replace a deletion on another device, a deletion that a
  device missed was never sent to it again, and an edit made on one device
  while the entry was deleted on another silently undid the deletion. A
  deletion now stays unless an edit really came after it; an edit made at the
  same time as a deletion is shown as a conflict — kept or deleted, your
  choice — on both devices, and the conflict page now opens for an entry you
  deleted on this device.
- **An edit from another device is no longer dropped from the conflicts
  list.** Editing an entry, or receiving any newer version of it, marked its
  open conflict resolved even when the other device's edit was not part of
  it, and a late copy of an older version could replace the version the
  conflict showed. A conflict now stays until a version that includes it is
  saved.
- **Label changes and rejected label suggestions sync reliably.** Setting an
  entry's labels while an edit arrived from another device could overwrite
  that edit, and a rejected AI label suggestion was never sent to your other
  devices. Both are now saved on top of the latest version.
