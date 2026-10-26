### Fixed
- **The "Background sync worker" flag still said it did no syncing yet.**
  Its description in Config Flags dated from when the worker only proved it
  could start. It now says what the flag does: with it on, sync — the
  Matrix client, catch-up, attachment downloads and sending — runs in a
  background worker instead of on the interface.
