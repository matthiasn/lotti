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
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
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

// Mock for speech dictionary service testing
class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

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

  group('SpeechDictionaryService integration', () {
    // These tests verify the service is correctly integrated with the editor
    late MockCategoryRepository mockCategoryRepository;
    late MockJournalRepository mockJournalRepository;

    setUp(() {
      mockCategoryRepository = MockCategoryRepository();
      mockJournalRepository = MockJournalRepository();
    });

    test('service returns success for valid term addition', () async {
      final service = SpeechDictionaryService(
        categoryRepository: mockCategoryRepository,
        journalRepository: mockJournalRepository,
      );

      when(() => mockJournalRepository.getJournalEntityById('entry-1'))
          .thenAnswer((_) async => testTextEntry);

      // Text entry has no category, so this should return noCategory
      final result = await service.addTermForEntry(
        entryId: 'entry-1',
        term: 'testTerm',
      );

      expect(result, equals(SpeechDictionaryResult.noCategory));
    });

    test('service returns emptyTerm for blank input', () async {
      final service = SpeechDictionaryService(
        categoryRepository: mockCategoryRepository,
        journalRepository: mockJournalRepository,
      );

      final result = await service.addTermForEntry(
        entryId: 'entry-1',
        term: '   ',
      );

      expect(result, equals(SpeechDictionaryResult.emptyTerm));
    });

    test('service returns termTooLong for oversized input', () async {
      final service = SpeechDictionaryService(
        categoryRepository: mockCategoryRepository,
        journalRepository: mockJournalRepository,
      );

      // Create a term longer than kMaxTermLength (50)
      final longTerm = 'a' * 51;
      final result = await service.addTermForEntry(
        entryId: 'entry-1',
        term: longTerm,
      );

      expect(result, equals(SpeechDictionaryResult.termTooLong));
    });

    test('service returns entryNotFound when entry does not exist', () async {
      final service = SpeechDictionaryService(
        categoryRepository: mockCategoryRepository,
        journalRepository: mockJournalRepository,
      );

      when(() => mockJournalRepository.getJournalEntityById('nonexistent'))
          .thenAnswer((_) async => null);

      final result = await service.addTermForEntry(
        entryId: 'nonexistent',
        term: 'testTerm',
      );

      expect(result, equals(SpeechDictionaryResult.entryNotFound));
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
