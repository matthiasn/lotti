# Lotti Privacy Policy

*Last updated: July 29th, 2026*

Trust at a glance:
- No telemetry, no analytics, no crash reporting
- Local-only by default; there is no Lotti cloud service and no Lotti account
- Optional end-to-end encrypted sync between your own devices via Matrix
- Optional AI, routed per category to a provider you choose, under your own key

## Core Privacy Commitment

Lotti is built on a fundamental principle: **your data belongs to you**. Everything you record in Lotti — tasks, audio recordings, journal entries, health data, and personal reflections — is stored on your own devices. There is no Lotti cloud service, no centralized data collection, and no analytics tracking your usage.

This is structural rather than a promise about intentions: there is no server for the data to go to, and you can confirm that by reading the source or watching the network traffic.

## Data Storage & Ownership

### Local Storage
- Journal records, tasks and metrics are stored locally in SQLite databases; audio, images and other attachments are stored as files in the local filesystem alongside them
- No data is uploaded to any Lotti servers, because there are none
- You keep complete ownership and control of your information
- Your logbook is an ordinary SQLite file on your own disk. There is no export wizard, because there is nothing to unlock: you can read the database directly with any SQLite client. Take a consistent copy with `VACUUM INTO` while the app is running, and copy the attachments directory alongside it, since audio and images live on the filesystem rather than in the database. On phones the database sits inside the app sandbox, so the practical route is to pair a desktop and copy from that device.
- There is no server-side backup and no account recovery, because there is no account. Sync is the redundancy story, but pairing alone does not make a backup: a newly paired device receives what is written from then on, while your existing settings and earlier entries arrive only when you run *Send settings* and *Send message history* from a device that already holds them. Do that soon after pairing, and keep an ordinary device backup as well.

### Device Synchronization
- Sync between your own devices is end-to-end encrypted using the Matrix protocol with **Vodozemac** (Rust) for Megolm crypto. The homeserver relays ciphertext and never sees your entries.
- **How pairing actually works.** The QR code you scan carries a pairing bundle — homeserver, account id, room id and a live account password — from a device that already syncs to one that does not. Treat that screen the way you would treat your password, because that is what it contains: anyone who scans or photographs it can sign in to your sync account. They could not decrypt your entries without also being emoji-verified from one of your devices, but they could take the account over, change its password and lock you out. Show it only to a device you own, and never through a chat, a screenshot or a shared screen. Both devices then display a six-character check code derived from the account, room and homeserver; it is a recognition aid that catches a wrong-code mistake, not a security control.
- **Encryption keys are shared only with devices you have verified** through the emoji comparison ceremony. They travel device-to-device over the homeserver, encrypted so the homeserver cannot read them — not in the QR code. A device that has joined the account but has not completed verification receives ciphertext it cannot read.
- No third party has access to your encryption keys or to the content of your synced data.
- **What this does not protect:** metadata. Whoever operates the homeserver can observe that a device synced, when, and roughly how much data moved — but not what it contains. If that matters to you, run the homeserver yourself.

## AI Integration & Privacy

### Your Choice, Your Control
Lotti has no inference backend of its own. Every AI call goes to a provider you configured, and you control how and when AI is used:

- **Per-category configuration**: choose a different AI provider — or none — for each category of your life
- **Local-only option**: run inference entirely offline via Ollama or oMLX
- **Cloud providers**: when you choose a cloud provider, data is
    - sent only for the specific inference request it is needed for,
    - transmitted using your own API key, under your own account with that provider,
    - subject to that provider's privacy policy and retention practices, which may include logging your requests,
    - **your decision to review**: read the retention policy of the provider you pick, and consider a zero-retention or enterprise plan if they offer one
- **Routing is decided in settings, not in the moment.** Which provider handles a category is a configuration choice you make in advance. Be aware of the flip side: once a category is configured, work in it can reach that provider without a further prompt — an agent waking on a change, or a recording being transcribed, does not stop to ask again. There is no just-in-time notice at that point, so the setting is the consent.
- **A friendly display name is not the boundary.** The provider detail view shows the real base URL, the models attached to it, and every profile depending on them.
- **Usage & Impact** records every request that left the machine and which model served it. Token counts are recorded for every provider. Cost, energy, CO₂e and water are recorded only when the provider returns them alongside the response — today that means Melious; for every other provider those fields stay empty rather than estimated. Local inference is not measured.

### Choosing a jurisdiction
- Providers hosted in the EU are supported, as are US and Chinese providers, and fully local inference. Onboarding highlights [Melious.ai](https://melious.ai), which states that requests are not used for training and that data stays under European jurisdiction.
- Those are the provider's claims, on their terms. Lotti does not rank providers, does not summarise their terms, and cannot verify anyone's assertions about jurisdiction, retention or training. Picking a provider is your decision, and the due diligence is yours.
- A LAN endpoint deserves the same scrutiny: "local" means it did not go to a hosted provider, not that no network hop occurred.

## Audio Transcription

- **Local option**: Whisper or Voxtral, running entirely on your device
- **Cloud option**: a provider with audio support, such as Gemini, OpenAI, Mistral or Melious.ai
- You choose which applies, per category
- Audio files stay on your device regardless of which you use

## Device Permissions

Lotti requests only the permissions it actually uses. What each one captures stays on-device unless it reaches a destination you configured — an AI provider set for that category, or Matrix sync you enabled. Once configured, those transfers can happen without a further prompt, including automatically: an agent waking on a change, or a recording being transcribed.

- **Microphone (`RECORD_AUDIO` / iOS microphone)**: used only when you start an audio recording. Recordings are stored locally; nothing is transmitted unless you choose to transcribe with a cloud provider.
- **Camera (`CAMERA`)**: used only on-device to scan the pairing QR code when adding one of your own devices to sync. The camera preview is never recorded, saved, or transmitted.
- **Location (`ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`)**: optional geo-tagging of journal entries you create. Captured coordinates are stored only in your local database and synced (end-to-end encrypted) between your own devices. They are never sent to Lotti, to advertisers, or to any third party. AI providers receive location data only if you explicitly include a geo-tagged entry in an inference request.
- **Health (`health` plugin / HealthKit / Health Connect)**: Lotti can read activity, sleep, heart-rate, workout and similar metrics that you have already chosen to record on your device, so you can correlate them with your journal. Reads are opt-in per category and happen on-device. Health data is never uploaded to a Lotti server (there is none) and is treated like any other journal data: it reaches a third party only when an entry containing it goes to an AI provider you configured — whether you send it yourself or an agent you enabled for that category picks it up.
- **Storage / media (`READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `ACCESS_MEDIA_LOCATION`)**: used to attach photos and files to journal entries and to read media you select. Lotti only touches files you pick.
- **Foreground service (`FOREGROUND_SERVICE`)**: used to keep long-running audio recording and sync work alive while the app is in the background, with a system notification visible the whole time. No background data collection happens outside these explicit user actions.
- **Notifications (`POST_NOTIFICATIONS`)**: used for reminders and habit prompts you've set up yourself, and to display the foreground-service notification.
- **Network (`INTERNET`, `ACCESS_NETWORK_STATE`)**: used to talk to the AI providers and Matrix homeserver you configure, and to detect connectivity. Lotti makes no other network calls.

## What Lotti Does Not Do

- ❌ No telemetry, usage analytics, or crash reporting
- ❌ No cloud accounts or user profiles
- ❌ No data mining or profiling
- ❌ No advertising or marketing tracking
- ❌ No sharing with third parties, except the AI providers you configure
- ❌ No backend servers collecting your data

To be precise about what this does *not* say: two destinations you choose do receive something. The homeserver you configure receives, stores and relays your sync payloads as ciphertext, and can see the account and traffic metadata that comes with them. The AI providers you configure receive the content of the requests routed to them. Neither is Lotti, and neither gets plaintext it was not given deliberately.

Diagnostic logs are local too. *Settings → Advanced → Logging* controls routine diagnostic logging per domain; errors are always recorded regardless of those toggles. Either way the files stay on your device until you choose to share them.

## Security Considerations

### Current state
- **The local databases are not encrypted at rest by Lotti.** They live inside your OS user account and rely on your device's own protection. This is a real caveat: someone with OS-level access to your device can read them.
- Please enable full-disk encryption (FileVault on macOS, BitLocker on Windows, LUKS on Linux, and the default protection on iOS and Android).
- Sync between devices is end-to-end encrypted, and keys reach only devices you have verified.
- If at-rest encryption matters for your threat model, weigh that before putting your most sensitive categories into Lotti.

### Planned
- On-device database encryption is a candidate for a future release.

## Open Source Transparency

Lotti is fully open source under [LICENSE](LICENSE). This means:
- Anyone can audit the code to verify the claims on this page
- The community can identify and report potential privacy issues
- Development happens in public here on [GitHub](https://github.com/matthiasn/lotti)

## Beta Testing

When participating in beta testing:
- **TestFlight (iOS/macOS)**: requires providing your Apple ID to receive invitations
- **Google Play (Android)**: testing tracks are distributed through the Google Play Store, which collects whatever account and device data Google's own terms describe. Lotti itself receives nothing extra from these channels.
- **Flathub and GitHub Releases**: direct download requires no personal information. Flathub publishes aggregate download counts; no per-user data reaches Lotti.

## Your Rights

You have complete control over the data on your own devices. These rights apply to each local copy, and every copy has to be dealt with separately — Lotti cannot reach across your devices for you.

- **Access**: directly through the app, and directly in the SQLite database it stores
- **Portability**: the schema is documented and the format is ordinary SQLite, readable without Lotti
- **Deletion**: delete entries in the app, which removes the record and its attachments together. Deleting the database files by hand is not equivalent: attachment cleanup works by walking deleted rows, so removing the databases first strands the audio and images on disk. Delete in the app first, then remove the files if you want the directories gone.
- **Other copies are yours to clear too**: each paired device holds its own replica, ordinary backups hold their own snapshots, and anything already sent to an AI provider is governed by that provider's retention policy. None of those are touched by a local deletion.
- **Control**: choose which AI services, if any, may process your data — per category

## Contact

For privacy questions or concerns:
- Open an issue on [GitHub](https://github.com/matthiasn/lotti/issues)
- Join the discussion on [GitHub Discussions](https://github.com/matthiasn/lotti/discussions)

For a **security vulnerability**, please do not open a public issue — follow [SECURITY.md](SECURITY.md) instead.

## Changes to This Policy

As Lotti evolves, this privacy policy may be updated. Changes will be:
- Announced on the GitHub repository
- Included in release notes
- Never applied retroactively to reduce your privacy rights

A hosted service that made provider access simpler without individual API keys may eventually exist. It would be entirely opt-in, would not become a condition of using Lotti, and would follow the commitments on this page, including an explicit no-retention policy.

---

**Remember**: Lotti is designed for a future where AI augments our capabilities without compromising our privacy. Your data stays yours, always.
