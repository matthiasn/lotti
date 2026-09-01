### Added
- **Sync can now be set up on Linux by signing in with a Matrix account.**
  Until now the very first device needed a provisioning bundle from the
  server-side admin tool, which left out anyone with a Matrix account but no
  homeserver of their own or nobody to run the tool for them. Under Settings
  → Sync Settings → Devices, *Set up sync* now offers *Sign in with a Matrix
  account instead* on Linux: enter the server address, your full Matrix ID and
  your password, and Lotti signs in, creates the encrypted sync room itself and
  is ready. Your password stays in this device's secure storage and is never
  changed; only the server you name sees it, plus the pairing codes you later
  make for your own devices, which carry it. Every further device pairs from
  this one with a pairing code, as before.
