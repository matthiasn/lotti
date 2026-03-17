import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/ui/widgets/project_target_date_field.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  group('ProjectTargetDateField', () {
    testWidgets('shows localized label text', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectTargetDateField(
            targetDate: null,
            onDatePicked: () {},
            onCleared: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Target Date'), findsOneWidget);
    });

    testWidgets('shows formatted date when targetDate is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectTargetDateField(
            targetDate: DateTime(2024, 6, 15),
            onDatePicked: () {},
            onCleared: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2024-06-15'), findsOneWidget);
    });

    testWidgets('shows clear icon button when targetDate is set and '
        'tapping it calls onCleared', (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectTargetDateField(
            targetDate: DateTime(2024, 6, 15),
            onDatePicked: () {},
            onCleared: () => cleared = true,
          ),
        ),
      );
      await tester.pump();

      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      expect(cleared, isTrue);
    });

    testWidgets('does not show clear icon button when targetDate is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectTargetDateField(
            targetDate: null,
            onDatePicked: () {},
            onCleared: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('tapping the field calls onDatePicked', (tester) async {
      var picked = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectTargetDateField(
            targetDate: null,
            onDatePicked: () => picked = true,
            onCleared: null,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(InkWell));
      expect(picked, isTrue);
    });
  });
}
