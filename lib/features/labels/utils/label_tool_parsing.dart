import 'dart:convert';

/// Result of parsing an assign_task_labels function call.
class LabelCallParseResult {
  const LabelCallParseResult({
    required this.selectedIds,
    required this.droppedLow,
    required this.legacyUsed,
    required this.confidenceBreakdown,
    this.totalCandidates = 0,
  });

  final List<String> selectedIds;
  final int droppedLow;
  final bool legacyUsed;
  final Map<String, int> confidenceBreakdown; // keys: very_high/high/medium/low
  final int totalCandidates;
}

int _confidenceToRank(String? confidence) {
  switch (confidence) {
    case 'very_high':
      return 3;
    case 'high':
      return 2;
    case 'medium':
    case null:
      return 1;
    case 'low':
      return 0;
    default:
      // Unknown values treated as medium by default.
      return 1;
  }
}

String _normalizeConfidence(String? confidence) {
  switch (confidence) {
    case 'very_high':
    case 'high':
    case 'medium':
    case 'low':
      return confidence!;
    default:
      return 'medium';
  }
}

/// Parse function call arguments for label assignment with confidence handling.
///
/// Accepts either the new Phase 2 shape:
///   {"labels": [{"id":"a","confidence":"high"}, ...]}
/// or the legacy (deprecated) shape:
///   {"labelIds": ["a","b", ...]} or {"labelIds": "a, b"}
///
/// Returns up to top 3 IDs by confidence (very_high > high > medium), dropping
/// low-confidence entries, preserving stable order among equals.
LabelCallParseResult parseLabelCallArgs(String argumentsJson) {
  try {
    final args = jsonDecode(argumentsJson) as Map<String, dynamic>;

    // Prefer new structured labels when present.
    final labelsRaw = args['labels'];
    if (labelsRaw is List) {
      final items = <({String id, int rank, int index, String confidence})>[];
      var countVH = 0;
      var countH = 0;
      var countM = 0;
      var countL = 0;

      for (var i = 0; i < labelsRaw.length; i++) {
        final e = labelsRaw[i];
        if (e is Map<String, dynamic>) {
          final id = e['id']?.toString().trim();
          if (id == null || id.isEmpty) continue;
          final confNorm = _normalizeConfidence(e['confidence']?.toString());
          switch (confNorm) {
            case 'very_high':
              countVH++;
            case 'high':
              countH++;
            case 'medium':
              countM++;
            case 'low':
              countL++;
          }
          final rank = _confidenceToRank(confNorm);
          if (rank > 0) {
            items.add((id: id, rank: rank, index: i, confidence: confNorm));
          }
        }
      }

      // Stable ordering among equals by sorting on (-rank, index).
      items.sort((a, b) {
        final byRank = b.rank.compareTo(a.rank);
        return byRank != 0 ? byRank : a.index.compareTo(b.index);
      });

      final selected = items.take(3).map((e) => e.id).toList(growable: false);
      final droppedLow = countL;
      return LabelCallParseResult(
        selectedIds: selected,
        droppedLow: droppedLow,
        legacyUsed: false,
        confidenceBreakdown: {
          'very_high': countVH,
          'high': countH,
          'medium': countM,
          'low': countL,
        },
        totalCandidates: labelsRaw.length,
      );
    }

    // Legacy fallback: labelIds array or comma-separated string. Treat all as medium.
    final idsRaw = args['labelIds'];
    final allIds = <String>[];
    if (idsRaw is List) {
      allIds.addAll(
        idsRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
      );
    } else if (idsRaw is String) {
      allIds.addAll(
        idsRaw
            .split(RegExp(r'\s*,\s*'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    final selected = allIds.take(3).toList(growable: false);
    return LabelCallParseResult(
      selectedIds: selected,
      droppedLow: 0,
      legacyUsed: idsRaw != null,
      confidenceBreakdown: {
        'very_high': 0,
        'high': 0,
        'medium': allIds.length,
        'low': 0,
      },
      totalCandidates: allIds.length,
    );
  } catch (_) {
    return const LabelCallParseResult(
      selectedIds: <String>[],
      droppedLow: 0,
      legacyUsed: false,
      confidenceBreakdown: {
        'very_high': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
      },
    );
  }
}

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
        idsRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
      );
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
