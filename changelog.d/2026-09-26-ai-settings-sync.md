### Fixed
- **AI settings now agree on every device, and deleted providers stay
  deleted.** When two devices changed the same provider, model, prompt or
  profile, each could end up keeping the other's change for good, and an older
  copy arriving late — or re-sent by "Send settings" — could overwrite a newer
  edit or undo a restore. The newest change now wins everywhere. Deleting a
  provider also no longer comes undone when another device sends its older
  copy back, API key included, and models that another device added for that
  provider in the meantime are removed with it.
- **A device that had lost its stored API keys no longer erases them on your
  other devices.** After restoring a backup or resetting the system keychain,
  the next sync of a provider from that device deleted the key everywhere else.
  Your other devices now keep their key.
- **Undo after deleting a prompt or skill brings it back.** The undo button in
  the confirmation toast did nothing for prompts and skills.
