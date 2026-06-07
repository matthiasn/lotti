import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
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

      // The toolbar build chain must fully settle before the divider
      // button is hit-testable.
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

    testWidgets('configures embed builders and unknown fallback', (
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

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final builders = quillEditor.config.embedBuilders;

      expect(builders, isNotNull);
      expect(
        builders!.any((builder) => builder is DividerEmbedBuilder),
        isTrue,
      );
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

  group('getDictionaryResultMessage', () {
    late AppLocalizations messages;

    setUpAll(() async {
      // Load English localizations for testing
      messages = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('returns success message for success result', () {
      final message = getDictionaryResultMessage(
        SpeechDictionaryResult.success,
        messages,
      );
      expect(message, equals(messages.addToDictionarySuccess));
      expect(message, isNotNull);
    });

    test('returns noCategory message for noCategory result', () {
      final message = getDictionaryResultMessage(
        SpeechDictionaryResult.noCategory,
        messages,
      );
      expect(message, equals(messages.addToDictionaryNoCategory));
      expect(message, isNotNull);
    });

    test('returns duplicate message for duplicate result', () {
      final message = getDictionaryResultMessage(
        SpeechDictionaryResult.duplicate,
        messages,
      );
      expect(message, equals(messages.addToDictionaryDuplicate));
      expect(message, isNotNull);
    });

    test('returns termTooLong message for termTooLong result', () {
      final message = getDictionaryResultMessage(
        SpeechDictionaryResult.termTooLong,
        messages,
      );
      expect(message, equals(messages.addToDictionaryTooLong));
      expect(message, isNotNull);
    });

    test('returns saveFailed message for saveFailed result', () {
      final message = getDictionaryResultMessage(
        SpeechDictionaryResult.saveFailed,
        messages,
      );
      expect(message, equals(messages.addToDictionarySaveFailed));
      expect(message, isNotNull);
    });

    test('returns null for emptyTerm result (silent)', () {
      final message = getDictionaryResultMessage(
        SpeechDictionaryResult.emptyTerm,
        messages,
      );
      expect(message, isNull);
    });

    test('returns null for entryNotFound result (silent)', () {
      final message = getDictionaryResultMessage(
        SpeechDictionaryResult.entryNotFound,
        messages,
      );
      expect(message, isNull);
    });

    test('returns null for categoryNotFound result (silent)', () {
      final message = getDictionaryResultMessage(
        SpeechDictionaryResult.categoryNotFound,
        messages,
      );
      expect(message, isNull);
    });

    test('covers all SpeechDictionaryResult enum values', () {
      // Ensure every enum value is handled
      for (final result in SpeechDictionaryResult.values) {
        // Should not throw - all cases are handled
        final message = getDictionaryResultMessage(result, messages);

        // Verify expected nullability based on result type
        if (result == SpeechDictionaryResult.emptyTerm ||
            result == SpeechDictionaryResult.entryNotFound ||
            result == SpeechDictionaryResult.categoryNotFound) {
          expect(message, isNull, reason: '$result should be silent');
        } else {
          expect(message, isNotNull, reason: '$result should have a message');
        }
      }
    });
  });

  group('_buildContextMenu / contextMenuBuilder', () {
    late AppLocalizations messages;

    setUpAll(() async {
      // GetIt + in-memory DBs come from the file-level setUpAll.
      messages = await AppLocalizations.delegate.load(const Locale('en'));
    });

    testWidgets(
      'contextMenuBuilder returns toolbar without dictionary button '
      'when no text is selected',
      (tester) async {
        const entryId = 'ctx-menu-no-selection';

        await tester.pumpWidget(
          buildEditorTestWidget(entryId: entryId, showToolbar: false),
        );
        await tester.pump(const Duration(milliseconds: 450));

        final quillEditor = tester.widget<QuillEditor>(
          find.byType(QuillEditor),
        );
        final contextMenuBuilder = quillEditor.config.contextMenuBuilder;
        expect(contextMenuBuilder, isNotNull);

        // Obtain a real QuillRawEditorState from the widget tree.
        final rawEditorState = tester.state<QuillRawEditorState>(
          find.byType(QuillRawEditor),
        );

        // Pump a standalone widget that calls the context-menu builder so the
        // builder code is exercised and we can assert on its output.
        late Widget builtMenu;
        await tester.pumpWidget(
          buildEditorTestWidget(entryId: entryId, showToolbar: false),
        );
        await tester.pump(const Duration(milliseconds: 450));

        // Re-acquire the state after re-pump.
        final freshState = tester.state<QuillRawEditorState>(
          find.byType(QuillRawEditor),
        );
        final freshEditor = tester.widget<QuillEditor>(
          find.byType(QuillEditor),
        );
        builtMenu = freshEditor.config.contextMenuBuilder!(
          tester.element(find.byType(QuillEditor)),
          freshState,
        );

        // The menu should be an AdaptiveTextSelectionToolbar (no dict button
        // because nothing is selected).
        expect(builtMenu, isA<AdaptiveTextSelectionToolbar>());
        // The controller has no selection — there should be no dictionary
        // button item in the returned widget.
        final toolbar = builtMenu as AdaptiveTextSelectionToolbar;
        final buttonItems = toolbar.buttonItems ?? [];
        final hasDictButton = buttonItems.any(
          (item) => item.label == messages.addToDictionary,
        );
        expect(hasDictButton, isFalse);

        // Suppress unused variable hint from the first state acquisition.
        expect(rawEditorState, isNotNull);
      },
    );

    testWidgets(
      'contextMenuBuilder includes "Add to Dictionary" button '
      'when text is selected',
      (tester) async {
        const entryId = 'ctx-menu-with-selection';

        await tester.pumpWidget(
          buildEditorTestWidget(entryId: entryId, showToolbar: false),
        );
        await tester.pump(const Duration(milliseconds: 450));

        final quillEditor = tester.widget<QuillEditor>(
          find.byType(QuillEditor),
        );
        // Select text in the controller so trimmedText is non-empty.
        quillEditor.controller.document.insert(0, 'Hello World');
        quillEditor.controller.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 5),
          ChangeSource.local,
        );
        await tester.pump();

        final freshEditor = tester.widget<QuillEditor>(
          find.byType(QuillEditor),
        );
        final rawEditorState = tester.state<QuillRawEditorState>(
          find.byType(QuillRawEditor),
        );

        final builtMenu = freshEditor.config.contextMenuBuilder!(
          tester.element(find.byType(QuillEditor)),
          rawEditorState,
        );

        expect(builtMenu, isA<AdaptiveTextSelectionToolbar>());
        final toolbar = builtMenu as AdaptiveTextSelectionToolbar;
        final buttonItems = toolbar.buttonItems ?? [];
        final hasDictButton = buttonItems.any(
          (item) => item.label == messages.addToDictionary,
        );
        expect(hasDictButton, isTrue);
      },
    );

    /// Drives the full context-menu add-to-dictionary flow for [result]:
    /// selects 'Hello', presses the dictionary button, and asserts the
    /// expected toast (or its absence for silent results).
    Future<void> runAddToDictionaryCase(
      WidgetTester tester, {
      required SpeechDictionaryResult result,
      required String? Function(AppLocalizations messages) expectedToast,
    }) async {
      final entryId = 'ctx-menu-add-dict-${result.name}';
      final mockDictionaryService = MockSpeechDictionaryService();
      when(
        () => mockDictionaryService.addTermForEntry(
          entryId: any(named: 'entryId'),
          term: any(named: 'term'),
        ),
      ).thenAnswer((_) async => result);

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: false,
          speechDictionaryServiceOverride: mockDictionaryService,
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      quillEditor.controller.document.insert(0, 'Hello World');
      quillEditor.controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      );
      await tester.pump();

      final freshEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final rawEditorState = tester.state<QuillRawEditorState>(
        find.byType(QuillRawEditor),
      );
      final toolbar =
          freshEditor.config.contextMenuBuilder!(
                tester.element(find.byType(QuillEditor)),
                rawEditorState,
              )
              as AdaptiveTextSelectionToolbar;
      final dictionaryButtonItem = (toolbar.buttonItems ?? []).firstWhere(
        (item) => item.label == messages.addToDictionary,
      );

      dictionaryButtonItem.onPressed?.call();
      await tester.pump(const Duration(milliseconds: 450));

      verify(
        () => mockDictionaryService.addTermForEntry(
          entryId: entryId,
          term: 'Hello',
        ),
      ).called(1);

      final toast = expectedToast(messages);
      if (toast == null) {
        // Silent result — no toast rendered.
        expect(find.byType(DesignSystemToast), findsNothing);
      } else {
        expect(find.text(toast), findsOneWidget);
      }
    }

    // Every message-producing result shows its toast; silent results
    // (emptyTerm) show nothing — one parameterized flow per case.
    for (final (result, expectedToast)
        in <(SpeechDictionaryResult, String? Function(AppLocalizations))>[
          (SpeechDictionaryResult.success, (m) => m.addToDictionarySuccess),
          (
            SpeechDictionaryResult.noCategory,
            (m) => m.addToDictionaryNoCategory,
          ),
          (SpeechDictionaryResult.duplicate, (m) => m.addToDictionaryDuplicate),
          (SpeechDictionaryResult.termTooLong, (m) => m.addToDictionaryTooLong),
          (
            SpeechDictionaryResult.saveFailed,
            (m) => m.addToDictionarySaveFailed,
          ),
          (SpeechDictionaryResult.emptyTerm, (m) => null),
        ]) {
      testWidgets(
        '_addToDictionary handles ${result.name} via the context menu',
        (tester) async {
          await runAddToDictionaryCase(
            tester,
            result: result,
            expectedToast: expectedToast,
          );
        },
      );
    }
  });
}

class _TestEntryController extends EntryController {
  _TestEntryController({required this.showToolbar});

  final bool showToolbar;

  @override
  Future<EntryState?> build({required String id}) async {
    controller = QuillController.basic();
    return EntryState.saved(
      entryId: id,
      entry: null,
      showMap: false,
      isFocused: showToolbar,
      shouldShowEditorToolBar: showToolbar,
      formKey: formKey,
    );
  }
}

Widget buildEditorTestWidget({
  required String entryId,
  required bool showToolbar,
  SpeechDictionaryService? speechDictionaryServiceOverride,
}) {
  return ProviderScope(
    overrides: [
      entryControllerProvider(id: entryId).overrideWith(
        () => _TestEntryController(showToolbar: showToolbar),
      ),
      if (speechDictionaryServiceOverride != null)
        speechDictionaryServiceProvider.overrideWithValue(
          speechDictionaryServiceOverride,
        ),
    ],
    child: MediaQuery(
      data: const MediaQueryData(),
      child: MaterialApp(
        theme: resolveTestTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FormBuilderLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 800,
                maxWidth: 800,
              ),
              child: EditorWidget(entryId: entryId),
            ),
          ),
        ),
      ),
    ),
  );
}
