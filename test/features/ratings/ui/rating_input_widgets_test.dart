import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ratings/ui/rating_input_widgets.dart';

import '../../../widget_test_utils.dart';

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      await tester.tap(find.byType(RatingTapBar));
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Drag across the tap bar
      await tester.drag(
        find.byType(RatingTapBar),
        const Offset(100, 0),
      );
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // SegmentedButton should render with the value selected
      final segmented = tester.widget<SegmentedButton<double>>(
        find.byType(SegmentedButton<double>),
      );
      expect(segmented.selected, equals({0.5}));
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
      await tester.pumpAndSettle();

      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      expect(capturedValue, equals(1.0));
    });

    testWidgets('renders with empty selection when value is null',
        (tester) async {
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
      await tester.pumpAndSettle();

      final segmented = tester.widget<SegmentedButton<double>>(
        find.byType(SegmentedButton<double>),
      );
      expect(segmented.selected, isEmpty);
    });
  });
}
