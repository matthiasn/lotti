# Lotti

[![Flathub installs](https://img.shields.io/flathub/downloads/com.matthiasn.lotti?style=flat&label=Flathub%20installs)](https://flathub.org/en/apps/com.matthiasn.lotti) [![GitHub Releases downloads](https://img.shields.io/github/downloads/matthiasn/lotti/total?label=GitHub%20Releases%20downloads)](https://github.com/matthiasn/lotti/releases) [![codecov](https://codecov.io/gh/matthiasn/lotti/graph/badge.svg?token=VB6FWvA1yW)](https://codecov.io/gh/matthiasn/lotti) [![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

**Tasks, time, journal and the people in your life — kept on your own devices,
synced end-to-end encrypted, with AI agents that propose while you decide.**

Lotti is a personal task manager, time tracker and journal. Speak a rambling
voice note and it comes back as a task with a checklist; an agent keeps a
living summary of every task and suggests the next change for you to confirm.
There is no Lotti cloud and no Lotti account: your record lives in a local
database on each of your devices, and the AI runs on a provider you pick — or
on none at all.

In development since 2016. I have tracked around 11,000 hours of my own work
in it since 2022.

<!-- Every screenshot on this page comes from the manual's screenshot catalog
     (docs-site/metadata/screenshot-cases.json), regenerated from the code
     nightly and published to the `development` channel on R2. They age with
     the app; if a case id is renamed, rename it here too. Never commit images. -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/tasks/workspace/desktop-dark.webp">
  <img alt="The task workspace on desktop: tasks grouped by due date, each with cover art, priority and status, beside an open task with its status, priority, due date, time spent and labels" src="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/tasks/workspace/desktop-light.webp">
</picture>

**[Install](#install)** · [Manual](https://matthiasn.github.io/lotti/manual/development/) ·
[Discord](https://discord.gg/uuSaa8NpY) · [Blog series](https://matthiasnehlsen.substack.com/p/meet-lotti)

On the [App Store](https://apps.apple.com/app/lotti-app/id6752654664) (iPhone,
iPad, Mac), [Google Play](https://play.google.com/store/apps/details?id=com.matthiasn.lotti)
and [Flathub](https://flathub.org/en/apps/com.matthiasn.lotti) · Windows from
source — Flutter, GPL-3.0.

## Why Lotti is different

- **Local-first.** Each device holds the whole record in local SQLite, with
  audio and images beside it on disk. No telemetry, no analytics, no account,
  no server that stores a readable copy of your data.
- **End-to-end encrypted sync through a relay you don't have to trust.**
  Devices sync over a [Matrix](https://matrix.org) homeserver that only ever
  sees ciphertext. Keys go only to devices you verified yourself by comparing
  emoji, and anything else is dropped.
- **Agents propose; you decide.** Task, project, goal, event and relationship
  agents read what you recorded and suggest changes. Each suggestion waits for
  you to confirm or dismiss it, apart from a small, named set of pre-approved
  writes such as transcribing a recording
  ([ADR 0102](docs/adr/0102-pre-approved-agent-changes.md)). Agent working
  memory lives in a separate database from your record.
- **Your AI, your choice — or none.** Lotti has no inference backend. You bring
  your own key for Mistral, OpenAI, Anthropic, Gemini and others, or run
  models locally, and route each category of your life to a different
  provider. Lotti is a complete task manager, time tracker and journal with AI
  switched off.

## What it looks like

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/tasks/agent-suggestions/mobile-dark.webp">
    <img width="260" alt="A task agent's summary with two proposed changes, a new checklist item and an estimate, each with dismiss and confirm controls, and Confirm all" src="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/tasks/agent-suggestions/mobile-light.webp">
  </picture>
  &nbsp;
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/onboarding/providers/mobile-dark.webp">
    <img width="260" alt="Onboarding: Lotti, drawn as a grandmother, recommends one provider key, with Mistral preselected and other providers behind a disclosure" src="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/onboarding/providers/mobile-light.webp">
  </picture>
  &nbsp;
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/sync/verification/mobile-dark.webp">
    <img width="260" alt="Confirming a new device: both screens show the same seven emoji, with They match and They differ buttons" src="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/sync/verification/mobile-light.webp">
  </picture>
</p>

<p align="center"><sub>A task agent's proposed changes · choosing an AI provider in onboarding · verifying a new device by emoji</sub></p>

## What you can do with it

- **Tasks** with checklists, estimates, priorities, due dates, labels, cover
  art and linked GitHub pull requests. A **task agent** keeps a living summary
  and proposes titles, estimates, checklist items, status changes, follow-up
  tasks and links — each one waiting for you.
- **Voice capture everywhere.** Record anywhere in the app and have it
  transcribed, on your device or by the provider you configured.
- **Time tracking** against the plan, with focus ratings and a time analysis
  by category.
- **A journal** of notes, photos, recordings, measurements and surveys, linked
  to the task, person, event or day they belong to.
- **Sections you switch on** under Settings → Sections: Projects, Goals,
  Habits, Dashboards, People and Events, each with its own agent where it
  makes sense — a project agent that reports health and next steps, a goal
  agent that tells you when a goal slips, an event agent that writes a recap,
  and a relationship agent that briefs you before you meet someone. Turning a
  section off only hides it; nothing is deleted.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/events/detail/desktop-dark.webp">
  <img alt="An event page: cover photo, rating, an AI recap of the evening, and the event agent proposing to add a person who was there and a note of what happened" src="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/events/detail/desktop-light.webp">
</picture>

The [manual](https://matthiasn.github.io/lotti/manual/development/) walks
through all of it, starting from
[the mental model](https://matthiasn.github.io/lotti/manual/development/getting-started/mental-model)
and [your first task](https://matthiasn.github.io/lotti/manual/development/getting-started/first-task/).

## Install

| Platform    | Where to get it                                                                                                                                                            |
|-------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **iOS / iPadOS** | [App Store](https://apps.apple.com/app/lotti-app/id6752654664)                                                                                                     |
| **macOS**   | [Mac App Store](https://apps.apple.com/app/lotti-app/id6752654664), or the signed and notarized DMG on [Releases](https://github.com/matthiasn/lotti/releases)             |
| **Android** | [Google Play](https://play.google.com/store/apps/details?id=com.matthiasn.lotti), or the APK on [Releases](https://github.com/matthiasn/lotti/releases)                    |
| **Linux**   | [Flathub](https://flathub.org/en/apps/com.matthiasn.lotti) (recommended, updates itself), or the AppImage or `tar.gz` on [Releases](https://github.com/matthiasn/lotti/releases) |
| **Windows** | [Build from source](docs/DEVELOPMENT.md) for now                                                                                                                             |

<!-- One App Store listing covers iPhone, iPad and Mac (universal purchase). -->
<p>
  <a href="https://apps.apple.com/app/lotti-app/id6752654664"><img height="48" alt="Download on the App Store" src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/en-us"></a>
  <a href="https://apps.apple.com/app/lotti-app/id6752654664"><img height="48" alt="Download on the Mac App Store" src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-mac-app-store/black/en-us"></a>
  <a href="https://play.google.com/store/apps/details?id=com.matthiasn.lotti"><img height="70" alt="Get it on Google Play" src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png"></a>
  <a href="https://flathub.org/en/apps/com.matthiasn.lotti"><img height="48" alt="Get it on Flathub" src="https://flathub.org/api/badge?locale=en"></a>
</p>

The **AppImage** needs no installation: mark it executable (`chmod +x`) and
run it. It works on distributions with glibc 2.35 or newer (Ubuntu 22.04,
Debian 12, Fedora 36 and later); where FUSE is missing, start it with
`--appimage-extract-and-run`. Unlike the Flathub build it does not update
itself.

On first launch, a short onboarding asks for one API key — Mistral is
preselected, others are one tap away — and records your first task. You can
close it and use Lotti without AI.

## Privacy and sync, in brief

**What leaves your device:** ciphertext to the sync homeserver you chose, which
stores and relays it without ever being able to read it; requests to the AI
provider you configured for a category; and calls to `api.github.com`, only if
you link pull requests to tasks. None of your record goes to Lotti.

**How sync works:** each change is an event in a private, non-federated,
Megolm-encrypted Matrix room ([Vodozemac](https://github.com/matrix-org/vodozemac)
for Olm/Megolm); attachments are encrypted per file. Keys are shared only with
devices you verified by emoji, and events from anything else — or sent in
plaintext — are dropped. Every entry carries a vector clock, so a device that
was offline for a week rejoins without losing writes, and genuinely concurrent
edits show up as conflicts for you to resolve. You set up the first device
against a homeserver with the included
[`tools/matrix_provisioner`](tools/matrix_provisioner); every further device
pairs from one you already use by QR code and emoji check.

**What it does not protect against — read this before you trust it with
anything sensitive:**

- **Metadata.** The homeserver operator cannot read or alter your record, but
  can see the account, which device synced when, from which IP, and how much.
- **A compromised device.** The local databases are not encrypted by Lotti
  today; rely on your operating system's full-disk encryption. Passwords, API
  keys and the GitHub token are kept in the OS keystore.
- **Losing every device.** There is no server-side backup and no account
  recovery. A second paired device is your replica — after you send it your
  history from the first — and an ordinary backup of the database plus the
  attachments folder is still worth keeping.
- **Your AI provider.** Whatever you route to a provider is subject to its
  terms. Prefer one with zero data retention; Lotti cannot verify anyone's
  retention claims.

The full threat model is in
[security and privacy](knowledge/architecture/security-and-privacy.md), the
sync runtime in [the sync concept](knowledge/features/sync/overview.md), and
the policies in [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

## AI, on your terms

- **Providers:** Mistral (recommended in onboarding: one key covers thinking,
  transcription and the read-aloud voice), Melious, OpenAI, Anthropic, Google
  Gemini, Alibaba, Nebius, OpenRouter, ElevenLabs for voices, and any
  OpenAI-compatible endpoint, including your own gateway.
- **Local:** speech recognition runs inside the app on every platform with
  sherpa-onnx (Whisper and other model families), and on desktop also through
  local Whisper or Voxtral servers. Ollama and oMLX have their own provider
  types; vLLM, llama.cpp's `llama-server`, LM Studio and similar servers
  connect as OpenAI-compatible endpoints.
- **Routing per category:** work can go to one provider, your journal to
  another, or to none. The provider page shows the actual base URL behind a
  friendly name, and every profile that depends on it.
- **Usage & Impact** shows tokens and requests for every cloud call, and cost,
  energy and CO₂e where the provider reports them (today: Melious). Nothing is
  estimated.
- **Which models are good enough** for the agents is measured, not guessed:
  [LottiGym](knowledge/features/ai/model-evaluation.md) runs candidates
  through the real agent harnesses ([results](docs/evaluations/)). Today the
  agents need a cloud-class model; local models are not yet fast enough for
  daily agent use.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/ai/usage/desktop-dark.webp">
  <img alt="Usage &amp; Impact: cost, energy, CO2e, tokens and requests for the month, with cost per day broken down by category" src="https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/manual/screenshots/development/ai/usage/desktop-light.webp">
</picture>

Setup is in the manual:
[connect an AI provider](https://matthiasn.github.io/lotti/manual/development/ai-and-automation/provider-setup/).

## In development

Built, documented, and changing quickly. Each is off by default.

- **Daily OS** — turns a spoken or typed check-in into a plan for the day,
  every proposed change shown with its reason, nothing committed until you
  confirm. Switch it on under Settings → Sections.
  [Manual](https://matthiasn.github.io/lotti/manual/development/plan-and-capture/daily-os)
- **The companion** — Lotti as a character you talk to: ask about your tasks,
  time and journal by voice or text, and hear the answer read aloud. Behind a
  flag in Settings → Advanced Settings → Config Flags.
- **Record provenance** — every entry signed by its author, so the record can
  prove who wrote what. The building blocks are in the codebase; entries are
  not signed yet.

See the [roadmap](https://matthiasn.github.io/lotti/manual/development/roadmap).

## Build from source

Install Flutter through [FVM](https://fvm.app/) (the repository pins the
version in `.fvmrc`), then:

```sh
make deps
fvm flutter run -d macos   # or linux, windows, or a connected device
```

Platform prerequisites (including Linux audio-codec and emoji-font packages)
are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Under the hood

Flutter and Dart on five platforms; local SQLite via Drift; Matrix with
Vodozemac for sync. The sync protocol and the agent runtime are specified as
[TLA+ models](specs/tla/README.md) and model-checked nightly under crashes,
injected failures and reordered messages — statements about the design, with
the specs saying exactly what is and isn't covered.

- [Knowledge bundle](knowledge/index.md) — how the app works at runtime,
  subsystem by subsystem, for contributors and coding agents alike
- [Security and privacy](knowledge/architecture/security-and-privacy.md) ·
  [Background](docs/BACKGROUND.md) — the threat model, and why Lotti exists
- [Changelog](CHANGELOG.md)

## Pricing

Linux is free, with full functionality, and will stay that way. On other
platforms the basics — task and journal capture, the task agent, voice
transcription — stay free too; some advanced agent features may eventually
become in-app purchases where that is the norm. Hosted sync is a real running
cost: self-host a Matrix homeserver, or bring one you already have.

## Contributing

Say hi on [Discord](https://discord.gg/uuSaa8NpY). **Bug reports** in
[GitHub Issues](https://github.com/matthiasn/lotti/issues) and
**translations** are very welcome. **Code pull requests are not accepted** —
review capacity is the limit, and Lotti holds people's personal data — so
please open an issue instead. [CONTRIBUTING.md](CONTRIBUTING.md) has the
details.

## License

GPL-3.0. See [LICENSE](LICENSE).

## Acknowledgments

Thanks to the [Flutter](https://flutter.dev) team, the
[Qwen](https://github.com/QwenLM) and [Mistral](https://mistral.ai) teams for
their open-weights models, [OpenAI](https://openai.com) for the
[Whisper](https://github.com/openai/whisper) weights, the
[Ollama](https://ollama.com) project, the [Matrix.org](https://matrix.org)
community, the [Vodozemac](https://github.com/matrix-org/vodozemac) authors, and
everyone contributing translations, issues, and ideas.
