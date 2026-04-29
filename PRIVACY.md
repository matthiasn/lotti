# Lotti Privacy Policy

*Last updated: April 29th, 2026*

Trust at a glance:
- No telemetry or analytics
- Local‑only by default; no Lotti cloud service
- End‑to‑end encrypted sync via Matrix (optional)

## Core Privacy Commitment

Lotti is built on a fundamental principle: **your data belongs to you**. All information you record in Lotti—tasks, audio recordings, journal entries, health data, and personal reflections—is stored exclusively on your own devices. There is no Lotti cloud service, no centralized data collection, and no analytics tracking your usage.

## Data Storage & Ownership

### Local Storage
- All data is stored locally on your devices using SQLite
- No data is uploaded to any Lotti servers (because there are none)
- You maintain complete ownership and control of your information
- Data can be exported at any time for backup or migration

### Device Synchronization
- Sync between your devices uses end-to-end encryption via Matrix protocol
- Encryption keys are exchanged via QR code, never transmitted over the network
- Matrix provides decentralized, secure communication for sync
- No third party has access to your encryption keys or synced data

## AI Integration & Privacy

### Your Choice, Your Control
Lotti offers AI capabilities through various providers, but you control exactly how and when AI is used:

- **Per-Category Configuration**: Choose different AI providers (or none) for each category of data
- **Local-Only Option**: Use Ollama for completely offline AI inference
- **Cloud Providers**: When you choose cloud AI (OpenAI, Anthropic, Gemini), data is:
    - Sent only for specific inference requests you initiate
    - Transmitted using your own API keys
    - Request/response data is transmitted only for inference but may be logged temporarily by the provider according to their retention policy
    - Subject to the provider's privacy policy and data retention practices
    - **Important**: Review your provider's retention policies and privacy settings. Consider requesting zero-retention or enterprise plans if available for enhanced privacy

### GDPR-Compliant Options
- European-hosted AI providers with no-retention policies are available
- These providers process your data without storing it
- You maintain the right to choose which provider to use or to use none at all

## Audio Transcription

- **Local Option**: Use OpenAI's Whisper model running entirely on your device
- **Cloud Option**: Use multimodal AI providers (like Gemini) for transcription
- You choose which method to use on a per-recording basis
- Audio files remain on your device regardless of transcription method

## Device Permissions

Lotti requests only the permissions it actually uses. Each one stays on-device unless you explicitly act in a way that sends data out (e.g. an AI inference call you initiate, or Matrix sync you've enabled).

- **Microphone (`RECORD_AUDIO` / iOS microphone)**: used only when you start an audio recording. Recordings are stored locally; nothing is transmitted unless you choose to transcribe with a cloud provider.
- **Camera (`CAMERA`)**: used only on-device to scan the QR code that exchanges Matrix sync keys between your devices. The camera preview is never recorded, saved, or transmitted.
- **Location (`ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`)**: optional geo-tagging of journal entries you create. Captured coordinates are stored only in your local database and synced (end-to-end encrypted) between your own devices. They are never sent to Lotti, to advertisers, or to any third party. AI providers receive location data only if you explicitly include a geo-tagged entry in an inference request.
- **Health (`health` plugin / HealthKit / Health Connect)**: Lotti can read activity, sleep, heart-rate, workout and similar metrics that you have already chosen to record on your device, so you can correlate them with your journal. Reads are opt-in per category and happen on-device. Health data is never uploaded to a Lotti server (there is none) and is treated like any other journal data: it's only sent to a third party if you explicitly send a containing entry to an AI provider you configured.
- **Storage / media (`READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `ACCESS_MEDIA_LOCATION`)**: used to attach photos and files to journal entries, to import/export data, and to read media you select. Lotti only touches files you pick.
- **Foreground service (`FOREGROUND_SERVICE`)**: used to keep long-running audio recording and sync work alive while the app is in the background, with a system notification visible the whole time. No background data collection happens outside these explicit user actions.
- **Notifications (`POST_NOTIFICATIONS`)**: used for reminders and habit prompts you've set up yourself, and to display the foreground-service notification.
- **Network (`INTERNET`, `ACCESS_NETWORK_STATE`)**: used to talk to the AI providers and Matrix homeserver you configure, and to detect connectivity. Lotti makes no other network calls.

## What We Don't Do

- ❌ No telemetry or usage analytics
- ❌ No cloud accounts or user profiles
- ❌ No data mining or profiling
- ❌ No advertising or marketing tracking
- ❌ No sharing with third parties (except AI providers you explicitly choose)
- ❌ No backend servers collecting your data

## Security Considerations

### Current State
- Device storage currently relies on your device's built-in security
- We strongly recommend enabling device encryption (FileVault on macOS, BitLocker on Windows, etc.)
- End-to-end encryption is used for device synchronization

### Future Improvements
- On-device database encryption is planned for future releases
- Additional security features are under development

## Open Source Transparency

Lotti is fully open source under [LICENSE](LICENSE). This means:
- Anyone can audit the code to verify our privacy claims
- The community can identify and report potential privacy issues
- Development happens in public here on [GitHub](https://github.com/matthiasn/lotti)

## Beta Testing

When participating in beta testing:
- **TestFlight (iOS/macOS)**: Requires providing your Apple ID to receive invitations
- **Google Play (Android)**: Closed and open testing tracks are distributed through the Google Play Store, which collects whatever account/device data Google's own terms describe; Lotti itself receives nothing extra from these channels
- **Other platforms**: Direct download from GitHub Releases requires no personal information

## Your Rights

You have complete control over your data:
- **Access**: Direct access to all your data via the app
- **Export**: Export your data at any time
- **Deletion**: Delete any or all data instantly
- **Portability**: Your data is stored in standard formats
- **Control**: Choose what AI services (if any) can process your data

## Contact

For privacy-related questions or concerns:
- Open an issue on [GitHub](https://github.com/matthiasn/lotti/issues)
- Join the discussion on [GitHub Discussions](https://github.com/matthiasn/lotti/discussions)

## Changes to This Policy

As Lotti evolves, this privacy policy may be updated. Changes will be:
- Announced on the GitHub repository
- Included in release notes
- Never retroactively reduce your privacy rights
- There might come a cloud‑based service for making access to providers simpler without requiring individual API keys, but this would be entirely opt-in and would follow the privacy goals outlined here, with an explicit no data retention policy

---

**Remember**: Lotti is designed for a future where AI augments our capabilities without compromising our privacy. Your data stays yours, always.
