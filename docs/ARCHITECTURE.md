# Lotti Architecture

## Table of Contents
- [Overview](#overview)
- [Core Principles](#core-principles)
- [High-Level Architecture](#high-level-architecture)
- [Feature Modules](#feature-modules)
- [Data Flow](#data-flow)
- [AI Provider Architecture](#ai-provider-architecture)
- [Security Architecture](#security-architecture)
- [Testing Strategy](#testing-strategy)
- [Build & Deployment](#build--deployment)
- [Performance Considerations](#performance-considerations)
- [Future Architecture Plans](#future-architecture-plans)
- [Development Guidelines](#development-guidelines)
- [Related Documentation](#related-documentation)

## Overview

Lotti is a privacy-first personal assistant built with Flutter, featuring local-first data storage, AI integration, and end-to-end encrypted synchronization. The architecture prioritizes data ownership, privacy, and extensibility while providing powerful AI capabilities.

## Core Principles

1. **Local-First**: All data is stored locally using SQLite, with no cloud dependency
2. **Privacy by Design**: User data never leaves devices unless explicitly shared for AI inference
3. **Modular Architecture**: Features are organized as independent modules with clear boundaries
4. **Provider Agnostic**: AI capabilities work with multiple providers (OpenAI, Anthropic, Gemini, Ollama)
5. **Cross-Platform**: Single codebase for iOS, macOS, Android, Windows, and Linux

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer (Flutter)                    │
├─────────────────────────────────────────────────────────────┤
│                     Feature Modules                          │
│  ┌──────────┬────────────┬──────────┬──────────────────┐   │
│  │ Tasks    │ AI Chat    │ Journal  │ Habits & Health  │   │
│  ├──────────┼────────────┼──────────┼──────────────────┤   │
│  │ Audio    │ Categories │ Sync     │ Settings         │   │
│  └──────────┴────────────┴──────────┴──────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                     Core Services                            │
│  ┌──────────────┬───────────────┬──────────────────────┐   │
│  │ Database     │ AI Providers  │ Audio Processing     │   │
│  │ (SQLite)     │ Integration   │ (Whisper)           │   │
│  └──────────────┴───────────────┴──────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                  Infrastructure Layer                        │
│  ┌──────────────┬───────────────┬──────────────────────┐   │
│  │ Persistence  │ Encryption    │ Background Tasks     │   │
│  │ & Migration  │ (Matrix Sync) │ & Notifications      │   │
│  └──────────────┴───────────────┴──────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Feature Modules

### AI Integration
- **[AI Module](../lib/features/ai/README.md)**: Core AI provider abstraction and configuration
- **[AI Chat](../lib/features/ai_chat/README.md)**: Interactive chat with context-aware AI assistance

### Content Management
- **[Tasks](../lib/features/tasks/README.md)**: Task lifecycle management with AI-enhanced summaries
- **[Journal](../lib/features/journal/README.md)**: Text and audio journal entries with transcription
- **[Categories](../lib/features/categories/README.md)**: Organize content with configurable AI providers per category

### Audio & Speech
- **[Speech](../lib/features/speech/README.md)**: Audio recording and transcription using Whisper or cloud providers

### Data & Visualization
- **Calendar**: Time-based views of entries and activities
- **Dashboards**: Analytics and insights from collected data
- **Habits**: Habit tracking and completion monitoring
- **Surveys**: Custom questionnaires and assessments

### System Features
- **Settings**: Configuration management and preferences
- **Sync**: End-to-end encrypted synchronization via Matrix (requires Matrix account - self-hosted or public homeserver)
- **Tags**: Flexible tagging system for organization
- **User Activity**: Activity tracking and analytics

## Data Flow

### 1. Local Data Storage
```
User Input → SQLite Database → UI Updates
```
All user data is stored in a local SQLite database with support for:
- Full-text search
- Efficient querying
- Data export/import
- Incremental backups

### 2. AI Processing Pipeline
```
User Request → Category Config → Provider Selection → API Call → Response Processing
```
- Users can configure different AI providers per category
- Requests are routed to the appropriate provider
- Responses are processed and stored locally
- No data retention on provider side (with appropriate plans)

### 3. Synchronization
```
Local Changes → Encryption → Matrix Protocol → Other Devices
```
- Changes are encrypted locally
- Transmitted via Matrix's decentralized network
- Decrypted on receiving devices
- Conflict resolution handled automatically

## AI Provider Architecture

### Provider Abstraction
The system supports multiple AI providers through a unified interface.

Note: The interface below is conceptual to illustrate the design. The production code uses configuration models such as `AiConfigInferenceProvider` and repositories (for example `lib/features/ai/conversation/conversation_repository.dart`) to orchestrate requests and streaming.

```dart
abstract class AiProvider {
  Stream<String> sendMessage(String message, List<Message> context);
  Future<String> transcribe(AudioData audio);
  bool get supportsStreaming;
  bool get supportsAudio;
}
```

#### Error handling and retries
- Provider‑specific error parsing (e.g., model not found, rate limits) with user‑friendly messages
- Exponential backoff for transient errors; fail fast for configuration issues
- Optional fallbacks between configured providers when applicable

### Supported Providers
1. **OpenAI**: GPT-4, GPT-3.5, Whisper
2. **Anthropic**: Claude 3.5, Claude 3
3. **Google**: Gemini Pro, Gemini Flash
4. **Ollama**: Local models (Llama, Mistral, etc.)
5. **OpenAI-Compatible**: Any provider with compatible API

### Configuration Management
- Per-category provider selection
- API key management (stored securely)
- Model selection within providers
- Fallback strategies for failures

## Security Architecture

### Data Protection
- **At Rest (today)**: Local databases are stored as plain SQLite. We recommend enabling full‑disk/device encryption (e.g., FileVault on macOS, BitLocker on Windows, File‑based encryption on Android, LUKS on Linux)
- **In Transit**: TLS for all network communication
- **Sync**: End-to-end encryption via Matrix
- **AI Calls**: HTTPS with API key authentication

### Key Storage (API keys and secrets)
Lotti uses OS‑backed secure storage via `flutter_secure_storage`:
- iOS: Keychain Services
- macOS: Keychain Services
- Android: Android Keystore (keys) with encrypted SharedPreferences
- Windows: Credential Locker (DPAPI)
- Linux: Secret Service (libsecret; via GNOME Keyring/KWallet depending on environment)

Secrets stored in secure storage include AI provider API keys and tokens, and sync credentials (e.g., Matrix access tokens).

### Data at Rest (Databases)
- Current state: SQLite databases (Drift) are stored unencrypted
- Recommended mitigation: rely on OS/device full‑disk encryption and user account protections
- Roadmap: optional database‑level encryption for SQLite (SQLCipher)

### Backups
- Secret backup/restore is handled by the OS keystore. Where available (e.g., iCloud Keychain), secrets may sync via the OS.

### References (platform APIs/libraries)
- Flutter secure storage: https://pub.dev/packages/flutter_secure_storage
- Apple Keychain Services (iOS/macOS)
- Android Keystore System + EncryptedSharedPreferences
- Windows Data Protection API (Credential Locker)
- Linux Secret Service (libsecret)

### Privacy Controls
- No telemetry or analytics
- No vendor/cloud accounts required for core functionality (local-only use)
- Multi-device sync requires a Matrix account (self-hosted or public homeserver) - no vendor lock-in as Matrix is decentralized
- Explicit consent for AI processing
- Data never leaves device without user action

## Testing Strategy

### Unit Tests
- Core business logic
- Data models and serialization
- Service layer functionality
- See repository Codecov badge for current coverage

### Integration Tests
- Database operations
- AI provider communication
- Sync functionality
- Platform-specific features

### Widget Tests
- UI component behavior
- User interaction flows
- State management
- Accessibility compliance

## Build & Deployment

### Code Generation
```bash
make build_runner  # Generate code for serialization, routing, etc.
```

### Platform Builds
- **iOS/macOS**: Xcode, TestFlight distribution
- **Android**: Gradle, APK/AAB generation
- **Windows**: MSIX packaging
- **Linux**: Flatpak, AppImage, tar.gz

### Continuous Integration
- GitHub Actions for all platforms
- Automated testing on PR
- Release builds on tags
- TestFlight deployment for Apple platforms

## Performance Considerations

### Optimization Strategies
1. **Lazy Loading**: Load data on demand
2. **Pagination**: Handle large datasets efficiently
3. **Caching**: In-memory caches for frequently accessed data
4. **Background Processing**: Heavy operations off main thread
5. **Streaming**: Real-time AI responses without blocking

### Resource Management
- Efficient memory usage
- Battery-conscious background tasks
- Network request batching
- Audio file compression

## Future Architecture Plans

### Planned Enhancements
1. **Plugin System**: Extensible architecture for custom features
2. **Local AI Models**: Expanded support for on-device inference
3. **Advanced Analytics**: Local ML for pattern recognition
4. **Federation**: Decentralized sharing with privacy
5. **Voice Interface**: Hands-free interaction

### Scalability Considerations
- SQLite handles single-user data efficiently at any scale
- Incremental sync optimization
- Parallel AI processing
- Multi-device coordination

## Development Guidelines

### Implementation Notes
- State management and dependency injection use Riverpod
- Persistence via Drift over SQLite; schemas live under `lib/database` and feature‑specific `*.drift` files
- Localization with Flutter gen‑l10n; ARB files in `lib/l10n/` and generation via `make l10n`
- Code generation via build_runner; run `make build_runner`

### Code Organization
```
lib/
├── features/       # Feature modules
├── services/       # Core services
├── models/         # Data models
├── widgets/        # Shared UI components
├── utils/          # Utility functions
└── main.dart       # Application entry
```

### Best Practices
1. Follow Flutter style guide
2. Write tests for new features
3. Document complex logic
4. Use dependency injection
5. Handle errors gracefully

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on:
- Code style and standards
- Testing requirements
- Pull request process
- Community guidelines

For development environment setup, see [DEVELOPMENT.md](DEVELOPMENT.md).

## Related Documentation

- [Development Setup](DEVELOPMENT.md)
- [Contributing](../CONTRIBUTING.md)
- [Privacy Policy](../PRIVACY.md)
- [User Manual](MANUAL.md)
- [Background & History](BACKGROUND.md)
