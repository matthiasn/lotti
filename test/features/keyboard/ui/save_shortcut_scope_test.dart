import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/save_shortcut_scope.dart';
import 'package:material_ui/material_ui.dart';

import '../../../test_helper.dart';

void main() {
  Future<void> pumpScope(
    WidgetTester tester, {
    required SaveShortcutScope scope,
    TargetPlatform platform = TargetPlatform.windows,
  }) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: AppCommandHost(
          handlers: const <AppCommandId, AppCommandHandler>{},
          platform: platform,
          child: scope,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pressSave(
    WidgetTester tester,
    LogicalKeyboardKey primary,
  ) async {
    await tester.sendKeyDownEvent(primary);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(primary);
  }

  for (final (platform, primaryKey) in [
    (TargetPlatform.windows, LogicalKeyboardKey.control),
    (TargetPlatform.macOS, LogicalKeyboardKey.meta),
  ]) {
    testWidgets('Primary+S invokes onSave on ${platform.name}', (
      tester,
    ) async {
      var saves = 0;
      await pumpScope(
        tester,
        platform: platform,
        scope: SaveShortcutScope(
          onSave: () => saves++,
          child: const Focus(autofocus: true, child: SizedBox.shrink()),
        ),
      );

      final focusedContext = FocusManager.instance.primaryFocus!.context!;
      final controller = AppCommandControllerProvider.of(focusedContext);
      expect(
        controller.isAvailable(focusedContext, AppCommandId.save),
        isTrue,
      );

      await pressSave(tester, primaryKey);
      expect(saves, 1);
    });
  }

  testWidgets('live availability controls Primary+S', (tester) async {
    var saves = 0;
    var saveEnabled = false;
    await pumpScope(
      tester,
      scope: SaveShortcutScope(
        onSave: () => saves++,
        isEnabled: () => saveEnabled,
        child: const Focus(autofocus: true, child: SizedBox.shrink()),
      ),
    );

    final focusedContext = FocusManager.instance.primaryFocus!.context!;
    final controller = AppCommandControllerProvider.of(focusedContext);
    expect(controller.isAvailable(focusedContext, AppCommandId.save), isFalse);

    await pressSave(tester, LogicalKeyboardKey.control);
    expect(saves, 0);

    saveEnabled = true;
    expect(controller.isAvailable(focusedContext, AppCommandId.save), isTrue);

    await pressSave(tester, LogicalKeyboardKey.control);
    expect(saves, 1);
  });
}
