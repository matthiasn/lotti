import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';

import '../../../../../widget_test_utils.dart';

/// Replaces the real controller so the test can pin the unsaved flag and
/// record save() invocations without a full entry-controller graph.
class _FakeSaveButtonController extends SaveButtonController {
  _FakeSaveButtonController({required this.unsaved});

  final bool unsaved;
  int saveCount = 0;

  @override
  Future<bool?> build() async => unsaved;

  @override
  Future<void> save({Duration? estimate}) async {
    saveCount++;
  }
}

void main() {
  const entryId = 'entry-1';

  Future<_FakeSaveButtonController> pumpButton(
    WidgetTester tester, {
    required bool unsaved,
  }) async {
    final controller = _FakeSaveButtonController(unsaved: unsaved);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SaveButton(entryId: entryId),
        overrides: [
          saveButtonControllerProvider(entryId).overrideWith(() => controller),
        ],
      ),
    );
    // Resolve the async controller value, then run the reveal animation to
    // completion (bounded pumps, no settle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return controller;
  }

  group('SaveButton', () {
    testWidgets('renders nothing (reserves no space) with no unsaved changes', (
      tester,
    ) async {
      await pumpButton(tester, unsaved: false);

      // The button is not built at all when there is nothing to save, so it
      // reserves no layout space around the editor.
      expect(find.byType(DesignSystemButton), findsNothing);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('is shown once the reveal completes when there are unsaved '
        'changes', (
      tester,
    ) async {
      await pumpButton(tester, unsaved: true);

      expect(find.byType(DesignSystemButton), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('tapping the button calls save() on the controller', (
      tester,
    ) async {
      final controller = await pumpButton(tester, unsaved: true);

      await tester.tap(find.byType(DesignSystemButton));
      await tester.pump();

      expect(controller.saveCount, 1);
    });
  });
}
