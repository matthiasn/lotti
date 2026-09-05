### Fixed
- **Sync startup avoids scanning a device’s full sequence history.** Checking
  pending local writes now reads only the matching counters, reducing database
  work on profiles with a long sync history.
