import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/command_catalog_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('palette filters active commands and invokes selection', (
    tester,
  ) async {
    final snapshot = _Snapshot({AppCommandId.refresh});
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: CommandCatalogView(
            paletteMode: true,
            snapshot: snapshot,
            platform: TargetPlatform.windows,
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(800, 800)),
      ),
    );
    final messages = tester.element(find.byType(CommandCatalogView)).messages;

    expect(find.text(messages.keyboardCommandRefresh), findsOneWidget);
    expect(find.text(messages.fileMenuNewTask), findsNothing);

    await tester.enterText(find.byType(TextField), 'refresh');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(snapshot.invoked, [AppCommandId.refresh]);
  });

  testWidgets('help exposes hidden interaction grammar and exact bindings', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(
          body: CommandCatalogView(
            paletteMode: false,
            platform: TargetPlatform.windows,
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(800, 1600)),
      ),
    );
    final messages = tester.element(find.byType(CommandCatalogView)).messages;

    await tester.enterText(find.byType(TextField), 'activate');
    await tester.pump();
    expect(find.text(messages.keyboardCommandActivate), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'command palette');
    await tester.pump();
    expect(find.text('Ctrl+K'), findsOneWidget);
  });

  testWidgets('arrow navigation wraps and invokes the selected command', (
    tester,
  ) async {
    final snapshot = _Snapshot({
      AppCommandId.openShortcutHelp,
      AppCommandId.createTextEntry,
    });
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: CommandCatalogView(
            paletteMode: true,
            snapshot: snapshot,
            platform: TargetPlatform.windows,
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(800, 800)),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(snapshot.invoked, [AppCommandId.createTextEntry]);

    snapshot.invoked.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(snapshot.invoked, [AppCommandId.openShortcutHelp]);
  });

  testWidgets('empty palettes ignore movement and show localized feedback', (
    tester,
  ) async {
    final snapshot = _Snapshot({});
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: CommandCatalogView(
            paletteMode: true,
            snapshot: snapshot,
          ),
        ),
      ),
    );
    final messages = tester.element(find.byType(CommandCatalogView)).messages;

    expect(find.text(messages.commandPaletteNoResults), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(snapshot.invoked, isEmpty);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: CommandCatalogView(paletteMode: false)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'no-such-command');
    await tester.pump();
    expect(find.text(messages.keyboardShortcutsNoResults), findsOneWidget);
  });

  testWidgets('widget updates clamp selection to the new command set', (
    tester,
  ) async {
    var snapshot = _Snapshot({
      AppCommandId.openShortcutHelp,
      AppCommandId.createTextEntry,
    });
    late StateSetter update;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: CommandCatalogView(
                paletteMode: true,
                snapshot: snapshot,
              ),
            );
          },
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

    final updated = _Snapshot({AppCommandId.openShortcutHelp});
    update(() => snapshot = updated);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(updated.invoked, [AppCommandId.openShortcutHelp]);
  });
}

class _Snapshot implements AppCommandContextSnapshot {
  _Snapshot(this.available);

  final Set<AppCommandId> available;
  final List<AppCommandId> invoked = [];

  @override
  bool isAvailable(AppCommandId id) => available.contains(id);

  @override
  Future<bool> invoke(AppCommandId id) async {
    invoked.add(id);
    return true;
  }
}
