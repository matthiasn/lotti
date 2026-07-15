import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('captured scopes stop dispatching after removal', (tester) async {
    var saves = 0;
    late StateSetter updateHarness;
    late BuildContext scopedContext;
    var showScope = true;

    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          handlers: const {},
          child: StatefulBuilder(
            builder: (context, setState) {
              updateHarness = setState;
              if (!showScope) return const SizedBox.shrink();
              return AppCommandScope(
                handlers: {
                  AppCommandId.save: AppCommandHandler(
                    invoke: (_) => saves++,
                  ),
                },
                child: Builder(
                  builder: (context) {
                    scopedContext = context;
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    final snapshot = AppCommandControllerProvider.of(
      scopedContext,
    ).capture(scopedContext);
    expect(snapshot.isAvailable(AppCommandId.save), isTrue);

    updateHarness(() => showScope = false);
    await tester.pump();

    expect(snapshot.isAvailable(AppCommandId.save), isFalse);
    expect(await snapshot.invoke(AppCommandId.save), isFalse);
    expect(saves, 0);
  });

  testWidgets('disabled local handlers fall back to the parent scope', (
    tester,
  ) async {
    var parentSaves = 0;
    var localSaves = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          platform: TargetPlatform.windows,
          handlers: {
            AppCommandId.save: AppCommandHandler(
              invoke: (_) => parentSaves++,
            ),
          },
          child: AppCommandScope(
            handlers: {
              AppCommandId.save: AppCommandHandler(
                isEnabled: () => false,
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

    expect((parentSaves, localSaves), (1, 0));
  });

  testWidgets('moves its registration when the provider controller changes', (
    tester,
  ) async {
    final first = AppCommandController();
    final second = AppCommandController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var firstNotifications = 0;
    var saves = 0;
    first.addListener(() => firstNotifications++);
    var useSecond = false;
    late StateSetter updateProvider;
    late BuildContext scopedContext;

    await tester.pumpWidget(
      _testApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateProvider = setState;
            return AppCommandControllerProvider(
              controller: useSecond ? second : first,
              platform: TargetPlatform.windows,
              child: AppCommandScope(
                handlers: {
                  AppCommandId.save: AppCommandHandler(invoke: (_) => saves++),
                },
                child: Builder(
                  builder: (context) {
                    scopedContext = context;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(first.capture(scopedContext).isAvailable(AppCommandId.save), isTrue);
    final firstBeforeMove = firstNotifications;

    updateProvider(() => useSecond = true);
    await tester.pump();

    expect(firstNotifications, greaterThan(firstBeforeMove));
    expect(
      second.capture(scopedContext).isAvailable(AppCommandId.save),
      isTrue,
    );
    expect(await second.invoke(scopedContext, AppCommandId.save), isTrue);
    expect(saves, 1);
  });
}

Widget _testApp(Widget child) =>
    makeTestableWidgetNoScroll(Scaffold(body: child));
