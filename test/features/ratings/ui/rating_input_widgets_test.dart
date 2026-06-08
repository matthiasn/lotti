import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ratings/ui/rating_input_widgets.dart';

import '../../../widget_test_utils.dart';

/// Builds `count` segments whose values are spaced 0.1 apart, so every value
/// is well outside the 0.01 selection tolerance of any other and the selected
/// index is unambiguous.
List<({String label, double value})> _segmentsOfLength(int count) => [
  for (var i = 0; i < count; i++) (label: 'Opt $i', value: i * 0.1),
];

void main() {
  group('RatingTapBar', () {
    testWidgets('renders with null value', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          RatingTapBar(
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RatingTapBar), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('renders with set value', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          RatingTapBar(
            value: 0.7,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RatingTapBar), findsOneWidget);
    });

    testWidgets('calls onChanged when tapped', (tester) async {
      double? capturedValue;
      await tester.pumpWidget(
        makeTestableWidget(
          RatingTapBar(
            value: null,
            onChanged: (v) => capturedValue = v,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(RatingTapBar));
      await tester.pump();

      expect(capturedValue, isNotNull);
      expect(capturedValue, greaterThanOrEqualTo(0.0));
      expect(capturedValue, lessThanOrEqualTo(1.0));
    });

    testWidgets('calls onChanged on horizontal drag', (tester) async {
      final capturedValues = <double>[];
      await tester.pumpWidget(
        makeTestableWidget(
          RatingTapBar(
            value: 0.5,
            onChanged: capturedValues.add,
          ),
        ),
      );
      await tester.pump();

      // Drag across the tap bar
      await tester.drag(
        find.byType(RatingTapBar),
        const Offset(100, 0),
      );
      await tester.pump();

      expect(capturedValues, isNotEmpty);
    });
  });

  group('RatingSegmentedInput', () {
    testWidgets('renders label and segments', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          RatingSegmentedInput(
            label: 'Test question',
            segments: const [
              (label: 'Low', value: 0.0),
              (label: 'Medium', value: 0.5),
              (label: 'High', value: 1.0),
            ],
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test question'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('highlights selected segment', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          RatingSegmentedInput(
            label: 'Test question',
            segments: const [
              (label: 'Low', value: 0.0),
              (label: 'Medium', value: 0.5),
              (label: 'High', value: 1.0),
            ],
            value: 0.5,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      // SegmentedButton uses int indices; value 0.5 maps to index 1
      final segmented = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(segmented.selected, equals({1}));
    });

    testWidgets('calls onChanged when segment is tapped', (tester) async {
      double? capturedValue;
      await tester.pumpWidget(
        makeTestableWidget(
          RatingSegmentedInput(
            label: 'Test question',
            segments: const [
              (label: 'Low', value: 0.0),
              (label: 'Medium', value: 0.5),
              (label: 'High', value: 1.0),
            ],
            value: null,
            onChanged: (v) => capturedValue = v,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('High'));
      await tester.pump();

      expect(capturedValue, equals(1.0));
    });

    testWidgets('renders with empty selection when value is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          RatingSegmentedInput(
            label: 'Question',
            segments: const [
              (label: 'A', value: 0.0),
              (label: 'B', value: 1.0),
            ],
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      final segmented = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(segmented.selected, isEmpty);
    });

    testWidgets('selecting a segment value highlights the matching index', (
      tester,
    ) async {
      final segments = _segmentsOfLength(4);
      // Drive the widget with the 3rd segment's value and confirm the
      // round-trip surfaces through the public SegmentedButton selection.
      await tester.pumpWidget(
        makeTestableWidget(
          RatingSegmentedInput(
            label: 'Question',
            segments: segments,
            value: segments[2].value,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      final segmented = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(segmented.selected, equals({2}));
    });
  });

  group('selectedSegmentIndex', () {
    test('returns -1 for a null value', () {
      expect(selectedSegmentIndex(_segmentsOfLength(3), null), -1);
    });

    test('returns -1 when no segment is within tolerance', () {
      // 0.25 sits 0.05 from both 0.2 and 0.3, outside the 0.01 band.
      expect(selectedSegmentIndex(_segmentsOfLength(4), 0.25), -1);
    });

    test('matches within the 0.01 tolerance band', () {
      final segments = _segmentsOfLength(4);
      // 0.205 is within 0.01 of segment 2 (value 0.2), but no other.
      expect(selectedSegmentIndex(segments, 0.205), 2);
    });

    test('does not match exactly at the tolerance boundary', () {
      final segments = _segmentsOfLength(4);
      // Exactly 0.01 away is NOT a match (strict `< 0.01`).
      expect(selectedSegmentIndex(segments, segments[1].value + 0.01), -1);
    });

    // Round-trip property: feeding any segment's own value back into the
    // lookup must return that segment's index. Confirms the index<->value
    // mapping stays in sync if the tolerance is ever adjusted.
    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(2, 9),
      glados.IntAnys(glados.any).intInRange(0, 9),
      glados.ExploreConfig(numRuns: 120),
    ).test('round-trips every segment value to its index', (count, rawIndex) {
      final segments = _segmentsOfLength(count);
      final index = rawIndex % count;
      expect(
        selectedSegmentIndex(segments, segments[index].value),
        index,
        reason:
            'value ${segments[index].value} should map back to index $index '
            'in a $count-segment list',
      );
    }, tags: 'glados');
  });
}
