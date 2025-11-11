# PalakNewAIProjectLotti

[![codecov](https://codecov.io/gh/matthiasn/lotti/graph/badge.svg?token=VB6FWvA1yW)](https://codecov.io/gh/matthiasn/lotti)
[![CodeFactor](https://www.codefactor.io/repository/github/matthiasn/lotti/badge)](https://www.codefactor.io/repository/github/matthiasn/lotti)
**Your AI‑powered context manager — a private, local‑first assistant for your tasks, notes, and audio.**

Lotti is an open-source personal assistant that helps you capture, organize, and understand your work and life through AI-enhanced task management, audio recordings, and intelligent summaries—all while keeping your data entirely under your control.

![AI Assistant](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.662+3261/tasks_category_summary.png)

Read more on [**Substack**](https://matthiasnehlsen.substack.com) | [**Project Background**](docs/BACKGROUND.md)

## Table of Contents
- [Why Lotti?](#why-lotti)
  - [Example Use Cases](#example-use-cases)
- [Core Features](#core-features)
  - [AI-Powered Intelligence](#ai-powered-intelligence)
  - [Comprehensive Tracking](#comprehensive-tracking)
  - [Privacy & Control](#privacy--control)
- [AI Provider Configuration](#ai-provider-configuration)
- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [Beta Testing](#beta-testing)
  - [Development](#development)
- [Documentation](#documentation)
- [Use Cases](#use-cases)
  - [For Developers](#for-developers)
  - [For Knowledge Workers](#for-knowledge-workers)
  - [For Personal Growth](#for-personal-growth)
- [Contributing](#contributing)
- [Technical Stack](#technical-stack)
- [Philosophy](#philosophy)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Why Lotti?

Most AI-powered tools require you to upload and store your personal data on their servers, creating privacy risks and vendor lock-in. Lotti takes a different approach:

- **Complete data ownership**: Your information stays on your devices. When you opt into cloud inference, European‑hosted, no‑retention providers are available
- **Configurable AI providers per category**: Choose between OpenAI, Anthropic, Gemini, Ollama (local), or any OpenAI-compatible provider on a per-category basis
- **Privacy-first design**: You control exactly what data gets shared with AI providers—only for specific inference calls via your API keys
- **No vendor lock-in**: Your data remains portable and accessible, independent of any subscription

### Example Use Cases

- Pick up a task from last week — see your last notes, time spent, and a one‑paragraph recap
- Record a quick voice note — later it’s transcribed and turned into a checklist
- Ask “What did I finish in June?” — get a dated list with brief summaries

## Core Features

*Currently, Lotti's AI capabilities are focused on task management and productivity. Habit tracking is fully functional but will receive AI enhancements in future updates.*

### 🤖 AI-Powered Intelligence

- **Smart Summaries**: Automatically generate summaries of tasks, capturing key points and progress
- **Audio Transcription**: Transcribe recordings using either local Whisper (OpenAI's open weights model, 99 languages supported) or cloud providers with audio capabilities like Gemini Flash/Pro
- **Context Recap**: Resume a task with a one‑screen recap of your latest notes, time, and progress
- **Intelligent Checklists**: Transform rambling audio notes into actionable checklists
- **Chat with Your Data**: Ask questions about your tasks, learnings, and achievements across any time period

### 📝 Comprehensive Tracking

- **Tasks**: Full lifecycle management (open, groomed, in progress, blocked, done, rejected)
- **Audio Recording**: Capture thoughts, progress notes, and brain dumps
- **Time Tracking**: Record time spent on tasks and projects
- **Journal Entries**: Written reflections and documentation
- **Habits**: Define and monitor daily habits and routines
- **Health Data**: Import from Apple Health and other sources
- **Custom Metrics**: Track anything that matters to you

### 🔐 Privacy & Control

- **Local-Only Storage**: All data is permanently stored only on your devices and never in the cloud
- **Encrypted Sync**: End-to-end encrypted synchronization between your devices (desktop/laptop and mobile) using **[Matrix](https://matrix.org)** (requires a Matrix account — self-hosted or public homeserver)
- **Selective AI Usage**: Configure AI providers per category—keep sensitive data completely local with Ollama but use state‑of‑the‑art (frontier) cloud models when appropriate
- **Your API Keys**: When you choose cloud AI, data is shared only for that specific inference call. Please review the respective provider's terms and privacy policy to understand how they handle your data
- **GDPR-Compliant Options**: European-hosted AI providers with no data retention policies available for enhanced privacy
- **Built for on‑device**: Designed for the era when local AI inference becomes standard 

## AI Provider Configuration

Lotti supports multiple AI providers, configurable per category:

- **Cloud Providers**: OpenAI, Anthropic Claude, Google Gemini
- **Local Inference**: Ollama for complete privacy (requires capable hardware)
  - Full functionality available with local models like Qwen3 (8B), GPT-OSS (20B/120B), Gemma3 (12B/27B)
  - Combined with local Whisper for speech recognition, enables 100% offline AI capabilities
- **OpenAI-Compatible**: Any provider with OpenAI-compatible APIs
- **European Options**: GDPR-compliant hosted alternatives

Configure different providers for different aspects of your life—use cutting-edge models for work projects while keeping personal reflections completely private with local inference. With sufficient hardware, you can run everything locally without any cloud dependency.

## Getting Started

### Installation

See [DEVELOPMENT.md](docs/DEVELOPMENT.md) for setup and development workflow.

### Beta Testing

- **Build it yourself**: for iOS, macOS, Android, Linux, Windows
- **iOS/macOS**: TestFlight builds are available for select users, will be available more broadly in due course
- **Linux**: See `tar.gz` files on **[GitHub releases](https://github.com/matthiasn/lotti/releases)** - will also be available via Flatpak soon

### Development

- Install Flutter ([instructions](https://docs.flutter.dev/get-started/install)) — FVM recommended; repo includes `.fvmrc`
- Install dependencies: `make deps`
- **Linux only**: Install emoji font support for proper emoji rendering:
  ```bash
  # First install the Noto Color Emoji font package:
  # Debian/Ubuntu: sudo apt install fonts-noto-color-emoji
  # Fedora: sudo dnf install google-noto-emoji-color-fonts
  # Arch: sudo pacman -S noto-fonts-emoji

  # Then configure fontconfig:
  ./linux/install_emoji_fonts.sh
  ```
- Static analysis: `make analyze`
- Tests: `make test` • Coverage report: `make coverage`
- Code generation: `make build_runner` • Localization: `make l10n`
- Run locally: macOS `fvm flutter run -d macos` • others `flutter run -d <device>`

See [DEVELOPMENT.md](docs/DEVELOPMENT.md) for detailed development setup.

## Documentation

- [Manual](docs/MANUAL.md) - How to use Lotti
- [Background Story](docs/BACKGROUND.md) - The inspiration and evolution of Lotti
- [Architecture](docs/ARCHITECTURE.md) - Technical design and AI integration
- [Privacy Policy](PRIVACY.md) - Our commitment to your privacy
- [Contributing](CONTRIBUTING.md) - How to help and our standards

## Use Cases

### For Developers
- Track project progress with automatic context recovery
- Document decisions and learnings with searchable audio notes
- Generate sprint summaries and retrospectives from your task data

### For Knowledge Workers
- Maintain focus with AI-powered context switching
- Build a searchable knowledge base from daily work
- Track time and generate reports across projects

### For Personal Growth
- Monitor habits and health metrics
- Reflect on achievements and learnings over time
- Keep a multilingual audio journal

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Technical Stack

- **Frontend**: Flutter (iOS, macOS, Android, Windows, Linux)
- **AI Integration**: Multiple providers with streaming support, including Ollama for 100% private local inference
- **Audio**: Local Whisper (OpenAI's open weights model) or cloud providers with multimodal audio support
- **Storage**: Local SQLite, no cloud storage
- **Synchronization**: End-to-end encrypted sync using **[Matrix](https://matrix.org)** infrastructure (requires a Matrix account)
- **Testing**: Comprehensive unit and integration tests


## Philosophy

Lotti represents a different approach to AI-powered productivity:

1. **Your data stays yours**: No company should own your thoughts and experiences
2. **AI as a tool, not a service**: Use AI capabilities without subscription lock-in
3. **Privacy by design**: Choose exactly what to share, when, and with whom
4. **Future-focused**: Built for the coming era of powerful local AI

## License

Lotti is open source under [LICENSE](LICENSE).

## Acknowledgments

Special thanks to the Flutter team, OpenAI for the Whisper model, and all contributors who believe in privacy-respecting AI tools.

---

**Building in public** • Follow development here on [GitHub](https://github.com/matthiasn/lotti) • Read updates on [Substack](https://matthiasnehlsen.substack.com)
