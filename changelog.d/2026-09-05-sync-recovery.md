### Fixed
- **Sync can recover missing journal upload files.** Entries still held in the
  local database, including deletions, can be sent without repeatedly retrying
  a missing file, provided they cover every queued version.
- **Sync handles out-of-order labels and pending writes more reliably.** Missing
  label definitions no longer fail background sync, and a pending local write
  is not incorrectly reported to other devices as an unused sequence number.
