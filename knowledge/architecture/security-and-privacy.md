---
type: Architecture
title: Security and privacy posture
description: What is encrypted, what is not, where secrets live, and what leaves the device.
resource: ../..
tags: [architecture, security, privacy, encryption, secure-storage]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-03T12:00:00Z }
stale_after: 2027-01-11
sources:
  - id: secure-storage
    resource: ../../lib/features/sync/secure_storage.dart
    title: SecureStorage
    last_modified: 2026-06-16
  - id: event-trust
    resource: ../../lib/features/sync/matrix/sync_event_trust.dart
    title: SyncEventTrust — inbound sender trust
    last_modified: 2026-10-03
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

**AI-provider API keys live there too.** `AiConfigDb` strips a provider's
`apiKey` from the row it writes to `ai_config.sqlite` and keeps the key in
`SecureStorage` through `AiApiKeyStorage`, under
`ai_provider_api_key:<namespace>:<config id>`; reading a provider puts the key
back. The key does travel in the `aiConfig` sync message, so it is protected in
transit by the sync channel's end-to-end encryption, and an outbox row waiting
to be sent holds it like any other payload.

**The GitHub token works the same way.** `GitHubTokenStorage` keeps one record
per profile in `SecureStorage` — the token, its login and the stamp of the
change — and the `gitHubAccount` sync message carries it to the user's other
devices end-to-end encrypted (ADR 0115). The token is a `SyncSecret` in the
message, so neither the message nor a log line prints it.

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
  Dec --> Trust["SyncEventTrust: sender device verified?"]
  Trust --> Queue["InboundEventQueue"]
  Queue --> Apply["SyncEventProcessor → local databases"]
```

The homeserver relays ciphertext it cannot read. Device trust is established
through Matrix key verification (`key_verification_runner.dart`) and enforced
in both directions. Outbound, room keys are shared only with directly verified
devices ([ADR 0045](../../docs/adr/0045-exclude-unverified-devices-from-key-sharing.md)).
Inbound, `SyncEventTrust` applies an event only when a device this one shares
its keys with created the Megolm session that decrypted it; plaintext, forwarded
sessions and unverified or blocked devices are dropped
([ADR 0113](../../docs/adr/0113-inbound-sync-trusts-only-key-sharing-peers.md)).
Without the inbound half, whoever can post into the room — the account holder
or the homeserver's operator — could inject sync payloads, because the Matrix
SDK checks neither. Events that arrive before their session key lower a durable
receive-floor timestamp before being skipped. The Matrix SDK retains the ciphertext; late key traffic
then triggers a catch-up walk back to that floor, including across app restart.
Because SDK pagination may return a cached encrypted event even after storing
the key, the bootstrap sink makes one fresh SDK decryption attempt on each
revisit before deciding that the event remains unresolved.

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
| Inbound sender trust | [`lib/features/sync/matrix/sync_event_trust.dart`](../../lib/features/sync/matrix/sync_event_trust.dart) |
| Late-key handling | [`lib/features/sync/queue/bootstrap_sink.dart`](../../lib/features/sync/queue/bootstrap_sink.dart), [`lib/features/sync/queue/bridge_coordinator.dart`](../../lib/features/sync/queue/bridge_coordinator.dart) |
| Published policy | [`PRIVACY.md`](../../PRIVACY.md) |
