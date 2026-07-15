import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
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

  testWidgets('palette traversal follows the rendered category order', (
    tester,
  ) async {
    final snapshot = _Snapshot({
      AppCommandId.refresh,
      AppCommandId.focusSearch,
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
      ),
    );
    final messages = tester.element(find.byType(CommandCatalogView)).messages;

    DesignSystemListItem selectedRow() => tester.widget<DesignSystemListItem>(
      find.byWidgetPredicate(
        (widget) => widget is DesignSystemListItem && widget.selected,
      ),
    );

    expect(selectedRow().title, messages.keyboardCommandFocusSearch);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(snapshot.invoked, [AppCommandId.focusSearch]);

    snapshot.invoked.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selectedRow().title, messages.keyboardCommandRefresh);
    expect(snapshot.invoked, [AppCommandId.refresh]);
  });

  testWidgets('Home and End jump to the first and last palette commands', (
    tester,
  ) async {
    final snapshot = _Snapshot({
      AppCommandId.openShortcutHelp,
      AppCommandId.createTextEntry,
      AppCommandId.focusSearch,
      AppCommandId.refresh,
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
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(snapshot.invoked, [AppCommandId.refresh]);

    snapshot.invoked.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(snapshot.invoked, [AppCommandId.openShortcutHelp]);
  });

  testWidgets('help search matches the displayed shortcut notation', (
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

    await tester.enterText(find.byType(TextField), 'ctrl s');
    await tester.pump();

    expect(find.text(messages.saveButton), findsOneWidget);
    expect(find.text(messages.keyboardCommandRefresh), findsNothing);
  });

  testWidgets('keyboard selection remains visible in a short palette', (
    tester,
  ) async {
    final snapshot = _Snapshot(AppCommandId.values.toSet());
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: CommandCatalogView(
            paletteMode: true,
            snapshot: snapshot,
            platform: TargetPlatform.windows,
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(800, 320)),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();

    final selectedFinder = find.byWidgetPredicate(
      (widget) => widget is DesignSystemListItem && widget.selected,
    );
    final listRect = tester.getRect(find.byType(SingleChildScrollView));
    final selectedRect = tester.getRect(selectedFinder);
    expect(selectedRect.top, greaterThanOrEqualTo(listRect.top));
    expect(selectedRect.bottom, lessThanOrEqualTo(listRect.bottom));
  });

  testWidgets('pending selection scrolling tolerates widget disposal', (
    tester,
  ) async {
    final snapshot = _Snapshot(AppCommandId.values.toSet());
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: CommandCatalogView(
            paletteMode: true,
            snapshot: snapshot,
            platform: TargetPlatform.windows,
          ),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.end);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.sendKeyUpEvent(LogicalKeyboardKey.end);

    expect(tester.takeException(), isNull);
  });

  testWidgets('help supports Arrow, Page, Home, and End scrolling', (
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
        mediaQueryData: const MediaQueryData(size: Size(800, 320)),
      ),
    );

    final scrollableFinder = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    );
    ScrollPosition position() =>
        tester.state<ScrollableState>(scrollableFinder).position;

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(position().pixels, position().maxScrollExtent);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(position().pixels, position().minScrollExtent);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(position().pixels, greaterThan(position().minScrollExtent));

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();
    expect(position().pixels, position().minScrollExtent);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(position().pixels, greaterThan(position().minScrollExtent));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(position().pixels, position().minScrollExtent);
  });

  testWidgets('help rows stay readable without becoming actionable', (
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

    final row = tester.widget<DesignSystemListItem>(
      find.byKey(const ValueKey(AppCommandId.openShortcutHelp)),
    );
    expect(row.onTap, isNull);
    expect(row.forcedState, DesignSystemListItemVisualState.idle);
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
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
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
