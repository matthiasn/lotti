import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
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
