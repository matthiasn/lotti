import 'dart:convert';

/// Parse labelIds from a tool/function call arguments JSON.
/// Accepts either a JSON array or a comma-separated string, trims items,
/// and discards empties.
List<String> parseLabelIdsFromToolArgs(String argumentsJson) {
  try {
    final args = jsonDecode(argumentsJson) as Map<String, dynamic>;
    final idsRaw = args['labelIds'];
    final out = <String>[];
    if (idsRaw is List) {
      out.addAll(
          idsRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty));
    } else if (idsRaw is String) {
      out.addAll(
        idsRaw
            .split(RegExp(r'\s*,\s*'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }
    return out;
  } catch (_) {
    return const <String>[];
  }
}
