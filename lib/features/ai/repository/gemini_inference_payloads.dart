part of 'gemini_inference_repository.dart';

/// Internal helper result for consolidated (non-streaming) Gemini payloads.
class _ProcessedPayload {
  _ProcessedPayload({
    required this.thinking,
    required this.visible,
    required this.toolChunks,
    required this.signatures,
    this.usage,
  });

  final String thinking;
  final String visible;
  final List<ChatCompletionStreamMessageToolCallChunk> toolChunks;
  final CompletionUsage? usage;

  /// Thought signatures captured from function calls, keyed by tool call ID.
  final Map<String, String> signatures;
}

/// Extracts a thought signature from a Gemini response part.
///
/// Gemini 3 models include `thoughtSignature` as a **sibling** to `functionCall`
/// at the part level (not nested inside `functionCall`). For example:
/// ```json
/// {
///   "functionCall": { "name": "...", "args": {...} },
///   "thoughtSignature": "<encrypted-signature>"
/// }
/// ```
///
/// For parallel function calls, only the first call receives a signature.
/// These signatures must be included in subsequent multi-turn requests to
/// maintain reasoning context; without them, Gemini 3 returns 400 errors.
///
/// Returns null if no signature is present (normal for Gemini 2.x or non-thinking mode).
String? extractThoughtSignature(Map<String, dynamic> part) {
  return part['thoughtSignature']?.toString();
}

// ---------------------------------------------------------------------------
// Image generation data structures
// ---------------------------------------------------------------------------

/// Represents a generated image from the Gemini image generation API.
///
/// Contains the raw image bytes and MIME type (typically 'image/png').
/// This is used as the return type for `generateImage` (see
/// [GeminiImageGeneration]).
class GeneratedImage {
  const GeneratedImage({
    required this.bytes,
    required this.mimeType,
  });

  /// The raw image data bytes.
  final List<int> bytes;

  /// The MIME type of the image (e.g., 'image/png', 'image/jpeg').
  final String mimeType;

  /// Returns the file extension for this image's MIME type.
  String get extension {
    switch (mimeType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/png':
      default:
        return 'png';
    }
  }
}
