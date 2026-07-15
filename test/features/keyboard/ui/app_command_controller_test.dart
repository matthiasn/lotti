import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('native invocation retains the last focused local scope', (
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
    late BuildContext commandContext;

    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          handlers: {
            AppCommandId.save: AppCommandHandler(
              invoke: (_) {
                calls++;
                return completer.future;
              },
            ),
          },
          child: Builder(
            builder: (context) {
              commandContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    final controller = AppCommandControllerProvider.of(commandContext);

    final first = controller.invoke(commandContext, AppCommandId.save);
    final second = await controller.invoke(commandContext, AppCommandId.save);

    expect(second, isFalse);
    expect(calls, 1);
    completer.complete();
    expect(await first, isTrue);
  });

  testWidgets('resolves a handler and its owner context atomically', (
    tester,
  ) async {
    final parentKey = GlobalKey();
    final childKey = GlobalKey();
    var enabledChecks = 0;
    var parentCalls = 0;
    var childCalls = 0;
    BuildContext? invocationContext;
    late BuildContext commandContext;

    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          handlers: const {},
          child: AppCommandScope(
            key: parentKey,
            handlers: {
              AppCommandId.save: AppCommandHandler(
                invoke: (invocation) {
                  parentCalls++;
                  invocationContext = invocation.context;
                },
              ),
            },
            child: AppCommandScope(
              key: childKey,
              handlers: {
                AppCommandId.save: AppCommandHandler(
                  isEnabled: () => enabledChecks++ == 0,
                  invoke: (invocation) {
                    childCalls++;
                    invocationContext = invocation.context;
                  },
                ),
              },
              child: Builder(
                builder: (context) {
                  commandContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    );

    final invoked = await AppCommandControllerProvider.of(
      commandContext,
    ).invoke(commandContext, AppCommandId.save);

    expect(invoked, isTrue);
    expect(enabledChecks, 1);
    expect((parentCalls, childCalls), (0, 1));
    expect(invocationContext, same(childKey.currentContext));
  });

  testWidgets('reports handler failures and returns false', (tester) async {
    Object? reportedError;
    late BuildContext commandContext;
    await tester.pumpWidget(
      _testApp(
        AppCommandHost(
          onError: (_, error, _) => reportedError = error,
          handlers: {
            AppCommandId.save: AppCommandHandler(
              invoke: (_) => throw StateError('failed'),
            ),
          },
          child: Builder(
            builder: (context) {
              commandContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final invoked = await AppCommandControllerProvider.of(
      commandContext,
    ).invoke(commandContext, AppCommandId.save);

    expect(invoked, isFalse);
    expect(reportedError, isA<StateError>());
  });

  testWidgets('disposed controllers ignore queued notifications', (
    tester,
  ) async {
    final controller = AppCommandController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            controller
              ..scopeChanged()
              ..dispose();
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(notifications, 0);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Widget child) =>
    makeTestableWidgetNoScroll(Scaffold(body: child));
