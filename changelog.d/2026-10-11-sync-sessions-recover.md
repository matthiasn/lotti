### Fixed
- **Sync starts on its own once the network is back.** Opening the app
  without a connection used to leave sync off until the next restart.
- **Signing in with your own homeserver details joins your existing sync
  room** instead of creating a new one, so your devices stay together.
- **Changes a device sent before you verified it now arrive** once the
  verification completes, instead of being dropped.
