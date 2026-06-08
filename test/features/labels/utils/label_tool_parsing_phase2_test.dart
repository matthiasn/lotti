import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show ExploreConfig, Glados, any;
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';
import 'label_tool_parsing_phase2_test_helpers.dart';

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
        final expected = hModelStructuredLabels(candidates);

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

  // Focused property tests pinning the private `_confidenceToRank` /
  // `_normalizeConfidence` contract through the public parser, per TEST_REVIEW.
  group('confidence normalization / rank contract', () {
    bool isCanonical(String s) => hCanonicalConfidenceRanks.containsKey(s);

    Glados(any.confidenceProbe, ExploreConfig(numRuns: 120)).test(
      'a single candidate is bucketed into exactly one valid confidence; '
      'unknown values normalize to medium',
      (confidence) {
        final args = jsonEncode({
          'labels': [
            {'id': 'only', 'confidence': confidence},
          ],
        });

        final result = parseLabelCallArgs(args);
        final breakdown = result.confidenceBreakdown;

        // Only the four canonical keys exist, and exactly one of them counts
        // the single candidate -> normalized confidence is always one of four.
        expect(
          breakdown.keys.toSet(),
          hCanonicalConfidenceRanks.keys.toSet(),
        );
        expect(
          breakdown.values.where((v) => v == 1).length,
          1,
          reason: 'the single candidate must land in exactly one bucket',
        );
        expect(breakdown.values.fold<int>(0, (a, b) => a + b), 1);

        final bucket = breakdown.entries.firstWhere((e) => e.value == 1).key;
        // Unknown / non-canonical confidences normalize to 'medium'.
        if (!isCanonical(confidence)) {
          expect(bucket, 'medium');
        } else {
          expect(bucket, confidence);
        }
      },
      tags: 'glados',
    );

    Glados(any.confidenceProbe, ExploreConfig(numRuns: 120)).test(
      'rank 0 (low) is dropped; rank > 0 is selected',
      (confidence) {
        final args = jsonEncode({
          'labels': [
            {'id': 'only', 'confidence': confidence},
          ],
        });

        final result = parseLabelCallArgs(args);

        // Effective rank: canonical lookup, else medium (rank 1) for unknowns.
        final effectiveRank =
            hCanonicalConfidenceRanks[confidence] ??
            hCanonicalConfidenceRanks['medium']!;

        // Rank is always within the 0..3 band.
        expect(effectiveRank, inInclusiveRange(0, 3));

        if (effectiveRank == 0) {
          // 'low' is the only rank-0 confidence -> dropped, not selected.
          expect(result.selectedIds, isEmpty);
          expect(result.droppedLow, 1);
        } else {
          expect(result.selectedIds, ['only']);
          expect(result.droppedLow, 0);
        }
      },
      tags: 'glados',
    );

    test('ranks order selection very_high > high > medium and drop low', () {
      // Deterministic ladder check covering all four ranks at once: the three
      // non-low candidates are selected in strict descending rank order, and
      // the low candidate is dropped.
      final args = jsonEncode({
        'labels': [
          {'id': 'l_low', 'confidence': 'low'},
          {'id': 'm', 'confidence': 'medium'},
          {'id': 'vh', 'confidence': 'very_high'},
          {'id': 'h', 'confidence': 'high'},
        ],
      });

      final result = parseLabelCallArgs(args);

      expect(result.selectedIds, ['vh', 'h', 'm']);
      expect(result.droppedLow, 1);
    });
  });
}
