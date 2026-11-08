import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_picker.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/projects/project_status_attributes.dart';
import 'package:material_ui/material_ui.dart';

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

  group('showProjectStatusPickerModal', () {
    /// Opens the picker over [currentStatus]; the returned list receives the
    /// modal's result once it closes.
    Future<List<ProjectStatus?>> openPicker(
      WidgetTester tester,
      ProjectStatus currentStatus,
    ) async {
      final results = <ProjectStatus?>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showProjectStatusPickerModal(
                  context: context,
                  currentStatus: currentStatus,
                ),
              ),
              child: const Text('open picker'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return results;
    }

    testWidgets('lists every status kind under the change-status title', (
      tester,
    ) async {
      await openPicker(tester, makeOpen());

      expect(find.text('Change status'), findsOneWidget);
      for (final label in [
        'Open',
        'Active',
        'Monitoring',
        'On Hold',
        'Completed',
        'Archived',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        find.descendant(
          of: find.byType(ProjectStatusModalContent),
          matching: find.byType(DesignSystemSelectionRow),
        ),
        findsNWidgets(allProjectStatusKinds.length),
      );
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('marks only the current status', (tester) async {
      await openPicker(tester, makeOpen());

      expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
    });

    testWidgets('returns a different status and closes', (tester) async {
      final results = await openPicker(tester, makeOpen());

      await tester.ensureVisible(find.text('Completed'));
      await tester.pump();
      await tester.tap(find.text('Completed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(results.single, isA<ProjectCompleted>());
      expect(find.text('Change status'), findsNothing);
    });

    testWidgets('returns null when the current status is picked again', (
      tester,
    ) async {
      final results = await openPicker(tester, makeOpen());

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(results, [null]);
    });
  });
}
