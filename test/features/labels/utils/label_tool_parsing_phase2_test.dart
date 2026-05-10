import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show
        Any,
        AnyUtils,
        CombinableAny,
        ExploreConfig,
        Generator,
        Glados,
        IntAnys,
        ListAnys,
        any;
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';

enum _GeneratedLabelCandidateShape { map, string, number, nullValue }

enum _GeneratedLabelIdShape {
  validString,
  paddedString,
  emptyString,
  whitespaceString,
  numeric,
  nullValue,
  missing,
}

enum _GeneratedConfidenceShape {
  veryHigh,
  high,
  medium,
  low,
  unknown,
  numeric,
  nullValue,
  missing,
}

enum _GeneratedLegacyPayloadShape { list, string }

enum _GeneratedLegacyIdShape {
  valid,
  padded,
  empty,
  number,
  nullValue,
}

class _GeneratedLabelCandidate {
  const _GeneratedLabelCandidate({
    required this.shape,
    required this.idShape,
    required this.confidenceShape,
    required this.value,
  });

  final _GeneratedLabelCandidateShape shape;
  final _GeneratedLabelIdShape idShape;
  final _GeneratedConfidenceShape confidenceShape;
  final int value;

  dynamic toRaw() {
    switch (shape) {
      case _GeneratedLabelCandidateShape.map:
        final raw = <String, dynamic>{};
        switch (idShape) {
          case _GeneratedLabelIdShape.validString:
            raw['id'] = normalizedId;
          case _GeneratedLabelIdShape.paddedString:
            raw['id'] = '  $normalizedId  ';
          case _GeneratedLabelIdShape.emptyString:
            raw['id'] = '';
          case _GeneratedLabelIdShape.whitespaceString:
            raw['id'] = ' \n\t ';
          case _GeneratedLabelIdShape.numeric:
            raw['id'] = value;
          case _GeneratedLabelIdShape.nullValue:
            raw['id'] = null;
          case _GeneratedLabelIdShape.missing:
            break;
        }

        switch (confidenceShape) {
          case _GeneratedConfidenceShape.veryHigh:
            raw['confidence'] = 'very_high';
          case _GeneratedConfidenceShape.high:
            raw['confidence'] = 'high';
          case _GeneratedConfidenceShape.medium:
            raw['confidence'] = 'medium';
          case _GeneratedConfidenceShape.low:
            raw['confidence'] = 'low';
          case _GeneratedConfidenceShape.unknown:
            raw['confidence'] = 'unexpected';
          case _GeneratedConfidenceShape.numeric:
            raw['confidence'] = value;
          case _GeneratedConfidenceShape.nullValue:
            raw['confidence'] = null;
          case _GeneratedConfidenceShape.missing:
            break;
        }
        return raw;
      case _GeneratedLabelCandidateShape.string:
        return normalizedId;
      case _GeneratedLabelCandidateShape.number:
        return value;
      case _GeneratedLabelCandidateShape.nullValue:
        return null;
    }
  }

  String get normalizedId => idShape == _GeneratedLabelIdShape.numeric
      ? value.toString()
      : 'label_$value';

  String? get parsedId {
    if (shape != _GeneratedLabelCandidateShape.map) return null;
    return switch (idShape) {
      _GeneratedLabelIdShape.validString => normalizedId,
      _GeneratedLabelIdShape.paddedString => normalizedId,
      _GeneratedLabelIdShape.emptyString => null,
      _GeneratedLabelIdShape.whitespaceString => null,
      _GeneratedLabelIdShape.numeric => value.toString(),
      _GeneratedLabelIdShape.nullValue => null,
      _GeneratedLabelIdShape.missing => null,
    };
  }

  String get normalizedConfidence {
    return switch (confidenceShape) {
      _GeneratedConfidenceShape.veryHigh => 'very_high',
      _GeneratedConfidenceShape.high => 'high',
      _GeneratedConfidenceShape.medium => 'medium',
      _GeneratedConfidenceShape.low => 'low',
      _GeneratedConfidenceShape.unknown => 'medium',
      _GeneratedConfidenceShape.numeric => 'medium',
      _GeneratedConfidenceShape.nullValue => 'medium',
      _GeneratedConfidenceShape.missing => 'medium',
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
    return '_GeneratedLabelCandidate('
        'shape: $shape, '
        'idShape: $idShape, '
        'confidenceShape: $confidenceShape, '
        'value: $value)';
  }
}

class _GeneratedLegacyLabelCandidate {
  const _GeneratedLegacyLabelCandidate({
    required this.shape,
    required this.value,
  });

  final _GeneratedLegacyIdShape shape;
  final int value;

  String get id => 'legacy_$value';

  Object? get listRaw => switch (shape) {
    _GeneratedLegacyIdShape.valid => id,
    _GeneratedLegacyIdShape.padded => '  $id  ',
    _GeneratedLegacyIdShape.empty => '   ',
    _GeneratedLegacyIdShape.number => value,
    _GeneratedLegacyIdShape.nullValue => null,
  };

  String get stringRaw => switch (shape) {
    _GeneratedLegacyIdShape.valid => id,
    _GeneratedLegacyIdShape.padded => '  $id  ',
    _GeneratedLegacyIdShape.empty => '   ',
    _GeneratedLegacyIdShape.number => value.toString(),
    _GeneratedLegacyIdShape.nullValue => '',
  };
}

class _GeneratedLegacyLabelPayload {
  const _GeneratedLegacyLabelPayload({
    required this.shape,
    required this.items,
  });

  final _GeneratedLegacyPayloadShape shape;
  final List<_GeneratedLegacyLabelCandidate> items;

  String get json {
    final labelIds = switch (shape) {
      _GeneratedLegacyPayloadShape.list =>
        items.map((item) => item.listRaw).toList(),
      _GeneratedLegacyPayloadShape.string =>
        items.map((item) => item.stringRaw).join(', '),
    };
    return jsonEncode({'labelIds': labelIds});
  }

  List<String> get allIds {
    return switch (shape) {
      _GeneratedLegacyPayloadShape.list =>
        items
            .map((item) => item.listRaw.toString().trim())
            .where((id) => id.isNotEmpty)
            .toList(),
      _GeneratedLegacyPayloadShape.string =>
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
    return '_GeneratedLegacyLabelPayload('
        'shape: $shape, '
        'itemCount: ${items.length}, '
        'allIds: $allIds)';
  }
}

class _ExpectedLabelParseResult {
  const _ExpectedLabelParseResult({
    required this.selectedIds,
    required this.droppedLow,
    required this.confidenceBreakdown,
  });

  final List<String> selectedIds;
  final int droppedLow;
  final Map<String, int> confidenceBreakdown;
}

extension _AnyLabelToolParsingScenarios on Any {
  Generator<_GeneratedLabelCandidateShape> get labelCandidateShape =>
      choose(_GeneratedLabelCandidateShape.values);

  Generator<_GeneratedLabelIdShape> get labelIdShape =>
      choose(_GeneratedLabelIdShape.values);

  Generator<_GeneratedConfidenceShape> get labelConfidenceShape =>
      choose(_GeneratedConfidenceShape.values);

  Generator<_GeneratedLegacyPayloadShape> get legacyPayloadShape =>
      choose(_GeneratedLegacyPayloadShape.values);

  Generator<_GeneratedLegacyIdShape> get legacyIdShape =>
      choose(_GeneratedLegacyIdShape.values);

  Generator<_GeneratedLabelCandidate> get labelCandidate => combine4(
    labelCandidateShape,
    labelIdShape,
    labelConfidenceShape,
    intInRange(0, 1000),
    (
      _GeneratedLabelCandidateShape shape,
      _GeneratedLabelIdShape idShape,
      _GeneratedConfidenceShape confidenceShape,
      int value,
    ) => _GeneratedLabelCandidate(
      shape: shape,
      idShape: idShape,
      confidenceShape: confidenceShape,
      value: value,
    ),
  );

  Generator<List<_GeneratedLabelCandidate>> get labelCandidates =>
      listWithLengthInRange(0, 14, labelCandidate);

  Generator<_GeneratedLegacyLabelCandidate> get legacyLabelCandidate =>
      combine2(
        legacyIdShape,
        intInRange(0, 1000),
        (
          _GeneratedLegacyIdShape shape,
          int value,
        ) => _GeneratedLegacyLabelCandidate(
          shape: shape,
          value: value,
        ),
      );

  Generator<_GeneratedLegacyLabelPayload> get legacyLabelPayload => combine2(
    legacyPayloadShape,
    listWithLengthInRange(0, 10, legacyLabelCandidate),
    (
      _GeneratedLegacyPayloadShape shape,
      List<_GeneratedLegacyLabelCandidate> items,
    ) => _GeneratedLegacyLabelPayload(
      shape: shape,
      items: items,
    ),
  );
}

_ExpectedLabelParseResult _modelStructuredLabels(
  List<_GeneratedLabelCandidate> candidates,
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

  return _ExpectedLabelParseResult(
    selectedIds: ranked.take(3).map((candidate) => candidate.id).toList(),
    droppedLow: confidenceBreakdown['low']!,
    confidenceBreakdown: confidenceBreakdown,
  );
}

void main() {
  group('parseLabelCallArgs', () {
    test('mixed confidences → top 3, drop low, stable among equals', () {
      final args = jsonEncode({
        'labels': [
          {'id': 'l1', 'confidence': 'low'},
          {'id': 'l2', 'confidence': 'medium'},
          {'id': 'l3', 'confidence': 'very_high'},
          {'id': 'l4', 'confidence': 'high'},
          {'id': 'l5', 'confidence': 'high'},
          {'id': 'l6', 'confidence': 'medium'},
        ],
      });

      final result = parseLabelCallArgs(args);

      // Expect top 3 by rank: very_high first, then highs in original order
      expect(result.selectedIds, ['l3', 'l4', 'l5']);
      expect(result.droppedLow, 1);
      expect(result.legacyUsed, isFalse);
      expect(result.confidenceBreakdown, {
        'very_high': 1,
        'high': 2,
        'medium': 2,
        'low': 1,
      });
    });

    test('legacy labelIds only → picks first 3 and marks legacy', () {
      final args = jsonEncode({
        'labelIds': ['a', 'b', 'c', 'd', 'e'],
      });

      final result = parseLabelCallArgs(args);

      expect(result.selectedIds, ['a', 'b', 'c']);
      expect(result.droppedLow, 0);
      expect(result.legacyUsed, isTrue);
      expect(result.confidenceBreakdown, {
        'very_high': 0,
        'high': 0,
        'medium': 5,
        'low': 0,
      });
    });

    test('all low → selects none', () {
      final args = jsonEncode({
        'labels': [
          {'id': 'l1', 'confidence': 'low'},
          {'id': 'l2', 'confidence': 'low'},
        ],
      });

      final result = parseLabelCallArgs(args);
      expect(result.selectedIds, isEmpty);
      expect(result.droppedLow, 2);
      expect(result.legacyUsed, isFalse);
      expect(result.confidenceBreakdown, {
        'very_high': 0,
        'high': 0,
        'medium': 0,
        'low': 2,
      });
    });

    test('neither labels nor labelIds → returns empty selectedIds', () {
      // Test when AI calls function without providing either parameter
      final args = jsonEncode({
        'someOtherField': 'value',
      });

      final result = parseLabelCallArgs(args);
      expect(result.selectedIds, isEmpty);
      expect(result.droppedLow, 0);
      expect(result.legacyUsed, isFalse);
      expect(result.totalCandidates, 0);
      expect(result.confidenceBreakdown, {
        'very_high': 0,
        'high': 0,
        'medium': 0,
        'low': 0,
      });
    });

    test('empty labels array → returns empty selectedIds', () {
      final args = jsonEncode({
        'labels': <Map<String, dynamic>>[],
      });

      final result = parseLabelCallArgs(args);
      expect(result.selectedIds, isEmpty);
      expect(result.droppedLow, 0);
      expect(result.legacyUsed, isFalse);
      expect(result.totalCandidates, 0);
    });

    test('empty labelIds array → returns empty selectedIds', () {
      final args = jsonEncode({
        'labelIds': <String>[],
      });

      final result = parseLabelCallArgs(args);
      expect(result.selectedIds, isEmpty);
      expect(result.droppedLow, 0);
      expect(result.legacyUsed, isTrue); // labelIds was present but empty
      expect(result.totalCandidates, 0);
    });

    test('invalid JSON → returns empty selectedIds gracefully', () {
      const args = 'not valid json {{{';

      final result = parseLabelCallArgs(args);
      expect(result.selectedIds, isEmpty);
      expect(result.droppedLow, 0);
      expect(result.legacyUsed, isFalse);
    });

    Glados(any.labelCandidates, ExploreConfig(numRuns: 160)).test(
      'matches the generated structured-label selection model',
      (candidates) {
        final rawLabels = candidates.map((candidate) => candidate.toRaw());
        final args = jsonEncode({
          'labels': rawLabels.toList(),
          'labelIds': ['legacy_should_be_ignored'],
        });
        final expected = _modelStructuredLabels(candidates);

        final result = parseLabelCallArgs(args);

        expect(result.selectedIds, expected.selectedIds);
        expect(result.droppedLow, expected.droppedLow);
        expect(result.legacyUsed, isFalse);
        expect(result.confidenceBreakdown, expected.confidenceBreakdown);
        expect(result.totalCandidates, candidates.length);
      },
      tags: 'glados',
    );

    Glados(any.legacyLabelPayload, ExploreConfig(numRuns: 120)).test(
      'matches the generated legacy labelIds selection model',
      (payload) {
        final result = parseLabelCallArgs(payload.json);

        expect(result.selectedIds, payload.allIds.take(3).toList());
        expect(result.droppedLow, 0);
        expect(result.legacyUsed, isTrue);
        expect(result.confidenceBreakdown, {
          'very_high': 0,
          'high': 0,
          'medium': payload.allIds.length,
          'low': 0,
        });
        expect(result.totalCandidates, payload.allIds.length);
      },
      tags: 'glados',
    );
  });
}
