### Security
- **Sync now applies changes only from your own verified devices.** Before,
  anything posted into your sync room was accepted as long as it looked like a
  sync message — whether or not it was encrypted, and whoever sent it. Someone
  with your account password, or the operator of your Matrix server, could
  have slipped in changes, such as pointing an AI provider at their own
  server. Every incoming change and attachment must now be encrypted by a
  device you verified, matching the rule Lotti already used for what it sends.
  History from a device you have since logged out still syncs.
