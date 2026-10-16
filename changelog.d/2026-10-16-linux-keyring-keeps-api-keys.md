### Fixed
- **Connecting GitHub on Linux no longer wipes your AI provider keys.** With
  an unencrypted GNOME Keyring, saving the GitHub token (or the sync setup)
  could leave the keyring entry blank, and the next key saved replaced every
  other one, so providers had no key after a restart. Secrets are now stored
  in a form the keyring keeps intact, and if the entry still comes back blank,
  Lotti writes the keys it knows back before saving anything new.
