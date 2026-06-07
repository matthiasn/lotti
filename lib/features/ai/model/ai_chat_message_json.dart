import 'package:lotti/features/ai/model/ai_chat_message.dart';

// =============================================================================
// Encoders — internal types → OpenAI-compatible wire JSON
// =============================================================================

extension AiChatMessageJson on AiChatMessage {
  Map<String, dynamic> toJson() {
    return switch (this) {
      final AiSystemMessage m => {
        'role': 'system',
        'content': m.content,
      },
      final AiUserMessage m => {
        'role': 'user',
        'content': m.content.toJson(),
      },
      final AiAssistantMessage m => {
        'role': 'assistant',
        if (m.content != null) 'content': m.content,
        if (m.toolCalls != null && m.toolCalls!.isNotEmpty)
          'tool_calls': m.toolCalls!.map((tc) => tc.toJson()).toList(),
      },
      final AiToolResultMessage m => {
        'role': 'tool',
        'tool_call_id': m.toolCallId,
        'content': m.content,
      },
    };
  }
}

extension AiUserContentJson on AiUserContent {
  Object toJson() {
    return switch (this) {
      final AiUserTextContent c => c.text,
      final AiUserPartsContent c => c.parts.map((p) => p.toJson()).toList(),
    };
  }
}

extension AiContentPartJson on AiContentPart {
  Map<String, dynamic> toJson() {
    return switch (this) {
      final AiTextPart p => {'type': 'text', 'text': p.text},
      final AiImagePart p => {
        'type': 'image_url',
        'image_url': {'url': p.url},
      },
      final AiAudioPart p => {
        'type': 'input_audio',
        'input_audio': {'data': p.data, 'format': p.format.wire},
      },
    };
  }
}

extension AiToolCallJson on AiToolCall {
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': 'function',
    'function': {'name': name, 'arguments': arguments},
  };
}

extension AiToolJson on AiTool {
  Map<String, dynamic> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

extension AiToolChoiceJson on AiToolChoice {
  Object toJson() {
    return switch (this) {
      AiToolChoiceAuto() => 'auto',
      AiToolChoiceNone() => 'none',
      AiToolChoiceRequired() => 'required',
      final AiToolChoiceFunction c => {
        'type': 'function',
        'function': {'name': c.name},
      },
    };
  }
}

// =============================================================================
// Decoders — OpenAI-compatible wire JSON → internal types
// =============================================================================

/// Parse one streaming chat-completion event.
///
/// Returns null for events that carry no meaningful payload (no choices and
/// no usage) — e.g. Anthropic-via-OpenRouter ping messages, which the previous
/// openai_dart implementation had to filter out via error catching.
///
/// Terminal usage-only events (OpenAI emits one when
/// `stream_options.include_usage=true`) are preserved with an empty choices
/// list so callers can extract token accounting from the final chunk.
AiStreamChunk? aiStreamChunkFromJson(Map<String, dynamic> json) {
  final choices = <AiStreamChoice>[];
  final choicesJson = json['choices'] as List<dynamic>?;
  if (choicesJson != null) {
    for (final c in choicesJson) {
      if (c is! Map<String, dynamic>) continue;
      final choice = _streamChoiceFromJson(c);
      if (choice != null) choices.add(choice);
    }
  }

  AiUsage? usage;
  final usageJson = json['usage'] as Map<String, dynamic>?;
  if (usageJson != null) {
    final completionDetails =
        usageJson['completion_tokens_details'] as Map<String, dynamic>?;
    final promptDetails =
        usageJson['prompt_tokens_details'] as Map<String, dynamic>?;
    usage = AiUsage(
      promptTokens: usageJson['prompt_tokens'] as int?,
      completionTokens: usageJson['completion_tokens'] as int?,
      totalTokens: usageJson['total_tokens'] as int?,
      reasoningTokens: completionDetails?['reasoning_tokens'] as int?,
      cachedInputTokens: promptDetails?['cached_tokens'] as int?,
    );
  }

  if (choices.isEmpty && usage == null) return null;

  return AiStreamChunk(
    id: json['id'] as String? ?? '',
    choices: choices,
    model: json['model'] as String?,
    created: json['created'] as int?,
    usage: usage,
  );
}

AiStreamChoice? _streamChoiceFromJson(Map<String, dynamic> json) {
  final deltaJson = json['delta'] as Map<String, dynamic>?;
  if (deltaJson == null) return null;

  final content = _extractDeltaContent(deltaJson['content']);
  final toolCalls = _parseToolCallChunks(deltaJson['tool_calls']);
  final roleStr = deltaJson['role'] as String?;
  final role = roleStr != null ? AiMessageRole.tryParse(roleStr) : null;

  return AiStreamChoice(
    index: json['index'] as int? ?? 0,
    delta: AiStreamDelta(role: role, content: content, toolCalls: toolCalls),
    finishReason: json['finish_reason'] as String?,
  );
}

/// Some providers (Mistral) emit `content` as an array of parts rather than
/// a string. Flatten to a string for our delta representation.
String? _extractDeltaContent(dynamic content) {
  if (content == null) return null;
  if (content is String) return content;
  if (content is List) {
    final parts = <String>[];
    for (final p in content) {
      if (p is Map<String, dynamic>) {
        final type = p['type'] as String?;
        if (type == 'text') {
          final text = p['text'] as String?;
          if (text != null) parts.add(text);
        }
      } else if (p is String) {
        parts.add(p);
      }
    }
    return parts.isEmpty ? null : parts.join();
  }
  return content.toString();
}

List<AiToolCallChunk>? _parseToolCallChunks(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  final result = <AiToolCallChunk>[];
  for (final tc in raw) {
    if (tc is! Map<String, dynamic>) continue;
    final function = tc['function'] as Map<String, dynamic>?;
    result.add(
      AiToolCallChunk(
        index: tc['index'] as int?,
        id: tc['id'] as String?,
        name: function?['name'] as String?,
        arguments: function?['arguments'] as String?,
      ),
    );
  }
  return result.isEmpty ? null : result;
}
