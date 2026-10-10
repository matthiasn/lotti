### Fixed
- **An AI provider, model, prompt or skill deleted on one device could stay
  on the others.** When the change could not be queued for sending — the sync
  outbox was briefly unavailable, or the app closed between the write and the
  queue — the deletion was gone here and nothing recorded that the other
  devices had not heard. A deleted prompt had no row left for *Send settings*
  to re-send either. Every AI configuration change is now owed to the other
  devices until the outbox has taken it, sent again at the next start or a
  minute later if it was not, and *Send settings* re-sends deletions along
  with the rows.
- **A model left behind by a deleted provider is no longer listed.** A model
  edited on a device that had not yet heard the provider was deleted stays
  stored, so undoing the provider's deletion brings it back, but it is hidden
  from the model lists until then rather than shown under a provider that no
  longer exists.
- **Removing a provider's API key now removes it on every device.** Before,
  an empty key arriving from another device was taken for a failed keychain
  read and the other devices kept theirs; a key cleared on purpose now says
  so, and the peers clear it too.
