import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_button.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';

import 'tutorial/tutorial_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TutorialAppHarness harness;

  setUp(() async {
    final previousWarnings = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () =>
          driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarnings,
    );
    harness = await TutorialAppHarness.setUp(
      aiConfigs: const [],
      languageCode: 'en',
      seedDemoWorld: false,
      inMemoryJournal: false,
      now: DateTime(2024, 6, 10, 12),
    );
  });
  tearDown(() async => harness.dispose());

  testWidgets('create, save and reopen a note backed by an isolated journal', (
    tester,
  ) async {
    final fatalHitTests = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(
      () => WidgetController.hitTestWarningShouldBeFatal = fatalHitTests,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.providerOverrides(),
        child: MyBeamerApp(
          navService: harness.navService,
          userActivityService: harness.userActivityService,
        ),
      ),
    );
    harness.navService.beamToNamed('/journal');
    await _pumpUntil(tester, find.byType(FloatingAddActionButton));
    await tester.tap(find.byType(FloatingAddActionButton).first);
    await _pumpUntil(tester, find.byIcon(LottiIcons.note));
    await tester.tap(find.byIcon(LottiIcons.note).first);
    await _pumpUntil(tester, find.byType(QuillEditor));

    const text = 'Penguin dispatch: the icebreaker leaves at noon.';
    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor).first);
    editor.controller.replaceText(
      0,
      0,
      text,
      const TextSelection.collapsed(offset: text.length),
    );
    editor.focusNode.requestFocus();
    await tester.pump();
    await _pumpUntil(tester, find.byIcon(LottiIcons.save));
    final entryId = tester
        .widget<EditorWidget>(find.byType(EditorWidget).first)
        .entryId;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuillEditor).first),
    );
    bool isSaved() =>
        container
            .read(entryControllerProvider(entryId))
            .value
            ?.maybeMap(
              saved: (_) => true,
              orElse: () => false,
            ) ??
        false;
    expect(
      isSaved(),
      isFalse,
      reason: 'Text insertion must create a dirty draft',
    );
    final saveButton = find.byIcon(LottiIcons.save).first;
    await tester.ensureVisible(saveButton);
    await _pumpUntil(tester, saveButton.hitTestable());
    await tester.tap(saveButton);
    for (var frame = 0; frame < 100 && !isSaved(); frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(isSaved(), isTrue, reason: 'Save must complete before reading disk');

    // Await real SQLite/file work outside the widget test's fake clock.
    final saved = await tester.runAsync(() async {
      final rows = await harness.journalDb
          .customSelect(
            "SELECT id FROM journal WHERE type = 'JournalEntry'",
          )
          .get();
      expect(rows, hasLength(1));
      final id = rows.single.read<String>('id');
      // A second connection proves the write reached disk, not just a draft
      // in the editor controller or the first connection's state.
      final reopened = JournalDb(
        documentsDirectoryProvider: () async => harness.documentsDirectory,
        background: false,
        readPool: 0,
      );
      try {
        final entry = await reopened.journalEntityById(id);
        expect(entry?.entryText?.plainText.trim(), text);
        return entry!;
      } finally {
        await reopened.close();
      }
    });
    expect(saved, isNotNull);

    harness.navService.beamToNamed('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(QuillEditor), findsNothing);
    harness.navService.beamToNamed('/journal/${saved!.meta.id}');
    await _pumpUntil(tester, find.byType(QuillEditor));
    final reloaded = tester.widget<QuillEditor>(find.byType(QuillEditor).first);
    expect(reloaded.controller.document.toPlainText().trim(), text);
    expect(identical(reloaded.controller, editor.controller), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var frame = 0; frame < 100 && finder.evaluate().isEmpty; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets, reason: 'Expected UI transition to complete');
}
