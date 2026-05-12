/// Collector for capturing thought signatures during Gemini streaming.
///
/// Pass an instance to `GeminiInferenceRepository.generateText` to capture
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

  /// Check if any signatures were captured.
  bool get hasSignatures => _signatures.isNotEmpty;
}
