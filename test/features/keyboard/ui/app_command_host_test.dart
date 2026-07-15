import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/keyboard/ui/keyboard_focus_region.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('dispatches a primary shortcut to the nearest focused scope', (
    tester,
  ) async {
    var globalSaves = 0;
    var localSaves = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          platform: TargetPlatform.windows,
          handlers: {
            AppCommandId.save: AppCommandHandler(
              invoke: (_) => globalSaves++,
            ),
          },
          child: AppCommandScope(
            handlers: {
              AppCommandId.save: AppCommandHandler(
                invoke: (_) => localSaves++,
              ),
            },
            child: TextField(focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect((localSaves, globalSaves), (1, 0));
  });

  testWidgets('falls back to the global scope and reports key activity', (
    tester,
  ) async {
    var calls = 0;
    var activity = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          platform: TargetPlatform.windows,
          onActivity: () => activity++,
          handlers: {
            AppCommandId.refresh: AppCommandHandler(
              invoke: (_) => calls++,
            ),
          },
          child: TextField(focusNode: focusNode),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(calls, 1);
    expect(activity, greaterThanOrEqualTo(2));
  });

  testWidgets('updates the error callback without replacing the controller', (
    tester,
  ) async {
    var oldErrors = 0;
    var newErrors = 0;
    var useNewHandler = false;
    late StateSetter updateHost;
    late BuildContext scopedContext;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _testApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return AppCommandHost(
              platform: TargetPlatform.windows,
              onError: useNewHandler
                  ? (_, _, _) => newErrors++
                  : (_, _, _) => oldErrors++,
              handlers: const {},
              child: AppCommandScope(
                handlers: {
                  AppCommandId.save: AppCommandHandler(
                    invoke: (_) => throw StateError('save failed'),
                  ),
                },
                child: Builder(
                  builder: (context) {
                    scopedContext = context;
                    return TextField(focusNode: focusNode);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    final originalController = AppCommandControllerProvider.of(scopedContext);

    updateHost(() => useNewHandler = true);
    await tester.pump();
    final updatedController = AppCommandControllerProvider.of(scopedContext);
    final invoked = await updatedController.invoke(
      scopedContext,
      AppCommandId.save,
    );

    expect(identical(updatedController, originalController), isTrue);
    expect(invoked, isFalse);
    expect((oldErrors, newErrors), (0, 1));
  });

  testWidgets('adopts and releases an external focus-region controller', (
    tester,
  ) async {
    final external = KeyboardFocusRegionController();
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(external.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var useExternal = false;
    late StateSetter updateHost;

    await tester.pumpWidget(
      _testApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return AppCommandHost(
              handlers: const {},
              focusRegionController: useExternal ? external : null,
              child: Column(
                children: [
                  KeyboardFocusRegion(
                    debugLabel: 'first',
                    preferredFocusNode: first,
                    child: TextButton(
                      focusNode: first,
                      onPressed: () {},
                      child: const Text('First'),
                    ),
                  ),
                  KeyboardFocusRegion(
                    debugLabel: 'second',
                    preferredFocusNode: second,
                    child: TextButton(
                      focusNode: second,
                      onPressed: () {},
                      child: const Text('Second'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    updateHost(() => useExternal = true);
    await tester.pump();
    expect(external.focusNext(), isTrue);
    await tester.pump();
    expect(first.hasFocus, isTrue);

    updateHost(() => useExternal = false);
    await tester.pump();
    expect(external.focusNext(), isFalse);
  });
}

Widget _testApp(Widget child) =>
    makeTestableWidgetNoScroll(Scaffold(body: child));
