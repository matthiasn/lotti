import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';
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
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('tapping opens adaptive modal with all 6 status options', (
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Adaptive modal title.
      expect(find.text('Change status'), findsOneWidget);

      // All 6 options
      // "Open" appears twice: once in the picker widget behind the sheet,
      // and once as an option in the sheet.
      expect(find.text('Open'), findsNWidgets(2));
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Monitoring'), findsOneWidget);
      expect(find.text('On Hold'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);

      // The shared selection anatomy renders one row per status kind.
      expect(
        find.descendant(
          of: find.byType(ProjectStatusModalContent),
          matching: find.byType(DesignSystemSelectionRow),
        ),
        findsNWidgets(allProjectStatusKinds.length),
      );
      expect(find.byType(Divider), findsNothing);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Active'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the "Open" option in the sheet (second occurrence)
      final openOptions = find.text('Open');
      await tester.tap(openOptions.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Change status'), findsOneWidget);

      await tester.ensureVisible(find.text('Completed'));
      await tester.pump();
      await tester.tap(find.text('Completed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Sheet should be dismissed
      expect(find.text('Change status'), findsNothing);
    });
  });
}
