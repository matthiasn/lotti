import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/features/journal/ui/widgets/journal_app_bar.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

import '../../../../widget_test_utils.dart';

/// Pins the unsaved flag without booting the full entry-controller graph.
class _FakeSaveButtonController extends SaveButtonController {
  @override
  Future<bool?> build() async => false;
}

void main() {
  const entryId = 'entry-42';

  Future<void> pumpAppBar(
    WidgetTester tester, {
    bool showBackButton = true,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CustomScrollView(
          slivers: [
            JournalSliverAppBar(
              entryId: entryId,
              showBackButton: showBackButton,
            ),
          ],
        ),
        overrides: [
          saveButtonControllerProvider(
            entryId,
          ).overrideWith(_FakeSaveButtonController.new),
        ],
      ),
    );
    // Resolve the async save-button controller, then run its 500ms opacity
    // animation to completion (bounded pumps, no settle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('JournalSliverAppBar', () {
    testWidgets('forwards its entryId to the SaveButton action', (
      tester,
    ) async {
      await pumpAppBar(tester);

      final saveButton = tester.widget<SaveButton>(find.byType(SaveButton));
      expect(saveButton.entryId, entryId);
    });

    testWidgets('renders a pinned bar with the BackWidget leading', (
      tester,
    ) async {
      await pumpAppBar(tester);

      expect(find.byType(BackWidget), findsOneWidget);
      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(bar.pinned, isTrue);
      expect(bar.automaticallyImplyLeading, isFalse);
    });

    testWidgets(
      'hides the back affordance in the desktop split pane '
      '(showBackButton false)',
      (tester) async {
        await pumpAppBar(tester, showBackButton: false);

        expect(find.byType(BackWidget), findsNothing);
        final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
        expect(bar.leading, isNull);
        expect(bar.leadingWidth, 0);
        // The save action must survive losing the back button.
        expect(find.byType(SaveButton), findsOneWidget);
      },
    );

    testWidgets('paints the unified logbook canvas, not the default '
        'app-bar background', (tester) async {
      await pumpAppBar(tester);

      final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      final context = tester.element(find.byType(SliverAppBar));
      expect(bar.backgroundColor, dsPageSurface(context));
      expect(bar.surfaceTintColor, Colors.transparent);
    });
  });
}
