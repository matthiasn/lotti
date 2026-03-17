import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_picker.dart';
import 'package:lotti/utils/file_utils.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2024, 3, 15);

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  ProjectStatus makeOpen() => ProjectStatus.open(
    id: uuid.v1(),
    createdAt: now,
    utcOffset: 0,
  );

  group('ProjectStatusPicker', () {
    testWidgets('displays current status label and chevron', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectStatusPicker(
            currentStatus: makeOpen(),
            onStatusChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Open'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('tapping opens bottom sheet with all 5 status options', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectStatusPicker(
            currentStatus: makeOpen(),
            onStatusChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Bottom sheet title
      expect(find.text('Change Status'), findsOneWidget);

      // All 5 options
      // "Open" appears twice: once in the picker widget behind the sheet,
      // and once as an option in the sheet.
      expect(find.text('Open'), findsNWidgets(2));
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('On Hold'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('current status shows check mark in sheet', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectStatusPicker(
            currentStatus: makeOpen(),
            onStatusChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('selecting a different status calls onStatusChanged', (
      tester,
    ) async {
      ProjectStatus? selectedStatus;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectStatusPicker(
            currentStatus: makeOpen(),
            onStatusChanged: (status) => selectedStatus = status,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      expect(selectedStatus, isA<ProjectActive>());
    });

    testWidgets('selecting current status does not call onStatusChanged', (
      tester,
    ) async {
      var callCount = 0;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectStatusPicker(
            currentStatus: makeOpen(),
            onStatusChanged: (_) => callCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the "Open" option in the sheet (second occurrence)
      final openOptions = find.text('Open');
      await tester.tap(openOptions.last);
      await tester.pumpAndSettle();

      expect(callCount, 0);
    });

    testWidgets('sheet dismisses after selection', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectStatusPicker(
            currentStatus: makeOpen(),
            onStatusChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Change Status'), findsOneWidget);

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('Change Status'), findsNothing);
    });
  });
}
