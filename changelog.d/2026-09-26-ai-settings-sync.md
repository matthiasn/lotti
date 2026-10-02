### Fixed
- **Deleting a provider also removes the models another device added for it.**
  A model another device created for the provider before it heard of the
  deletion stayed behind, listed under a provider that no longer existed and
  failing every request sent to it. It is now removed on every device, and
  undoing the deletion still brings back the models it took.
- **A device that had lost its stored API keys no longer erases them on your
  other devices.** After restoring a backup or resetting the system keychain,
  the next sync of a provider from that device deleted the key everywhere else.
  Your other devices now keep their key.
- **Undo after deleting a prompt or skill brings it back.** The undo button in
  the confirmation toast did nothing for prompts and skills.
