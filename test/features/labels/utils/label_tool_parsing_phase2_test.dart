import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';

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
        'labelIds': ['a', 'b', 'c', 'd', 'e']
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
  });
}
