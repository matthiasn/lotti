import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/journal/ui/widgets/editor/embed_builders.dart';
import 'package:lotti/features/speech/services/speech_dictionary_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import 'editor_widget_test_helpers.dart';

void main() {
  // One shared heavy setup for the whole file: both widget-test groups
  // (EditorWidget and the context-menu group) need the identical GetIt
  // wiring with in-memory JournalDb/EditorDb — open them once.
  final mockTimeService = MockTimeService();

  setUpAll(() async {
    registerAllFallbackValues();

    final mockUpdateNotifications = MockUpdateNotifications();
    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );
    when(
      mockTimeService.getStream,
    ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
          ..registerSingleton<VectorClockService>(MockVectorClockService())
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
          ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<TimeService>(mockTimeService)
          ..registerSingleton<EditorStateService>(EditorStateService());
      },
    );
  });

  tearDownAll(() async {
    // Ensure databases are closed and service locator is reset
    if (getIt.isRegistered<JournalDb>()) {
      await getIt<JournalDb>().close();
    }
    if (getIt.isRegistered<EditorDb>()) {
      await getIt<EditorDb>().close();
    }
    await getIt.reset();
  });

  group('EditorWidget', () {
    testWidgets('editor toolbar is invisible without autofocus', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: 'toolbar-invisible-no-autofocus',
          showToolbar: false,
        ),
      );

      await tester.pump(const Duration(milliseconds: 450));

      final boldIconFinder = find.byIcon(Icons.format_bold);
      expect(boldIconFinder, findsNothing);
    });

    testWidgets('disables clipping when toolbar is hidden', (
      WidgetTester tester,
    ) async {
      const entryId = 'toolbar-hidden';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: false,
        ),
      );

      await tester.pump(const Duration(milliseconds: 450));

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.clipBehavior, equals(Clip.none));

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      expect(quillEditor.config.padding, EdgeInsets.zero);
    });

    testWidgets('restores clipping when toolbar is visible', (
      WidgetTester tester,
    ) async {
      const entryId = 'toolbar-visible';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: true,
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.clipBehavior, equals(Clip.hardEdge));

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      expect(
        quillEditor.config.padding,
        const EdgeInsets.only(top: 5, bottom: 15, left: 10, right: 10),
      );
    });

    testWidgets('divider toolbar button inserts divider embed', (
      WidgetTester tester,
    ) async {
      const entryId = 'toolbar-divider';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: true,
        ),
      );

      // The toolbar build chain must fully settle before the buttons are
      // hit-testable.
      await tester.pumpAndSettle();

      // At this (narrow) width the divider lives behind the "…" overflow, not
      // inline; open the sheet first.
      expect(find.byIcon(Icons.horizontal_rule), findsNothing);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      final dividerButton = find.byIcon(Icons.horizontal_rule);
      expect(dividerButton, findsOneWidget);

      await tester.tap(dividerButton);
      // The Quill toolbar routes the tap through animations that need to
      // fully drain before the document mutation lands.
      await tester.pumpAndSettle();

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final operations = quillEditor.controller.document.toDelta().toList();
      expect(operations.first.data, equals({'divider': 'hr'}));
      expect(operations[1].value, equals('\n'));
    });

    testWidgets('wires the UnknownEmbedBuilder fallback for unknown embeds', (
      WidgetTester tester,
    ) async {
      const entryId = 'embed-config';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: false,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // EditorWidget must wire the project's UnknownEmbedBuilder as the
      // catch-all for embed types it does not explicitly support — that is the
      // contract this test pins. The fallback's actual rendering (the warning
      // glyph + "Unsupported content (<type>)" label) is exercised
      // behaviourally in embed_builders_test.dart; driving a live custom
      // BlockEmbed through QuillEditor here is brittle (block-embed insertion
      // does not reliably lay out via a single pump), so we assert the wiring
      // of the specific fallback builder type instead of re-rendering it.
      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      expect(
        quillEditor.config.unknownEmbedBuilder,
        isA<UnknownEmbedBuilder>(),
      );
    });

    testWidgets('configures custom context menu builder', (
      WidgetTester tester,
    ) async {
      const entryId = 'context-menu';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: false,
        ),
      );

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));

      // Verify context menu builder is configured
      expect(quillEditor.config.contextMenuBuilder, isNotNull);
    });

    testWidgets('uses persistent ScrollController across rebuilds', (
      WidgetTester tester,
    ) async {
      const entryId = 'scroll-controller-test';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Get the first ScrollController reference
      final quillEditor1 = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final scrollController1 = quillEditor1.scrollController;
      expect(scrollController1, isNotNull);

      // Trigger a rebuild by changing showToolbar
      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Get the new ScrollController reference - should be the same instance
      final quillEditor2 = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final scrollController2 = quillEditor2.scrollController;

      // The scroll controller should be the same instance (not recreated)
      expect(scrollController2, same(scrollController1));
    });

    testWidgets('disposes ScrollController when widget is removed', (
      WidgetTester tester,
    ) async {
      const entryId = 'scroll-controller-dispose';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Get the ScrollController reference before disposal
      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final scrollController = quillEditor.scrollController;
      expect(scrollController, isNotNull);

      // Remove the widget from the tree
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 450));

      // The widget should be removed without errors
      // (dispose was called properly)
      expect(find.byType(EditorWidget), findsNothing);
      // The real contract: removal disposed the ScrollController without
      // throwing (a double-dispose or use-after-dispose would surface here).
      expect(tester.takeException(), isNull);
    });

    // The optional `margin` constructor parameter is forwarded verbatim to the
    // outer Card. Default (null) and an explicit value share one flow so the
    // forwarding contract is asserted without copy-pasted permutations.
    for (final margin in <EdgeInsets?>[
      null,
      const EdgeInsets.all(12),
    ]) {
      testWidgets('forwards margin=$margin to the Card', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          buildEditorTestWidget(
            entryId: 'margin-${margin == null ? 'null' : 'set'}',
            showToolbar: false,
            margin: margin,
          ),
        );
        await tester.pump(const Duration(milliseconds: 450));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.margin, margin);
      });
    }
  });

  group('getSelectedText', () {
    test('returns empty string when selection is collapsed', () {
      final controller = QuillController.basic();
      // Insert some text
      controller.document.insert(0, 'Hello World');
      // Move cursor to position 5 (collapsed selection)
      controller.updateSelection(
        const TextSelection.collapsed(offset: 5),
        ChangeSource.local,
      );

      final result = getSelectedText(controller);
      expect(result, isEmpty);
    });

    test('returns selected text when selection is not collapsed', () {
      final controller = QuillController.basic();
      // Insert some text
      controller.document.insert(0, 'Hello World');
      // Select "World" (positions 6-11)
      controller.updateSelection(
        const TextSelection(baseOffset: 6, extentOffset: 11),
        ChangeSource.local,
      );

      final result = getSelectedText(controller);
      expect(result, equals('World'));
    });

    test('returns correct text for partial selection', () {
      final controller = QuillController.basic();
      controller.document.insert(0, 'Testing selection functionality');
      // Select "selection" (positions 8-17)
      controller.updateSelection(
        const TextSelection(baseOffset: 8, extentOffset: 17),
        ChangeSource.local,
      );

      final result = getSelectedText(controller);
      expect(result, equals('selection'));
    });

    test('returns empty string for empty document', () {
      final controller = QuillController.basic();

      final result = getSelectedText(controller);
      expect(result, isEmpty);
    });
  });

  group('showDictionaryResultToast', () {
    late AppLocalizations messages;

    setUpAll(() async {
      messages = await AppLocalizations.delegate.load(const Locale('en'));
    });

    testWidgets('shows snackbar for success result', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: resolveTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDictionaryResultToast(
                      context,
                      SpeechDictionaryResult.success,
                      messages,
                    );
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text(messages.addToDictionarySuccess), findsOneWidget);
    });

    testWidgets('shows snackbar for noCategory result', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: resolveTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDictionaryResultToast(
                      context,
                      SpeechDictionaryResult.noCategory,
                      messages,
                    );
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text(messages.addToDictionaryNoCategory), findsOneWidget);
    });

    testWidgets('returns false and shows no snackbar for silent results', (
      tester,
    ) async {
      late bool showResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: resolveTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showResult = showDictionaryResultToast(
                      context,
                      SpeechDictionaryResult.emptyTerm,
                      messages,
                    );
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump(const Duration(milliseconds: 450));

      expect(showResult, isFalse);
      // No snackbar should be shown
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('returns true when snackbar is shown', (tester) async {
      late bool showResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: resolveTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showResult = showDictionaryResultToast(
                      context,
                      SpeechDictionaryResult.duplicate,
                      messages,
                    );
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump(const Duration(milliseconds: 450));

      expect(showResult, isTrue);
      expect(find.text(messages.addToDictionaryDuplicate), findsOneWidget);
    });

    Future<void> pumpResult(
      WidgetTester tester,
      SpeechDictionaryResult result,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: resolveTestTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDictionaryResultToast(context, result, messages);
                  },
                  child: const Text('Test'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Test'));
      await tester.pump(const Duration(milliseconds: 450));
    }

    testWidgets('maps saveFailed to the error tone', (tester) async {
      await pumpResult(tester, SpeechDictionaryResult.saveFailed);

      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.error);
      expect(toast.title, messages.addToDictionarySaveFailed);
    });

    testWidgets('maps termTooLong to the warning tone', (tester) async {
      await pumpResult(tester, SpeechDictionaryResult.termTooLong);

      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.warning);
      expect(toast.title, messages.addToDictionaryTooLong);
    });
  });
}
