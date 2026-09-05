### Fixed
- **Diagnostic logging causes fewer disk writes.** Domain logs now share the
  buffered writer and shutdown flush used by other logs, while errors still
  request an immediate flush. Routine logging bursts have a bounded queue with
  counted summaries for omitted records. Sync and recording logs also omit account
  identities, device names and absolute recording paths.
