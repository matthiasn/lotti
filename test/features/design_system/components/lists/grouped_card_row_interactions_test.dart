import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_interactions.dart';

void main() {
  group('buildGroupedCardRowInteractions', () {
    test('keeps the divider when adjacent rows are inactive', () {
      final interactions = buildGroupedCardRowInteractions(
        priorities: const [0, 0],
        connectedBelow: const [true],
      );

      expect(interactions, hasLength(2));
      expect(interactions[0].showDividerBelow, isTrue);
      expect(interactions[0].bottomOverlap, 0);
      expect(interactions[1].topOverlap, 0);
    });

    test('gives the overlap to the lower active row and hides the divider', () {
      final interactions = buildGroupedCardRowInteractions(
        priorities: const [0, 1],
        connectedBelow: const [true],
      );

      expect(interactions[0].showDividerBelow, isFalse);
      expect(interactions[0].bottomOverlap, 0);
      expect(interactions[1].topOverlap, 1);
    });

    test('a single row has no edges, so no overlap and no divider', () {
      final interactions = buildGroupedCardRowInteractions(
        priorities: const [0],
        connectedBelow: const [],
      );

      expect(interactions, hasLength(1));
      expect(interactions.single.topOverlap, 0);
      expect(interactions.single.bottomOverlap, 0);
      expect(interactions.single.showDividerBelow, isFalse);
    });

    test('an empty list yields no interactions', () {
      final interactions = buildGroupedCardRowInteractions(
        priorities: const [],
        connectedBelow: const [],
      );

      expect(interactions, isEmpty);
    });

    test('does not coordinate rows across disconnected boundaries', () {
      final interactions = buildGroupedCardRowInteractions(
        priorities: const [0, 1],
        connectedBelow: const [false],
      );

      expect(interactions[0].showDividerBelow, isFalse);
      expect(interactions[0].bottomOverlap, 0);
      expect(interactions[1].topOverlap, 0);
    });
  });
}
