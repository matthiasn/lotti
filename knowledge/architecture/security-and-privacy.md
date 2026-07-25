---
type: Architecture
title: Security and privacy posture
description: What is encrypted, what is not, where secrets live, and what leaves the device.
tags: [architecture, security, privacy, encryption, secure-storage]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: secure-storage
    resource: ../../lib/features/sync/secure_storage.dart
    title: SecureStorage
    last_modified: 2026-07-20
  - id: privacy-policy
    resource: ../../PRIVACY.md
    title: Lotti privacy policy
    last_modified: 2026-04-30
  - id: pubspec
    resource: ../../pubspec.yaml
    title: Dependency manifest — evidence of what is absent
    last_modified: 2026-07-26
---

# The claim, and what backs it

Lotti's product promise is that your data is yours. Three architectural facts
back that up, and one caveat qualifies it.

**No telemetry, at all.** The dependency manifest contains no analytics,
crash-reporting or attribution SDK — no Firebase, Sentry, PostHog, Mixpanel or
Amplitude. This is verifiable rather than asserted: the absence is in
`pubspec.yaml`, and adding any of them would be a visible dependency change.

**No account is required.** The app is fully functional with no server. A
Matrix account is needed only for multi-device sync, and Matrix is decentralized
— self-hosted or any public homeserver, no vendor lock-in.

**Nothing leaves the device without a user action.** Journal content reaches a
network only on two paths: end-to-end encrypted sync to the user's own devices,
and AI inference the user configured and triggered.

**The caveat: the SQLite databases are not encrypted at rest.** There is no
SQLCipher in the dependency set. On-disk protection relies on OS-level
full-disk encryption — FileVault, BitLocker, Android file-based encryption,
LUKS. Database-level encryption is a known gap, not a shipped feature; do not
document it as one.

# Secrets

API keys and sync credentials never touch SQLite. They go to the OS keystore
through `flutter_secure_storage`, wrapped by `SecureStorage`:

| Platform | Backing store |
|----------|---------------|
| iOS / macOS | Keychain Services |
| Android | Android Keystore + encrypted SharedPreferences |
| Windows | Credential Locker (DPAPI) |
| Linux | Secret Service (libsecret, via GNOME Keyring or KWallet) |

`SecureStorage` adds two things over the raw plugin:

- **A read-through in-memory cache.** The first read of a key is memoised for
  the process lifetime; `writeValue` deletes before writing so the cache and the
  keystore cannot disagree.
- **Namespacing by package name.** iOS and macOS entries carry the app's package
  name as `accountName`, so build flavours installed side by side do not collide
  in a shared keychain.

# Sync encryption

Sync is end-to-end encrypted by Matrix itself, using **vodozemac** (the Rust
reimplementation of libolm) via `flutter_vodozemac`. `vod.init()` runs during
`registerSingletons()` before the Matrix client is created.

```mermaid
flowchart LR
  Local["Local write"] --> Outbox["OutboxService (sync.sqlite)"]
  Outbox --> Sender["MatrixMessageSender"]
  Sender --> Enc["Olm/Megolm encryption (vodozemac)"]
  Enc --> Room["Encrypted Matrix room on the homeserver"]
  Room --> Dec["Decryption on the peer device"]
  Dec --> Queue["InboundEventQueue"]
  Queue --> Apply["SyncEventProcessor → local databases"]
```

The homeserver relays ciphertext it cannot read. Device trust is established
through Matrix key verification (`key_verification_runner.dart`), and events
that arrive before their session key does are parked in the
**pending-decryption pen** rather than dropped, so a late key still yields the
message instead of a permanent hole.

# AI inference

AI is the one path where content deliberately leaves the device, and it is
governed by explicit configuration rather than a default:

- Providers and models are configured by the user; nothing is preconfigured
  with a vendor key.
- **Ollama and other local endpoints keep inference on-device entirely.**
- Automatic inference — transcribing new audio, analysing new images without a
  user gesture — is gated behind a category's `automaticInferenceEnabled` flag,
  which is nullable and treated as *off* when absent. Selecting an inference
  profile is deliberately **not** sufficient to start spending tokens.

See [the AI feature](../features/ai.md) for how requests are routed and
[categories](../features/categories.md) for where that consent flag is set.

# Error handling as a privacy surface

Because there is no crash reporter, diagnostics stay local: logs are written to
files in the documents directory, gated per domain, and readable only in-app
(see [logging and diagnostics](logging-and-diagnostics.md)). Nothing is uploaded.
Sharing a log is a deliberate export by the user.

# Where to look

| Concern | File |
|---------|------|
| Keystore wrapper | [`lib/features/sync/secure_storage.dart`](../../lib/features/sync/secure_storage.dart) |
| Matrix client creation | [`lib/features/sync/matrix/client.dart`](../../lib/features/sync/matrix/client.dart) |
| Key verification | [`lib/features/sync/matrix/key_verification_runner.dart`](../../lib/features/sync/matrix/key_verification_runner.dart) |
| Late-key handling | [`lib/features/sync/queue/pending_decryption_pen.dart`](../../lib/features/sync/queue/pending_decryption_pen.dart) |
| Published policy | [`PRIVACY.md`](../../PRIVACY.md) |
