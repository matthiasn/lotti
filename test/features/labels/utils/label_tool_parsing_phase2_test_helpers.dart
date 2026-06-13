import 'dart:convert';

import 'package:glados/glados.dart'
    show Any, AnyUtils, CombinableAny, Generator, IntAnys, ListAnys;

/// The four confidence strings the parser treats as canonical, mapped to the
/// rank the parser assigns them. This mirrors the private `_confidenceToRank` /
/// `_normalizeConfidence` contract so we can probe it through the public parser.
const hCanonicalConfidenceRanks = <String, int>{
  'very_high': 3,
  'high': 2,
  'medium': 1,
  'low': 0,
};

extension AnyConfidenceString on Any {
  /// Generates a confidence value: either one of the four canonical strings or
  /// an arbitrary "junk" string (which must normalize to 'medium'/rank 1).
  Generator<String> get confidenceProbe => choose([
    ...hCanonicalConfidenceRanks.keys,
    'unexpected',
    'VERY_HIGH',
    'High',
    '',
    'highish',
    'low ',
    '1',
    'none',
  ]);
}

enum GeneratedLabelCandidateShape { map, string, number, nullValue }

enum GeneratedLabelIdShape {
  validString,
  paddedString,
  emptyString,
  whitespaceString,
  numeric,
  nullValue,
  missing,
}

enum GeneratedConfidenceShape {
  veryHigh,
  high,
  medium,
  low,
  unknown,
  numeric,
  nullValue,
  missing,
}

enum GeneratedLegacyPayloadShape { list, string }

enum GeneratedLegacyIdShape {
  valid,
  padded,
  empty,
  number,
  nullValue,
}

class GeneratedLabelCandidate {
  const GeneratedLabelCandidate({
    required this.shape,
    required this.idShape,
    required this.confidenceShape,
    required this.value,
  });

  final GeneratedLabelCandidateShape shape;
  final GeneratedLabelIdShape idShape;
  final GeneratedConfidenceShape confidenceShape;
  final int value;

  dynamic toRaw() {
    switch (shape) {
      case GeneratedLabelCandidateShape.map:
        final raw = <String, dynamic>{};
        switch (idShape) {
          case GeneratedLabelIdShape.validString:
            raw['id'] = normalizedId;
          case GeneratedLabelIdShape.paddedString:
            raw['id'] = '  $normalizedId  ';
          case GeneratedLabelIdShape.emptyString:
            raw['id'] = '';
          case GeneratedLabelIdShape.whitespaceString:
            raw['id'] = ' \n\t ';
          case GeneratedLabelIdShape.numeric:
            raw['id'] = value;
          case GeneratedLabelIdShape.nullValue:
            raw['id'] = null;
          case GeneratedLabelIdShape.missing:
            break;
        }

        switch (confidenceShape) {
          case GeneratedConfidenceShape.veryHigh:
            raw['confidence'] = 'very_high';
          case GeneratedConfidenceShape.high:
            raw['confidence'] = 'high';
          case GeneratedConfidenceShape.medium:
            raw['confidence'] = 'medium';
          case GeneratedConfidenceShape.low:
            raw['confidence'] = 'low';
          case GeneratedConfidenceShape.unknown:
            raw['confidence'] = 'unexpected';
          case GeneratedConfidenceShape.numeric:
            raw['confidence'] = value;
          case GeneratedConfidenceShape.nullValue:
            raw['confidence'] = null;
          case GeneratedConfidenceShape.missing:
            break;
        }
        return raw;
      case GeneratedLabelCandidateShape.string:
        return normalizedId;
      case GeneratedLabelCandidateShape.number:
        return value;
      case GeneratedLabelCandidateShape.nullValue:
        return null;
    }
  }

  String get normalizedId => idShape == GeneratedLabelIdShape.numeric
      ? value.toString()
      : 'label_$value';

  String? get parsedId {
    if (shape != GeneratedLabelCandidateShape.map) return null;
    return switch (idShape) {
      GeneratedLabelIdShape.validString => normalizedId,
      GeneratedLabelIdShape.paddedString => normalizedId,
      GeneratedLabelIdShape.emptyString => null,
      GeneratedLabelIdShape.whitespaceString => null,
      GeneratedLabelIdShape.numeric => value.toString(),
      GeneratedLabelIdShape.nullValue => null,
      GeneratedLabelIdShape.missing => null,
    };
  }

  String get normalizedConfidence {
    return switch (confidenceShape) {
      GeneratedConfidenceShape.veryHigh => 'very_high',
      GeneratedConfidenceShape.high => 'high',
      GeneratedConfidenceShape.medium => 'medium',
      GeneratedConfidenceShape.low => 'low',
      GeneratedConfidenceShape.unknown => 'medium',
      GeneratedConfidenceShape.numeric => 'medium',
      GeneratedConfidenceShape.nullValue => 'medium',
      GeneratedConfidenceShape.missing => 'medium',
    };
  }

  int get rank {
    return switch (normalizedConfidence) {
      'very_high' => 3,
      'high' => 2,
      'medium' => 1,
      'low' => 0,
      _ => 1,
    };
  }

  @override
  String toString() {
    return 'GeneratedLabelCandidate('
        'shape: $shape, '
        'idShape: $idShape, '
        'confidenceShape: $confidenceShape, '
        'value: $value)';
  }
}

class GeneratedLegacyLabelCandidate {
  const GeneratedLegacyLabelCandidate({
    required this.shape,
    required this.value,
  });

  final GeneratedLegacyIdShape shape;
  final int value;

  String get id => 'legacy_$value';

  Object? get listRaw => switch (shape) {
    GeneratedLegacyIdShape.valid => id,
    GeneratedLegacyIdShape.padded => '  $id  ',
    GeneratedLegacyIdShape.empty => '   ',
    GeneratedLegacyIdShape.number => value,
    GeneratedLegacyIdShape.nullValue => null,
  };

  String get stringRaw => switch (shape) {
    GeneratedLegacyIdShape.valid => id,
    GeneratedLegacyIdShape.padded => '  $id  ',
    GeneratedLegacyIdShape.empty => '   ',
    GeneratedLegacyIdShape.number => value.toString(),
    GeneratedLegacyIdShape.nullValue => '',
  };
}

class GeneratedLegacyLabelPayload {
  const GeneratedLegacyLabelPayload({
    required this.shape,
    required this.items,
  });

  final GeneratedLegacyPayloadShape shape;
  final List<GeneratedLegacyLabelCandidate> items;

  String get json {
    final labelIds = switch (shape) {
      GeneratedLegacyPayloadShape.list =>
        items.map((item) => item.listRaw).toList(),
      GeneratedLegacyPayloadShape.string =>
        items.map((item) => item.stringRaw).join(', '),
    };
    return jsonEncode({'labelIds': labelIds});
  }

  List<String> get allIds {
    return switch (shape) {
      GeneratedLegacyPayloadShape.list =>
        items
            .map((item) => item.listRaw.toString().trim())
            .where((id) => id.isNotEmpty)
            .toList(),
      GeneratedLegacyPayloadShape.string =>
        items
            .map((item) => item.stringRaw)
            .join(', ')
            .split(RegExp(r'\s*,\s*'))
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toList(),
    };
  }

  @override
  String toString() {
    return 'GeneratedLegacyLabelPayload('
        'shape: $shape, '
        'itemCount: ${items.length}, '
        'allIds: $allIds)';
  }
}

class ExpectedLabelParseResult {
  const ExpectedLabelParseResult({
    required this.selectedIds,
    required this.droppedLow,
    required this.confidenceBreakdown,
  });

  final List<String> selectedIds;
  final int droppedLow;
  final Map<String, int> confidenceBreakdown;
}

extension AnyLabelToolParsingScenarios on Any {
  Generator<GeneratedLabelCandidateShape> get labelCandidateShape =>
      choose(GeneratedLabelCandidateShape.values);

  Generator<GeneratedLabelIdShape> get labelIdShape =>
      choose(GeneratedLabelIdShape.values);

  Generator<GeneratedConfidenceShape> get labelConfidenceShape =>
      choose(GeneratedConfidenceShape.values);

  Generator<GeneratedLegacyPayloadShape> get legacyPayloadShape =>
      choose(GeneratedLegacyPayloadShape.values);

  Generator<GeneratedLegacyIdShape> get legacyIdShape =>
      choose(GeneratedLegacyIdShape.values);

  Generator<GeneratedLabelCandidate> get labelCandidate => combine4(
    labelCandidateShape,
    labelIdShape,
    labelConfidenceShape,
    intInRange(0, 1000),
    (
      GeneratedLabelCandidateShape shape,
      GeneratedLabelIdShape idShape,
      GeneratedConfidenceShape confidenceShape,
      int value,
    ) => GeneratedLabelCandidate(
      shape: shape,
      idShape: idShape,
      confidenceShape: confidenceShape,
      value: value,
    ),
  );

  Generator<List<GeneratedLabelCandidate>> get labelCandidates =>
      listWithLengthInRange(0, 14, labelCandidate);

  Generator<GeneratedLegacyLabelCandidate> get legacyLabelCandidate => combine2(
    legacyIdShape,
    intInRange(0, 1000),
    (
      GeneratedLegacyIdShape shape,
      int value,
    ) => GeneratedLegacyLabelCandidate(
      shape: shape,
      value: value,
    ),
  );

  Generator<GeneratedLegacyLabelPayload> get legacyLabelPayload => combine2(
    legacyPayloadShape,
    listWithLengthInRange(0, 10, legacyLabelCandidate),
    (
      GeneratedLegacyPayloadShape shape,
      List<GeneratedLegacyLabelCandidate> items,
    ) => GeneratedLegacyLabelPayload(
      shape: shape,
      items: items,
    ),
  );
}

ExpectedLabelParseResult hModelStructuredLabels(
  List<GeneratedLabelCandidate> candidates,
) {
  final ranked = <({String id, int rank, int index})>[];
  final confidenceBreakdown = {
    'very_high': 0,
    'high': 0,
    'medium': 0,
    'low': 0,
  };

  for (final (index, candidate) in candidates.indexed) {
    final id = candidate.parsedId;
    if (id == null || id.isEmpty) continue;

    final confidence = candidate.normalizedConfidence;
    confidenceBreakdown[confidence] = confidenceBreakdown[confidence]! + 1;
    if (candidate.rank > 0) {
      ranked.add((id: id, rank: candidate.rank, index: index));
    }
  }

  ranked.sort((a, b) {
    final byRank = b.rank.compareTo(a.rank);
    return byRank != 0 ? byRank : a.index.compareTo(b.index);
  });

  return ExpectedLabelParseResult(
    selectedIds: ranked.take(3).map((candidate) => candidate.id).toList(),
    droppedLow: confidenceBreakdown['low']!,
    confidenceBreakdown: confidenceBreakdown,
  );
}
