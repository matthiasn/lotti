import 'dart:convert';

import 'package:lotti/features/ai/model/ai_config.dart';

/// Shared helpers for mapping a provider's `/models` catalog response into the
/// app's `KnownModel` shape.
///
/// The dynamic-catalog repositories (Gemini, OpenAI, …) each fetch a provider
/// listing and translate it into installable model rows. The parsing and
/// formatting primitives below are identical across providers, so they live
/// here instead of being copied per repository.
abstract final class ModelCatalogMapping {
  /// A safe-to-log/surface representation of [uri]: host + path only, with any
  /// userinfo (credentials) and query string (which can carry an API key)
  /// stripped.
  static String redactedEndpoint(Uri uri) {
    final host = uri.host.isEmpty ? '<local>' : uri.host;
    return '$host${uri.path}';
  }

  /// Appends [modality] to [modalities] only if it is not already present.
  static void addUniqueModality(List<Modality> modalities, Modality modality) {
    if (!modalities.contains(modality)) modalities.add(modality);
  }

  /// Loosely coerces a JSON value to a bool (accepting `true`, non-zero
  /// numbers, and the string `"true"`).
  static bool truthy(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  /// Loosely coerces a JSON value to an int, returning `null` when it cannot.
  static int? integerValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Humanizes a raw model id into a display name.
  ///
  /// Uses the leaf after the last `/`, splits on separators, upper-cases any
  /// segment in [acronyms] and any number-ish segment, and title-cases the
  /// rest. Falls back to [modelId] verbatim when the result would be empty.
  static String humanizeModelId(
    String modelId, {
    Set<String> acronyms = const {},
  }) {
    final leaf = modelId.split('/').last;
    final words = leaf
        .replaceAll(RegExp('[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((word) => _titleCaseWord(word, acronyms));
    final displayName = words.join(' ');
    return displayName.isEmpty ? modelId : displayName;
  }

  static String _titleCaseWord(String word, Set<String> acronyms) {
    final upper = word.toUpperCase();
    if (acronyms.contains(upper)) return upper;
    if (RegExp(r'^[a-z]?\d+[a-z]?$', caseSensitive: false).hasMatch(word)) {
      return upper;
    }
    return '${word[0].toUpperCase()}${word.substring(1)}';
  }

  /// Extracts a human-readable message from a provider error [body].
  ///
  /// Understands the common `{error: {message}}`, `{error: "…"}` and
  /// `{message}` shapes, and otherwise returns a clipped raw body (never more
  /// than [maxLength] characters). Falls back to a status-only message when the
  /// body is empty.
  static String extractErrorMessage(
    String body,
    int statusCode, {
    required String providerLabel,
    int maxLength = 160,
  }) {
    final fallback = '$providerLabel API error (HTTP $statusCode)';
    if (body.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) return message;
        }
        if (error is String && error.isNotEmpty) return error;
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Fall through to a clipped raw body.
    }
    return body.length > maxLength ? '${body.substring(0, maxLength)}…' : body;
  }
}
