# AI Configuration System

This module provides a persistent storage system for AI-related configurations such as API keys, prompt templates, and other settings.

## Structure

The system consists of:

1. **Model** (`ai_config.dart`): Defines the configuration data model using Freezed for union types
2. **Database** (`ai_config_db.drift`, `ai_config_db.dart`): Drift database for persistent storage
3. **Repository** (`ai_config_repository.dart`): Interface for manipulating configurations

## Features

- Store and manage API keys for different AI providers
- Extensible design for adding new configuration types (prompts, settings, etc.)
- Serialization/deserialization of configuration objects
- Reactive streams for configuration changes

## Usage

```dart
// Initialize the database
final db = AiConfigDb();

// Create the repository
final repository = AiConfigRepository(db);

// Create a new API key configuration
final config = AiConfig.apiKey(
  id: 'openai-key',
  baseUrl: 'https://api.openai.com/v1',
  apiKey: 'sk-1234567890abcdef',
  name: 'OpenAI API Key',
  createdAt: DateTime.now(),
  supportsThinkingOutput: true,
);

// Save the configuration
await repository.saveConfig(config);

// Get a configuration by ID
final savedConfig = await repository.getConfigById('openai-key');

// Watch for configurations of a specific type
repository.watchConfigsByType('_AiConfigApiKey').listen((configs) {
  // Handle configuration changes
});

// Delete a configuration
await repository.deleteConfig('openai-key');
```

## Testing

The system includes both mock tests and integration tests using an in-memory database. 