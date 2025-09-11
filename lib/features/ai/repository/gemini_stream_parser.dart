import 'dart:convert';

import 'package:lotti/features/ai/repository/gemini_utils.dart';

/// Incremental parser for mixed-format Gemini streaming payloads.
///
/// Supports:
/// - SSE lines with optional inline JSON payloads (e.g. `data: { ... }`)
/// - NDJSON (newline-delimited JSON objects)
/// - JSON array framing (leading '[', commas, and closing ']')
/// - Objects spanning multiple chunks
/// - Robust string scanning that ignores braces inside string literals
///
/// Usage pattern:
///
/// final parser = GeminiStreamParser();
/// final objs = parser.addChunk(rawChunk);
/// for (final obj in objs) { ... }
///
/// The parser maintains internal buffer state between calls.
class GeminiStreamParser {
  GeminiStreamParser({this.verbose = false, this.maxBufferSize = 64 * 1024});

  final bool verbose;

  /// Maximum number of characters the internal buffer may hold.
  /// Defaults to 64KB to prevent unbounded growth when upstream framing is noisy.
  final int maxBufferSize;
  final StringBuffer _buffer = StringBuffer();

  /// Add a raw text [chunk], returning all complete decoded JSON objects
  /// contained within. Any incomplete tail remains buffered internally until
  /// more data arrives.
  ///
  /// The internal buffer is capped at [maxBufferSize]; when incoming data
  /// would exceed the cap, the oldest content is trimmed from the left before
  /// appending. Trimming prefers to align to the next '{' if present to
  /// increase the odds of beginning at an object boundary.
  List<Map<String, dynamic>> addChunk(String chunk) {
    // Enforce a cap by trimming oldest data before appending the new chunk.
    // This prevents unbounded growth under pathological streams.
    if (_buffer.length + chunk.length > maxBufferSize) {
      final needed = (_buffer.length + chunk.length) - maxBufferSize;
      if (needed > 0) {
        final existing = _buffer.toString();
        var trimmed =
            needed >= existing.length ? '' : existing.substring(needed);
        // Prefer aligning to the next JSON object start if present.
        final brace = trimmed.indexOf('{');
        if (brace > 0) {
          trimmed = trimmed.substring(brace);
        }
        _buffer
          ..clear()
          ..write(trimmed);
      }
    }
    _buffer.write(chunk);
    var text = _buffer.toString();
    // Normalize framing before scanning
    text = GeminiUtils.stripLeadingFraming(text);

    final results = <Map<String, dynamic>>[];
    var progressed = true;
    while (progressed) {
      progressed = false;
      final start = text.indexOf('{');
      if (start == -1) break;
      var depth = 0;
      var inStr = false;
      var esc = false;
      var end = -1;
      for (var i = start; i < text.length; i++) {
        final ch = text[i];
        if (inStr) {
          if (esc) {
            esc = false;
          } else if (ch.codeUnitAt(0) == 92) {
            // backslash
            esc = true;
          } else if (ch == '"') {
            inStr = false;
          }
          continue;
        }
        if (ch == '"') {
          inStr = true;
          continue;
        }
        if (ch == '{') depth++;
        if (ch == '}') {
          depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
      }
      if (end == -1) break; // need more data

      final objStr = text.substring(start, end + 1);
      try {
        final obj = jsonDecode(objStr) as Map<String, dynamic>;
        results.add(obj);
      } catch (e) {
        // On malformed object, skip it and continue scanning after it.
        // This mirrors the adapter's resilience to vendor quirks.
        // Optionally expose a hook for diagnostics in the future.
      }

      // consume processed portion and re-strip for any next object
      text = text.substring(end + 1);
      text = GeminiUtils.stripLeadingFraming(text);
      progressed = true;
    }

    // Preserve remainder in buffer
    _buffer
      ..clear()
      ..write(text);

    return results;
  }

  /// Returns the current buffered, unparsed remainder (useful for testing).
  String remainder() => _buffer.toString();
}
