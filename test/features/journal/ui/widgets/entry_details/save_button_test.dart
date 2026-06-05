import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

import '../../../../../widget_test_utils.dart';

/// Replaces the real controller so the test can pin the unsaved flag and
/// record save() invocations without a full entry-controller graph.
class _FakeSaveButtonController extends SaveButtonController {
  _FakeSaveButtonController({required this.unsaved});

  final bool unsaved;
  int saveCount = 0;

  @override
  Future<bool?> build({required String id}) async => unsaved;

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
          saveButtonControllerProvider(
            id: entryId,
          ).overrideWith(() => controller),
        ],
      ),
    );
    // Resolve the async controller value, then run the 500ms opacity
    // animation to completion (bounded pumps, no settle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return controller;
  }

  group('SaveButton', () {
    testWidgets('is invisible (opacity 0) when there are no unsaved changes', (
      tester,
    ) async {
      await pumpButton(tester, unsaved: false);

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, 0);
    });

    testWidgets('is visible (opacity 1) when there are unsaved changes', (
      tester,
    ) async {
      await pumpButton(tester, unsaved: true);

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, 1);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('tapping the button calls save() on the controller', (
      tester,
    ) async {
      final controller = await pumpButton(tester, unsaved: true);

      await tester.tap(find.byType(LottiTertiaryButton));
      await tester.pump();

      expect(controller.saveCount, 1);
    });
  });
}
