---
type: Architecture
title: Security and privacy posture
description: What is encrypted, what is not, where secrets live, and what leaves the device.
resource: ../..
tags: [architecture, security, privacy, encryption, secure-storage]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T20:00:00Z }
stale_after: 2027-01-11
sources:
  - id: secure-storage
    resource: ../../lib/features/sync/secure_storage.dart
    title: SecureStorage
    last_modified: 2026-06-16
  - id: privacy-policy
    resource: ../../PRIVACY.md
    title: Lotti privacy policy
    last_modified: 2026-04-29
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

**"Private" is a read filter, not a protection.** With the `private` config flag
off, lists, searches and batch reads leave private entries out — but the row is
stored like any other, and **fetching a single entity by id does not filter**, so a
detail page or a deep link still shows it. See
[persistence](persistence.md#private-visibility-is-gated-three-different-ways) for
the three mechanisms and the exact reads that skip them. Treat it as a
shoulder-surfing affordance, never as a security boundary.

**The caveat: the SQLite databases are not encrypted at rest.** There is no
SQLCipher in the dependency set. On-disk protection relies on OS-level
full-disk encryption — FileVault, BitLocker, Android file-based encryption,
LUKS. Database-level encryption is a known gap, not a shipped feature; do not
document it as one.

# Secrets

**Sync provisioning credentials** go to the OS keystore through
`flutter_secure_storage`, wrapped by `SecureStorage`. That is the Matrix config
JSON — homeserver, user, password.

**The Matrix session is not in the keystore.** `createMatrixClient()` hands the
SDK a plain sqflite database at `<documents>/matrix/lotti_sync.db`, and
`MatrixSdkDatabase.insertClient`/`updateClient` persist `token`, `refreshToken`
and `olmAccount` into it. So the live **access token, refresh token and Olm
identity are at rest in unencrypted SQLite**, protected only by OS-level
full-disk encryption — the same posture as journal content and AI provider keys,
not the keystore posture the config gets.

Worth stating precisely because the two are easy to conflate: the keystore holds
what is needed to *log in*, the SDK database holds what is needed to *stay
logged in*. An attacker with file access does not need the password.

**AI-provider API keys do not.** `AiConfigDb.saveConfig()` persists a provider as
`jsonEncode(config.toJson())`, and that serialized map includes its `apiKey`. So
provider keys live in `ai_config.sqlite` — **one of the databases that is not
encrypted at rest** (see the caveat above). Their on-disk protection is OS-level
full-disk encryption, exactly like journal content.

That asymmetry is worth stating plainly rather than glossing: a threat model
derived from "keys are in the keychain" would be wrong for AI providers. Moving
them into `SecureStorage` is a real hardening opportunity, not a documentation
fix.

`SecureStorage` itself is backed by:

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

See [the AI feature](../features/ai/) for how requests are routed and
[categories](../features/categories.md) for where that consent flag is set.

# Error handling as a privacy surface

Because there is no crash reporter, diagnostics stay local: logs are written to
files in the documents directory and gated per domain (see
[logging and diagnostics](logging-and-diagnostics.md)). Nothing is uploaded.

**There is no in-app log viewer**, which cuts both ways for privacy work. Nothing
in the app surfaces log content, so no screen can leak it — but a user who wants to
help debug has to get the files off the device, and support has no read-only
in-app surface to point them at. Sharing a log is therefore a deliberate file
export, not a tap.

# Where to look

| Concern | File |
|---------|------|
| Keystore wrapper | [`lib/features/sync/secure_storage.dart`](../../lib/features/sync/secure_storage.dart) |
| Matrix client creation | [`lib/features/sync/matrix/client.dart`](../../lib/features/sync/matrix/client.dart) |
| Key verification | [`lib/features/sync/matrix/key_verification_runner.dart`](../../lib/features/sync/matrix/key_verification_runner.dart) |
| Late-key handling | [`lib/features/sync/queue/pending_decryption_pen.dart`](../../lib/features/sync/queue/pending_decryption_pen.dart) |
| Published policy | [`PRIVACY.md`](../../PRIVACY.md) |
