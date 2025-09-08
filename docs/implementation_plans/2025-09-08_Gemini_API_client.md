# Gemini Native API Client Implementation Plan

**Date:** 2025-09-08  
**Author:** AI Assistant  
**Status:** Draft  
**Issue:** Gemini 2.5 Flash not performing complex reasoning in AI Chat due to missing thinking configuration

## Executive Summary

This document outlines a plan to implement a native Gemini API client for the Lotti application. The primary goal is to enable proper thinking mode configuration for Gemini 2.5 Flash, which currently fails to perform complex reasoning tasks due to limitations in the OpenAI compatibility layer.

## Problem Statement

### Current Issue
- Gemini 2.5 Flash refuses to perform complex reasoning tasks (e.g., categorizing tasks by topic)
- The model claims it lacks the capability, despite being a reasoning-capable model
- Works correctly with Gemini 2.5 Pro and local models like Qwen3

### Root Cause
- The current implementation uses `openai_dart` package with OpenAI compatibility mode
- OpenAI compatibility doesn't pass Gemini-specific `thinkingConfig` parameters
- Gemini 2.5 Flash defaults to minimal thinking without explicit configuration
- Gemini 2.5 Pro has thinking always enabled, masking the issue

## Proposed Solution

### Architecture Overview

```
┌─────────────────────────────────────────┐
│         ChatRepository                  │
│                                         │
└────────────┬────────────────────────────┘
             │
             ├──── Provider Detection
             │
    ┌────────┴────────┬───────────────────┐
    │                 │                   │
    ▼                 ▼                   ▼
┌───────────┐  ┌──────────────┐  ┌──────────────┐
│ Gemini    │  │ OpenAI       │  │ Ollama       │
│ Inference │  │ Compatible   │  │ Inference    │
│ Repository│  │ Repository   │  │ Repository   │
└───────────┘  └──────────────┘  └──────────────┘
    │
    ▼
┌──────────────────────────────────────────┐
│   Native Gemini API (REST or SDK)        │
│   - Full thinking configuration support  │
│   - Direct tool calling                  │
│   - Streaming responses                  │
└──────────────────────────────────────────┘
```

## Implementation Details

### 1. Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  google_generative_ai: ^0.5.0  # Official Google SDK
```

### 2. Create Gemini Repository

```dart
// lib/features/ai/repository/gemini_inference_repository.dart

class GeminiInferenceRepository {
  Stream<GeminiStreamResponse> generateWithThinking({
    required String prompt,
    required String model,
    required GeminiThinkingConfig thinkingConfig,
    required List<GeminiTool>? tools,
    String? systemMessage,
    double temperature = 0.7,
  });
  
  Stream<GeminiStreamResponse> generateFromMessages({
    required List<GeminiMessage> messages,
    required String model,
    required GeminiThinkingConfig thinkingConfig,
    required List<GeminiTool>? tools,
  });
}
```

### 3. Thinking Configuration Model

```dart
// lib/features/ai/repository/gemini_thinking_config.dart

@freezed
class GeminiThinkingConfig with _$GeminiThinkingConfig {
  const factory GeminiThinkingConfig({
    required int thinkingBudget, // -1 for auto, 0 to disable, 1-24576 for fixed
    @Default(false) bool includeThoughts,
  }) = _GeminiThinkingConfig;
  
  // Presets for common scenarios
  static const auto = GeminiThinkingConfig(thinkingBudget: -1);
  static const disabled = GeminiThinkingConfig(thinkingBudget: 0);
  static const standard = GeminiThinkingConfig(thinkingBudget: 8192);
  static const intensive = GeminiThinkingConfig(thinkingBudget: 16384);
}
```

### 4. Integration with CloudInferenceRepository

```dart
// lib/features/ai/repository/cloud_inference_repository.dart

Stream<CreateChatCompletionStreamResponse> generate(...) {
  // Detect Gemini provider
  if (provider?.inferenceProviderType == InferenceProviderType.gemini) {
    return _geminiRepository.generateWithThinking(
      prompt: prompt,
      model: model,
      thinkingConfig: _getThinkingConfigForModel(model),
      tools: _convertToolsToGemini(tools),
      systemMessage: systemMessage,
      temperature: temperature,
    ).map(_convertGeminiToOpenAiResponse);
  }
  // ... existing code for other providers
}
```

### 5. Model-Specific Default Configuration

```dart
// lib/features/ai/util/gemini_config.dart

GeminiThinkingConfig getDefaultThinkingConfig(String modelId) {
  return switch (modelId) {
    'models/gemini-2.5-flash' => GeminiThinkingConfig.standard,
    'models/gemini-2.5-flash-lite' => GeminiThinkingConfig(thinkingBudget: 4096),
    'models/gemini-2.5-pro' => GeminiThinkingConfig.auto, // Can't be disabled
    'models/gemini-2.0-flash' => GeminiThinkingConfig.disabled, // No thinking support
    _ => GeminiThinkingConfig.auto,
  };
}
```

### 6. Response Stream Handling

```dart
Stream<String> _processGeminiStream(Stream<GeminiStreamChunk> stream) async* {
  final thinkingBuffer = StringBuffer();
  bool inThinking = false;
  
  await for (final chunk in stream) {
    if (chunk.isThinkingContent) {
      inThinking = true;
      thinkingBuffer.write(chunk.text);
    } else {
      if (inThinking) {
        // Emit thinking block
        yield '<thinking>\n${thinkingBuffer.toString()}\n</thinking>\n';
        thinkingBuffer.clear();
        inThinking = false;
      }
      // Emit regular content
      yield chunk.text ?? '';
    }
  }
}
```

### 7. Tool Calling Support

```dart
// Convert existing OpenAI tools to Gemini format
GeminiTool convertToGeminiTool(ChatCompletionTool openAiTool) {
  return GeminiTool.function(
    name: openAiTool.function.name,
    description: openAiTool.function.description ?? '',
    parameters: openAiTool.function.parameters?.toJson() ?? {},
  );
}
```

## Testing Strategy

### Unit Tests
- Verify thinking configuration is correctly passed to API
- Test response conversion between Gemini and OpenAI formats
- Validate tool calling with thinking enabled

### Integration Tests
- Test actual Gemini API calls with different thinking budgets
- Verify complex reasoning tasks work with Flash model
- Compare response quality with different configurations

### Test Scenarios
1. **Task Categorization**: "Summarize my tasks from August by topic"
2. **Pattern Analysis**: "What patterns do you see in my work?"
3. **Complex Queries**: Multi-step reasoning requiring intermediate thoughts
4. **Tool + Thinking**: Verify tool calls work with thinking enabled

## Implementation Options

### Option A: Google SDK (`google_generative_ai`)
**Pros:**
- Official support and documentation
- Built-in error handling and retries
- Type-safe Dart models

**Cons:**
- Additional dependency
- Less control over HTTP layer

### Option B: Direct REST Implementation
**Pros:**
- Full control over implementation
- Minimal dependencies
- Direct access to all API features

**Cons:**
- More code to maintain
- Manual error handling needed

**Recommendation:** Start with Option A (SDK) for faster implementation.

## Sample API Request

```json
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent

{
  "contents": [{
    "role": "user",
    "parts": [{"text": "Categorize my tasks by topic"}]
  }],
  "generationConfig": {
    "temperature": 0.7,
    "thinkingConfig": {
      "thinkingBudget": 8192,
      "includeThoughts": true
    }
  },
  "tools": [{
    "functionDeclarations": [{
      "name": "get_task_summaries",
      "description": "Retrieves task summaries for a date range",
      "parameters": {
        "type": "object",
        "properties": {
          "start_date": {"type": "string"},
          "end_date": {"type": "string"}
        }
      }
    }]
  }]
}
```

## References

- [Gemini Thinking Documentation](https://ai.google.dev/gemini-api/docs/thinking)
- [Google Generative AI SDK](https://pub.dev/packages/google_generative_ai)
- [Gemini API Reference](https://ai.google.dev/api/generate-content)
- [Firebase AI Logic Documentation](https://firebase.google.com/docs/ai-logic)