import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/features/journal/ui/widgets/journal_app_bar.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

import '../../../../widget_test_utils.dart';

/// Pins the unsaved flag without booting the full entry-controller graph.
class _FakeSaveButtonController extends SaveButtonController {
  @override
  Future<bool?> build({required String id}) async => false;
}

void main() {
  const entryId = 'entry-42';

  Future<void> pumpAppBar(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const CustomScrollView(
          slivers: [JournalSliverAppBar(entryId: entryId)],
        ),
        overrides: [
          saveButtonControllerProvider(
            id: entryId,
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
  });
}
