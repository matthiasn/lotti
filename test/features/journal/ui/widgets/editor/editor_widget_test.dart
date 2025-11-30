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
import 'package:lotti/database/logging_db.dart';
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
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('EditorWidget', () {
    final mockTimeService = MockTimeService();

    setUpAll(() async {
      await getIt.reset();
      final mockUpdateNotifications = MockUpdateNotifications();
      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<VectorClockService>(MockVectorClockService())
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<TagsService>(TagsService())
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<EditorStateService>(EditorStateService());

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDownAll(() async {
      // Ensure databases are closed and service locator is reset
      if (getIt.isRegistered<LoggingDb>()) {
        await getIt<LoggingDb>().close();
      }
      if (getIt.isRegistered<JournalDb>()) {
        await getIt<JournalDb>().close();
      }
      if (getIt.isRegistered<EditorDb>()) {
        await getIt<EditorDb>().close();
      }
      await getIt.reset();
    });

    testWidgets('editor toolbar is invisible without autofocus',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EditorWidget(entryId: testTextEntry.meta.id),
        ),
      );

      await tester.pumpAndSettle();

      final boldIconFinder = find.byIcon(Icons.format_bold);
      expect(boldIconFinder, findsNothing);
    });

    testWidgets('disables clipping when toolbar is hidden',
        (WidgetTester tester) async {
      const entryId = 'toolbar-hidden';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: false,
        ),
      );

      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.clipBehavior, equals(Clip.none));

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      expect(quillEditor.config.padding, EdgeInsets.zero);
    });

    testWidgets('restores clipping when toolbar is visible',
        (WidgetTester tester) async {
      const entryId = 'toolbar-visible';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: true,
        ),
      );

      await tester.pumpAndSettle();

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.clipBehavior, equals(Clip.hardEdge));

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      expect(
        quillEditor.config.padding,
        const EdgeInsets.only(top: 5, bottom: 15, left: 10, right: 10),
      );
    });

    testWidgets('divider toolbar button inserts divider embed',
        (WidgetTester tester) async {
      const entryId = 'toolbar-divider';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: true,
        ),
      );

      await tester.pumpAndSettle();

      final dividerButton = find.byIcon(Icons.horizontal_rule);
      expect(dividerButton, findsOneWidget);

      await tester.tap(dividerButton);
      await tester.pumpAndSettle();

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final operations = quillEditor.controller.document.toDelta().toList();
      expect(operations.first.data, equals({'divider': 'hr'}));
      expect(operations[1].value, equals('\n'));
    });

    testWidgets('configures embed builders and unknown fallback',
        (WidgetTester tester) async {
      const entryId = 'embed-config';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: false,
        ),
      );

      await tester.pumpAndSettle();

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final builders = quillEditor.config.embedBuilders;

      expect(builders, isNotNull);
      expect(
          builders!.any((builder) => builder is DividerEmbedBuilder), isTrue);
      expect(
          quillEditor.config.unknownEmbedBuilder, isA<UnknownEmbedBuilder>());
    });

    testWidgets('configures custom context menu builder',
        (WidgetTester tester) async {
      const entryId = 'context-menu';

      await tester.pumpWidget(
        buildEditorTestWidget(
          entryId: entryId,
          showToolbar: false,
        ),
      );

      await tester.pumpAndSettle();

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));

      // Verify context menu builder is configured
      expect(quillEditor.config.contextMenuBuilder, isNotNull);
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

  group('showDictionaryResultSnackbar', () {
    late AppLocalizations messages;

    setUpAll(() async {
      messages = await AppLocalizations.delegate.load(const Locale('en'));
    });

    testWidgets('shows snackbar for success result', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDictionaryResultSnackbar(
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
      await tester.pumpAndSettle();

      expect(find.text(messages.addToDictionarySuccess), findsOneWidget);
    });

    testWidgets('shows snackbar for noCategory result', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDictionaryResultSnackbar(
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
      await tester.pumpAndSettle();

      expect(find.text(messages.addToDictionaryNoCategory), findsOneWidget);
    });

    testWidgets('returns false and shows no snackbar for silent results',
        (tester) async {
      late bool showResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showResult = showDictionaryResultSnackbar(
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
      await tester.pumpAndSettle();

      expect(showResult, isFalse);
      // No snackbar should be shown
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('returns true when snackbar is shown', (tester) async {
      late bool showResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showResult = showDictionaryResultSnackbar(
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
      await tester.pumpAndSettle();

      expect(showResult, isTrue);
      expect(find.text(messages.addToDictionaryDuplicate), findsOneWidget);
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
}) {
  return ProviderScope(
    overrides: [
      entryControllerProvider(id: entryId).overrideWith(
        () => _TestEntryController(showToolbar: showToolbar),
      ),
    ],
    child: MediaQuery(
      data: const MediaQueryData(),
      child: MaterialApp(
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
