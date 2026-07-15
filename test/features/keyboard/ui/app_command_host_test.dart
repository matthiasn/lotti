import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/keyboard/ui/keyboard_focus_region.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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

  testWidgets('native-style invocation retains the last focused local scope', (
    tester,
  ) async {
    var globalSaves = 0;
    var localSaves = 0;
    late BuildContext globalContext;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          platform: TargetPlatform.macOS,
          handlers: {
            AppCommandId.save: AppCommandHandler(
              invoke: (_) => globalSaves++,
            ),
          },
          child: Builder(
            builder: (context) {
              globalContext = context;
              return AppCommandScope(
                handlers: {
                  AppCommandId.save: AppCommandHandler(
                    invoke: (_) => localSaves++,
                  ),
                },
                child: TextField(focusNode: focusNode),
              );
            },
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    focusNode.unfocus();
    await tester.pump();

    final invoked = await AppCommandControllerProvider.of(
      globalContext,
    ).invoke(globalContext, AppCommandId.save);

    expect(invoked, isTrue);
    expect((localSaves, globalSaves), (1, 0));
  });

  testWidgets('prevents re-entry for an unfinished one-shot command', (
    tester,
  ) async {
    final completer = Completer<void>();
    var calls = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          platform: TargetPlatform.windows,
          handlers: {
            AppCommandId.save: AppCommandHandler(
              invoke: (_) {
                calls++;
                return completer.future;
              },
            ),
          },
          child: TextField(focusNode: focusNode),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(calls, 1);
    completer.complete();
    await tester.pump();
  });

  testWidgets(
    'captured scopes stop dispatching after their widget is removed',
    (
      tester,
    ) async {
      var saves = 0;
      late StateSetter updateHarness;
      late BuildContext scopedContext;
      var showScope = true;
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _testApp(
          AppCommandHost(
            platform: TargetPlatform.windows,
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
                      return TextField(focusNode: focusNode);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      final snapshot = AppCommandControllerProvider.of(
        scopedContext,
      ).capture(scopedContext);
      expect(snapshot.isAvailable(AppCommandId.save), isTrue);

      updateHarness(() => showScope = false);
      await tester.pump();

      expect(snapshot.isAvailable(AppCommandId.save), isFalse);
      expect(await snapshot.invoke(AppCommandId.save), isFalse);
      expect(saves, 0);
    },
  );

  testWidgets('F6 cycles focus regions and Shift+F6 reverses', (tester) async {
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          platform: TargetPlatform.windows,
          handlers: const {},
          child: Builder(
            builder: (context) => Column(
              children: [
                KeyboardFocusRegion(
                  debugLabel: context.messages.navTabTitleTasks,
                  preferredFocusNode: first,
                  child: TextButton(
                    focusNode: first,
                    onPressed: () {},
                    child: const Text('First'),
                  ),
                ),
                KeyboardFocusRegion(
                  debugLabel: context.messages.navTabTitleJournal,
                  preferredFocusNode: second,
                  child: TextButton(
                    focusNode: second,
                    onPressed: () {},
                    child: const Text('Second'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    first.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    await tester.pump();
    expect(second.hasFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(first.hasFocus, isTrue);
  });
}

Widget _testApp(Widget child) =>
    makeTestableWidgetNoScroll(Scaffold(body: child));
