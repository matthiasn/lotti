### Fixed
- **Stopping sync also stops pending media repair.** A delayed device lookup
  or failed upload-queue operation can no longer restart media requests after
  sync has been shut down.
