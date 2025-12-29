import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_action_items.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/tasks/ui/labels/label_selection_modal_content.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../mocks/mocks.dart';
import '../../../../../../test_data/test_data.dart';

class _TestEntryController extends EntryController {
  _TestEntryController(this.entry);

  final JournalEntity entry;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

class _MockLabelsRepository extends Mock implements LabelsRepository {}

JournalEntity textEntryWithLabels(List<String> labelIds) {
  final now = DateTime(2023);
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: 'entry-123',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: labelIds,
    ),
  );
}

JournalEntity taskWithLabels(List<String> labelIds) {
  final now = DateTime(2023);
  return JournalEntity.task(
    meta: Metadata(
      id: 'task-123',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: labelIds,
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-1',
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: [],
      title: 'Sample task',
    ),
  );
}

void main() {
  late MockEntitiesCacheService cacheService;
  late MockEditorStateService editorStateService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late _MockLabelsRepository repository;

  setUpAll(() {
    registerFallbackValue(testLabelDefinition1);
  });

  setUp(() async {
    cacheService = MockEntitiesCacheService();
    editorStateService = MockEditorStateService();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    repository = _MockLabelsRepository();

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications);

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(
      () => cacheService.filterLabelsForCategory(any(), any()),
    ).thenAnswer(
      (invocation) =>
          invocation.positionalArguments.first as List<LabelDefinition>,
    );
    when(() => cacheService.getLabelById(testLabelDefinition1.id))
        .thenReturn(testLabelDefinition1);
    when(() => cacheService.getLabelById(testLabelDefinition2.id))
        .thenReturn(testLabelDefinition2);
    when(() => cacheService.sortedLabels)
        .thenReturn([testLabelDefinition1, testLabelDefinition2]);
  });

  tearDown(() async {
    await getIt.reset();
  });

  /// Builds a widget tree that properly handles the Navigator.pop() call
  /// that ModernLabelsItem makes when opening the labels modal.
  ProviderScope buildWrapper(JournalEntity entry) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(id: entry.id).overrideWith(
          () => _TestEntryController(entry),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(
            [testLabelDefinition1, testLabelDefinition2],
          ),
        ),
        labelsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  // Simulate opening a modal that contains ModernLabelsItem
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) => Dialog(
                      child: SingleChildScrollView(
                        child: ModernLabelsItem(entryId: entry.id),
                      ),
                    ),
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Simple wrapper for testing widget visibility only (no modal interaction)
  ProviderScope buildSimpleWrapper(JournalEntity entry) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(id: entry.id).overrideWith(
          () => _TestEntryController(entry),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(
            [testLabelDefinition1, testLabelDefinition2],
          ),
        ),
        labelsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ModernLabelsItem(entryId: entry.id),
            ),
          ),
        ),
      ),
    );
  }

  group('ModernLabelsItem visibility', () {
    testWidgets('shows for non-task entries', (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(buildSimpleWrapper(entry));
      await tester.pumpAndSettle();

      expect(find.text('Labels'), findsOneWidget);
    });

    testWidgets('is hidden for Task entries', (tester) async {
      final task = taskWithLabels(const []);

      await tester.pumpWidget(buildSimpleWrapper(task));
      await tester.pumpAndSettle();

      expect(find.text('Labels'), findsNothing);
    });

    testWidgets('shows subtitle text', (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(buildSimpleWrapper(entry));
      await tester.pumpAndSettle();

      expect(
        find.text('Assign labels to organize this entry'),
        findsOneWidget,
      );
    });

    testWidgets('shows label icon', (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(buildSimpleWrapper(entry));
      await tester.pumpAndSettle();

      // ModernModalActionItem uses the provided icon
      expect(find.byType(Icon), findsWidgets);
    });
  });

  group('Labels modal opening', () {
    testWidgets('tapping opens labels modal', (tester) async {
      final entry = textEntryWithLabels(['label-1']);
      when(
        () => repository.setLabels(
          journalEntityId: any(named: 'journalEntityId'),
          labelIds: any(named: 'labelIds'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      // First open the dialog containing ModernLabelsItem
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Now tap the Labels item inside the dialog
      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      // Modal should be open with Apply button
      expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
    });

    testWidgets('modal shows search bar', (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      // Search field should be visible in the modal
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('passes entry categoryId to selector', (tester) async {
      final entry = textEntryWithLabels(const []).copyWith(
        meta: textEntryWithLabels(const []).meta.copyWith(categoryId: 'work'),
      );

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      final content = tester.widget<LabelSelectionModalContent>(
        find.byType(LabelSelectionModalContent),
      );
      expect(content.categoryId, equals('work'));
    });

    testWidgets('passes null categoryId when entry has none', (tester) async {
      final entry = textEntryWithLabels(const []).copyWith(
        meta: textEntryWithLabels(const []).meta.copyWith(categoryId: null),
      );

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      final content = tester.widget<LabelSelectionModalContent>(
        find.byType(LabelSelectionModalContent),
      );
      expect(content.categoryId, isNull);
    });
  });

  group('Modal actions', () {
    testWidgets('modal shows cancel button', (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      // Cancel button should be visible
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('apply button saves labels and closes modal', (tester) async {
      final entry = textEntryWithLabels(const []);
      when(
        () => repository.setLabels(
          journalEntityId: any(named: 'journalEntityId'),
          labelIds: any(named: 'labelIds'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      // Select a label
      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();

      // Apply changes
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      // Verify repository was called
      verify(
        () => repository.setLabels(
          journalEntityId: 'entry-123',
          labelIds: any(named: 'labelIds'),
        ),
      ).called(1);

      // Modal should be closed
      expect(find.widgetWithText(FilledButton, 'Apply'), findsNothing);
    });

    testWidgets('shows error snackbar when apply fails', (tester) async {
      final entry = textEntryWithLabels(const []);
      when(
        () => repository.setLabels(
          journalEntityId: any(named: 'journalEntityId'),
          labelIds: any(named: 'labelIds'),
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      // Error snackbar should be shown
      expect(find.text('Failed to update labels'), findsWidgets);
      // Modal should still be open
      expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
    });
  });

  group('Search functionality', () {
    testWidgets('search filters labels', (tester) async {
      final entry = textEntryWithLabels(const []);
      when(
        () => repository.setLabels(
          journalEntityId: any(named: 'journalEntityId'),
          labelIds: any(named: 'labelIds'),
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      // Enter search text
      final searchField = find.descendant(
        of: find.byType(TextField),
        matching: find.byType(EditableText),
      );
      await tester.enterText(searchField, 'Urgent');
      await tester.pumpAndSettle();

      // Only one CheckboxListTile should be visible
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('clearing search shows all labels', (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      // Enter and then clear search
      final searchField = find.descendant(
        of: find.byType(TextField),
        matching: find.byType(EditableText),
      );
      await tester.enterText(searchField, 'test');
      await tester.pumpAndSettle();

      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      // Both labels should be visible
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Backlog'), findsOneWidget);
    });
  });

  group('Label selection', () {
    testWidgets('shows initially selected labels as checked', (tester) async {
      final entry = textEntryWithLabels(['label-1']);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      // Find the checkbox for label-1
      final checkbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Urgent'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(checkbox.value, isTrue);
    });

    testWidgets('toggles label selection on tap', (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      // Initially unchecked
      var checkbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Urgent'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(checkbox.value, isFalse);

      // Tap to select
      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();

      // Now checked
      checkbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Urgent'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(checkbox.value, isTrue);
    });
  });

  group('Entry with existing labels', () {
    testWidgets('passes existing labelIds to selector', (tester) async {
      final entry = textEntryWithLabels(['label-1', 'label-2']);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Labels'));
      await tester.pumpAndSettle();

      final content = tester.widget<LabelSelectionModalContent>(
        find.byType(LabelSelectionModalContent),
      );
      expect(content.initialLabelIds, containsAll(['label-1', 'label-2']));
    });
  });
}
