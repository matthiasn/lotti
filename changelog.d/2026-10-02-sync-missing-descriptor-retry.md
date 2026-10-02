### Fixed
- **A sync item whose attachment was deleted from the server no longer stays
  stuck retrying forever.** When the sync server had already purged the file
  an incoming item depended on, the app kept retrying it every 30 seconds for
  as long as it ran, filling the sync log with the same error. It now skips
  such an item as soon as the server reports the file gone, and gives up on
  any item whose file has still not appeared after a full day of retrying.
