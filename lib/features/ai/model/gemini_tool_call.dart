import 'package:lotti/features/ai/repository/gemini_inference_repository.dart'
    show GeminiInferenceRepository;

/// Information about a Gemini tool call including optional thought signature.
///
/// Gemini 3 models include `thoughtSignature` in function calls for multi-turn
/// conversations. This signature must be included in subsequent requests to
/// maintain reasoning context.
class GeminiToolCall {
  const GeminiToolCall({
    required this.name,
    required this.arguments,
    required this.id,
    this.thoughtSignature,
  });

  /// Function name being called
  final String name;

  /// JSON-encoded function arguments
  final String arguments;

  /// Tool call ID (e.g., "tool_0")
  final String id;

  /// Optional thought signature from Gemini 3 models.
  /// Must be included in subsequent function call requests.
  final String? thoughtSignature;

  @override
  String toString() =>
      'GeminiToolCall(name: $name, id: $id, hasSignature: ${thoughtSignature != null})';
}

/// Collector for capturing thought signatures during Gemini streaming.
///
/// Pass an instance to [GeminiInferenceRepository.generateText] to capture
/// signatures as they appear in the response stream. After streaming completes,
/// access [signatures] to get all captured signatures keyed by tool call ID.
class ThoughtSignatureCollector {
  final Map<String, String> _signatures = {};

  /// Add a signature for a tool call.
  void addSignature(String toolCallId, String signature) {
    _signatures[toolCallId] = signature;
  }

  /// Get all captured signatures, keyed by tool call ID.
  Map<String, String> get signatures => Map.unmodifiable(_signatures);

  /// Get signature for a specific tool call ID.
  String? getSignature(String toolCallId) => _signatures[toolCallId];

  /// Check if any signatures were captured.
  bool get hasSignatures => _signatures.isNotEmpty;

  /// Clear all captured signatures.
  void clear() => _signatures.clear();
}
