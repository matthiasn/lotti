### Fixed
- **Sync retries changes when saving their receipt fails.** Temporary database
  failures no longer silently finish individual changes or bundles, and a
  failed link save cannot leave the link incorrectly marked as received.
