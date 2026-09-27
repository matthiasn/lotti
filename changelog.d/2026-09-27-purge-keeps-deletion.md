### Fixed
- **An entry you deleted could survive, or come back, after you purged deleted
  items.** Purge deleted items (Settings → Advanced → Maintenance) removed every
  trace of a deleted entry. A device that had not yet received the deletion
  then kept the entry for good, and an older copy arriving from another device
  could bring it back on this one. A purge now keeps a small record of each
  deletion. It still removes the entry's content and files, and the deletion
  now reaches every device.
