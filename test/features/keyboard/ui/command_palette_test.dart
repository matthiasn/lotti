import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/command_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('opens as a searchable dialog and Escape closes it', (
    tester,
  ) async {
    final snapshot = _Snapshot();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => TextButton(
            focusNode: focusNode,
            onPressed: () => showAppCommandPalette(context, snapshot),
            child: const Text('Open'),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1000, 800)),
      ),
    );
    final messages = tester.element(find.text('Open')).messages;
    focusNode.requestFocus();
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(find.text(messages.commandPaletteTitle), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text(messages.commandPaletteTitle), findsNothing);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('restores focus before dispatching a selected command', (
    tester,
  ) async {
    final snapshot = _Snapshot();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => TextButton(
            focusNode: focusNode,
            onPressed: () => showAppCommandPalette(context, snapshot),
            child: const Text('Open'),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1000, 800)),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    expect(snapshot.invoked, [AppCommandId.openShortcutHelp]);
  });
}

class _Snapshot implements AppCommandContextSnapshot {
  final List<AppCommandId> invoked = [];

  @override
  bool isAvailable(AppCommandId id) => id == AppCommandId.openShortcutHelp;

  @override
  Future<bool> invoke(AppCommandId id) async {
    invoked.add(id);
    return true;
  }
}
