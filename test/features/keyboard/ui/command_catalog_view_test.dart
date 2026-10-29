import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/domain/palette_jump.dart';
import 'package:lotti/features/keyboard/ui/command_catalog_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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

  group('jumping by title', () {
    const chicks = PaletteJumpTarget(
      entityId: 'task-1',
      kind: PaletteJumpKind.task,
      title: 'Feed the chicks',
    );
    const pip = PaletteJumpTarget(
      entityId: 'person-1',
      kind: PaletteJumpKind.person,
      title: 'Pip',
    );

    Future<List<String>> pumpPalette(
      WidgetTester tester, {
      required PaletteJumpSearch search,
      Set<AppCommandId> available = const {},
      List<PaletteJumpTarget>? opened,
    }) async {
      final searched = <String>[];
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: CommandCatalogView(
              paletteMode: true,
              snapshot: _Snapshot(available),
              platform: TargetPlatform.windows,
              jumpSearch: (query) {
                searched.add(query);
                return search(query);
              },
              onJumpSelected: opened?.add,
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(800, 800)),
        ),
      );
      return searched;
    }

    Future<void> typeAndSettle(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(CommandCatalogView.jumpSearchDebounce);
      await tester.pump();
    }

    testWidgets('typing searches titles once it pauses, and lists them under '
        'Go to, below the commands, with their kind', (tester) async {
      final searched = await pumpPalette(
        tester,
        available: {AppCommandId.refresh},
        search: (_) async => [chicks],
      );
      final messages = tester.element(find.byType(CommandCatalogView)).messages;
      expect(
        find.text(messages.commandPaletteSearchEverythingHint),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 're');
      await tester.pump();
      expect(searched, isEmpty, reason: 'still typing');

      await tester.pump(CommandCatalogView.jumpSearchDebounce);
      await tester.pump();

      expect(searched, ['re']);
      expect(find.text(messages.commandPaletteGoTo), findsOneWidget);
      expect(find.text('Feed the chicks'), findsOneWidget);
      expect(find.text(messages.navTabTitleTasks), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Feed the chicks')).dy,
        greaterThan(
          tester.getTopLeft(find.text(messages.keyboardCommandRefresh)).dy,
        ),
      );
    });

    testWidgets('arrow keys run on from the commands into the titles, and '
        'Enter opens the selected one', (tester) async {
      final opened = <PaletteJumpTarget>[];
      await pumpPalette(
        tester,
        available: {AppCommandId.refresh},
        search: (_) async => [chicks, pip],
        opened: opened,
      );
      await typeAndSettle(tester, 're');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(opened, [pip]);
    });

    testWidgets('a tap opens a title', (tester) async {
      final opened = <PaletteJumpTarget>[];
      await pumpPalette(tester, search: (_) async => [chicks], opened: opened);
      await typeAndSettle(tester, 'chicks');

      await tester.tap(find.text('Feed the chicks'));
      await tester.pump();

      expect(opened, [chicks]);
    });

    testWidgets('near matches for a misspelling say so', (tester) async {
      await pumpPalette(
        tester,
        search: (_) async => [
          const PaletteJumpTarget(
            entityId: 'task-1',
            kind: PaletteJumpKind.task,
            title: 'Feed the chicks',
            fuzzy: true,
          ),
        ],
      );
      final messages = tester.element(find.byType(CommandCatalogView)).messages;

      await typeAndSettle(tester, 'chikcs');

      expect(find.text(messages.commandPaletteSimilarTitles), findsOneWidget);
      expect(find.text(messages.commandPaletteGoTo), findsNothing);
    });

    testWidgets('a single letter searches no titles and clears the last '
        'ones', (tester) async {
      final searched = await pumpPalette(tester, search: (_) async => [chicks]);
      await typeAndSettle(tester, 'ch');
      expect(find.text('Feed the chicks'), findsOneWidget);

      await typeAndSettle(tester, 'c');

      expect(searched, ['ch']);
      expect(find.text('Feed the chicks'), findsNothing);
    });

    testWidgets('an answer for an older query never replaces a newer '
        'one', (tester) async {
      final slow = Completer<List<PaletteJumpTarget>>();
      await pumpPalette(
        tester,
        search: (query) => query == 'chi' ? slow.future : Future.value([pip]),
      );

      await typeAndSettle(tester, 'chi');
      await typeAndSettle(tester, 'pip');
      slow.complete([chicks]);
      await tester.pump();

      expect(find.text('Pip'), findsOneWidget);
      expect(find.text('Feed the chicks'), findsNothing);
    });

    testWidgets('nothing matching, or a failed search, says nothing '
        'matches — once the search has answered', (tester) async {
      await pumpPalette(
        tester,
        search: (_) async => throw Exception('index closed'),
      );
      final messages = tester.element(find.byType(CommandCatalogView)).messages;

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(
        find.text(messages.commandPaletteNothingFound),
        findsNothing,
        reason: 'the title search is still pending',
      );

      await tester.pump(CommandCatalogView.jumpSearchDebounce);
      await tester.pump();
      expect(find.text(messages.commandPaletteNothingFound), findsOneWidget);
    });

    testWidgets('a result still listed after the next answer keeps its '
        'row', (tester) async {
      await pumpPalette(
        tester,
        search: (query) async => query == 'fe' ? [chicks] : [chicks, pip],
      );
      await typeAndSettle(tester, 'fe');
      final before = tester.element(find.text('Feed the chicks'));

      await typeAndSettle(tester, 'fee');

      expect(find.text('Pip'), findsOneWidget);
      expect(
        identical(tester.element(find.text('Feed the chicks')), before),
        isTrue,
        reason: 'the same element, updated in place',
      );
    });
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
