import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/features/tasks/ui/labels/label_selection_modal_content.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';

class _MockLabelsRepository extends Mock implements LabelsRepository {}

class _MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late _MockLabelsRepository repository;
  late _MockEntitiesCacheService cacheService;

  final testLabels = [
    testLabelDefinition1.copyWith(
      id: 'label-1',
      name: 'Urgent',
      description: 'Requires immediate attention',
      color: '#FF0000',
    ),
    testLabelDefinition2.copyWith(
      id: 'label-2',
      name: 'Backend',
      description: 'Backend development task',
      color: '#00FF00',
    ),
    testLabelDefinition1.copyWith(
      id: 'label-3',
      name: 'Frontend',
      description: null,
      color: '#0000FF',
    ),
    testLabelDefinition2.copyWith(
      id: 'label-4',
      name: 'Bug',
      description: '',
      color: '#FF00FF',
    ),
  ];

  setUpAll(() {
    registerFallbackValue(testLabelDefinition1);
  });

  setUp(() async {
    repository = _MockLabelsRepository();
    cacheService = _MockEntitiesCacheService();

    await getIt.reset();
    getIt
      ..registerSingleton<LabelsRepository>(repository)
      ..registerSingleton<EntitiesCacheService>(cacheService);

    when(() => cacheService.filterLabelsForCategory(
          any(),
          any(),
        )).thenAnswer(
      (invocation) =>
          invocation.positionalArguments.first as List<LabelDefinition>,
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget buildWidget({
    required List<String> initialLabelIds,
    String? categoryId,
    List<LabelDefinition>? availableLabels,
  }) {
    final applyController = ValueNotifier<Future<bool> Function()?>(null);
    final searchQuery = ValueNotifier<String>('');

    return ProviderScope(
      overrides: [
        availableLabelsForCategoryProvider(categoryId).overrideWith(
          (ref) => availableLabels ?? testLabels,
        ),
        labelsRepositoryProvider.overrideWithValue(repository),
      ],
      child: WidgetTestBench(
        child: Material(
          child: LabelSelectionModalContent(
            taskId: 'task-123',
            initialLabelIds: initialLabelIds,
            categoryId: categoryId,
            applyController: applyController,
            searchQuery: searchQuery,
          ),
        ),
      ),
    );
  }

  group('Label rendering and selection', () {
    testWidgets('renders all available labels', (tester) async {
      await tester.pumpWidget(buildWidget(initialLabelIds: const []));
      await tester.pumpAndSettle();

      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Backend'), findsOneWidget);
      expect(find.text('Frontend'), findsOneWidget);
      expect(find.text('Bug'), findsOneWidget);
    });

    testWidgets('shows labels sorted alphabetically', (tester) async {
      await tester.pumpWidget(buildWidget(initialLabelIds: const []));
      await tester.pumpAndSettle();

      final checkboxes =
          tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
      final labelNames = checkboxes
          .map((cb) => (cb.title! as Text).data)
          .where((name) => name != null)
          .toList();

      expect(labelNames, equals(['Backend', 'Bug', 'Frontend', 'Urgent']));
    });

    testWidgets('shows checked state for initially selected labels',
        (tester) async {
      await tester.pumpWidget(
        buildWidget(initialLabelIds: const ['label-1', 'label-2']),
      );
      await tester.pumpAndSettle();

      final urgentCheckbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Urgent'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      final backendCheckbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Backend'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      final frontendCheckbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Frontend'),
          matching: find.byType(CheckboxListTile),
        ),
      );

      expect(urgentCheckbox.value, isTrue);
      expect(backendCheckbox.value, isTrue);
      expect(frontendCheckbox.value, isFalse);
    });

    testWidgets('toggles selection when checkbox is tapped', (tester) async {
      await tester.pumpWidget(buildWidget(initialLabelIds: const []));
      await tester.pumpAndSettle();

      // Initially unchecked
      var urgentCheckbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Urgent'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(urgentCheckbox.value, isFalse);

      // Tap to check
      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();

      urgentCheckbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Urgent'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(urgentCheckbox.value, isTrue);

      // Tap to uncheck
      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();

      urgentCheckbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Urgent'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(urgentCheckbox.value, isFalse);
    });

    testWidgets('shows label description as subtitle when present',
        (tester) async {
      await tester.pumpWidget(buildWidget(initialLabelIds: const []));
      await tester.pumpAndSettle();

      expect(find.text('Requires immediate attention'), findsOneWidget);
      expect(find.text('Backend development task'), findsOneWidget);
    });

    testWidgets('does not show subtitle for labels without description',
        (tester) async {
      await tester.pumpWidget(buildWidget(initialLabelIds: const []));
      await tester.pumpAndSettle();

      final frontendCheckbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Frontend'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(frontendCheckbox.subtitle, isNull);

      final bugCheckbox = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Bug'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(bugCheckbox.subtitle, isNull);
    });

    testWidgets('shows colored circle avatar for each label', (tester) async {
      await tester.pumpWidget(buildWidget(initialLabelIds: const []));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is CircleAvatar && widget.radius == 12,
        ),
        findsNWidgets(4),
      );
    });
  });

  group('Search functionality', () {
    testWidgets('filters labels by name', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Update search query
      searchQuery.value = 'urg';
      await tester.pumpAndSettle();

      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Backend'), findsNothing);
      expect(find.text('Frontend'), findsNothing);
      expect(find.text('Bug'), findsNothing);
    });

    testWidgets('filters labels by description', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search by description
      searchQuery.value = 'development';
      await tester.pumpAndSettle();

      expect(find.text('Backend'), findsOneWidget);
      expect(find.text('Urgent'), findsNothing);
      expect(find.text('Frontend'), findsNothing);
      expect(find.text('Bug'), findsNothing);
    });

    testWidgets('search is case insensitive', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = 'URGENT';
      await tester.pumpAndSettle();

      expect(find.text('Urgent'), findsOneWidget);
    });

    testWidgets('trims and handles whitespace in search', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = '  backend  ';
      await tester.pumpAndSettle();

      expect(find.text('Backend'), findsOneWidget);
      expect(find.text('Urgent'), findsNothing);
    });

    testWidgets('shows all labels when search is empty', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = '';
      await tester.pumpAndSettle();

      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Backend'), findsOneWidget);
      expect(find.text('Frontend'), findsOneWidget);
      expect(find.text('Bug'), findsOneWidget);
    });
  });

  group('Empty states', () {
    testWidgets('shows empty state when no labels available', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          initialLabelIds: const [],
          availableLabels: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No labels available yet.'), findsOneWidget);
      expect(find.text('Create label'), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsOneWidget);
    });

    testWidgets('shows empty state when search has no matches', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = 'nonexistent';
      await tester.pumpAndSettle();

      expect(find.text('No labels match "nonexistent".'), findsOneWidget);
      expect(find.text('Create "nonexistent" label'), findsOneWidget);
    });

    testWidgets('empty state without search query shows generic message',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => const <LabelDefinition>[],
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No labels available yet.'), findsOneWidget);
      expect(find.text('Create label'), findsOneWidget);
    });

    testWidgets('empty state with whitespace-only search shows generic text',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set search to whitespace only
      searchQuery.value = '   ';
      await tester.pumpAndSettle();

      // All labels should still be visible since trimmed query is empty
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Backend'), findsOneWidget);
    });
  });

  group('Label creation', () {
    testWidgets('opens label editor when create button is tapped',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => const <LabelDefinition>[],
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create label'));
      await tester.pumpAndSettle();

      expect(find.byType(LabelEditorSheet), findsOneWidget);
    });

    testWidgets('prefills label name when creating from search query',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = 'New Label Name';
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create "New Label Name" label'));
      await tester.pumpAndSettle();

      final editorSheet =
          tester.widget<LabelEditorSheet>(find.byType(LabelEditorSheet));
      expect(editorSheet.initialName, equals('New Label Name'));
    });

    testWidgets('does not prefill when creating from empty state',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => const <LabelDefinition>[],
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create label'));
      await tester.pumpAndSettle();

      final editorSheet =
          tester.widget<LabelEditorSheet>(find.byType(LabelEditorSheet));
      expect(editorSheet.initialName, isNull);
    });
  });

  group('Apply functionality', () {
    testWidgets('initializes applyController on init', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(applyController.value, isNotNull);
    });

    testWidgets('calls repository.setLabels when apply is invoked',
        (tester) async {
      when(() => repository.setLabels(
            journalEntityId: any(named: 'journalEntityId'),
            labelIds: any(named: 'labelIds'),
          )).thenAnswer((_) async => true);

      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select a label
      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();

      // Call apply
      final result = await applyController.value!();

      expect(result, isTrue);
      verify(() => repository.setLabels(
            journalEntityId: 'task-123',
            labelIds: ['label-1'],
          )).called(1);
    });

    testWidgets('returns false when repository.setLabels fails',
        (tester) async {
      when(() => repository.setLabels(
            journalEntityId: any(named: 'journalEntityId'),
            labelIds: any(named: 'labelIds'),
          )).thenAnswer((_) async => null);

      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Call apply
      final result = await applyController.value!();

      expect(result, isFalse);
    });

    testWidgets('applies selected labels correctly with multiple selections',
        (tester) async {
      when(() => repository.setLabels(
            journalEntityId: any(named: 'journalEntityId'),
            labelIds: any(named: 'labelIds'),
          )).thenAnswer((_) async => true);

      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const ['label-1'],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select additional labels
      await tester.tap(find.text('Backend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frontend'));
      await tester.pumpAndSettle();

      // Call apply
      await applyController.value!();

      // Verify all three labels are set
      final captured = verify(() => repository.setLabels(
            journalEntityId: 'task-123',
            labelIds: captureAny(named: 'labelIds'),
          )).captured.single as List<String>;

      expect(captured.length, equals(3));
      expect(captured.toSet(), containsAll(['label-1', 'label-2', 'label-3']));
    });

    testWidgets('deselecting initial labels removes them from apply',
        (tester) async {
      when(() => repository.setLabels(
            journalEntityId: any(named: 'journalEntityId'),
            labelIds: any(named: 'labelIds'),
          )).thenAnswer((_) async => true);

      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const ['label-1', 'label-2'],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deselect one label
      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();

      // Call apply
      await applyController.value!();

      // Verify only one label remains
      verify(() => repository.setLabels(
            journalEntityId: 'task-123',
            labelIds: ['label-2'],
          )).called(1);
    });

    testWidgets('applies empty list when all labels deselected',
        (tester) async {
      when(() => repository.setLabels(
            journalEntityId: any(named: 'journalEntityId'),
            labelIds: any(named: 'labelIds'),
          )).thenAnswer((_) async => true);

      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const ['label-1'],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deselect the label
      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();

      // Call apply
      await applyController.value!();

      verify(() => repository.setLabels(
            journalEntityId: 'task-123',
            labelIds: const <String>[],
          )).called(1);
    });
  });

  group('Category filtering', () {
    testWidgets('uses availableLabelsForCategoryProvider with null category',
        (tester) async {
      await tester.pumpWidget(
        buildWidget(
          initialLabelIds: const [],
          availableLabels: testLabels,
        ),
      );
      await tester.pumpAndSettle();

      // All labels should be available
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Backend'), findsOneWidget);
      expect(find.text('Frontend'), findsOneWidget);
      expect(find.text('Bug'), findsOneWidget);
    });

    testWidgets(
        'uses availableLabelsForCategoryProvider with specific category',
        (tester) async {
      final categoryLabels = [testLabels[0], testLabels[1]]; // Urgent, Backend

      await tester.pumpWidget(
        buildWidget(
          initialLabelIds: const [],
          categoryId: 'work-category',
          availableLabels: categoryLabels,
        ),
      );
      await tester.pumpAndSettle();

      // Only category-specific labels should be available
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Backend'), findsOneWidget);
      expect(find.text('Frontend'), findsNothing);
      expect(find.text('Bug'), findsNothing);
    });
  });

  group('Create button with substring matches', () {
    testWidgets('shows create button when substring match but no exact match',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      final labelsWithDependencies = [
        ...testLabels,
        testLabelDefinition1.copyWith(
          id: 'label-5',
          name: 'dependencies',
          description: 'Dependency updates',
          color: '#FFA500',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => labelsWithDependencies,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search for "CI" which is a substring of "dependencies"
      searchQuery.value = 'CI';
      await tester.pumpAndSettle();

      // "dependencies" should be shown (substring match)
      expect(find.text('dependencies'), findsOneWidget);
      // Create button should also be visible
      expect(find.text('Create "CI" label'), findsOneWidget);
    });

    testWidgets('hides create button when exact match exists (same case)',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      final labelsWithCI = [
        ...testLabels,
        testLabelDefinition1.copyWith(
          id: 'label-ci',
          name: 'CI',
          description: 'Continuous Integration',
          color: '#00FFFF',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => labelsWithCI,
            ),
            labelsStreamProvider
                .overrideWith((ref) => Stream.value(labelsWithCI)),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = 'CI';
      await tester.pumpAndSettle();

      // "CI" label should be shown
      expect(find.text('CI'), findsOneWidget);
      // Create button should NOT be visible
      expect(find.text('Create "CI" label'), findsNothing);
    });

    testWidgets('hides create button when exact match exists (different case)',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      final labelsWithCI = [
        ...testLabels,
        testLabelDefinition1.copyWith(
          id: 'label-ci',
          name: 'CI',
          description: 'Continuous Integration',
          color: '#00FFFF',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => labelsWithCI,
            ),
            labelsStreamProvider
                .overrideWith((ref) => Stream.value(labelsWithCI)),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search for "ci" (lowercase) when "CI" (uppercase) exists
      searchQuery.value = 'ci';
      await tester.pumpAndSettle();

      // "CI" label should be shown
      expect(find.text('CI'), findsOneWidget);
      // Create button should NOT be visible (case-insensitive exact match)
      expect(find.text('Create "ci" label'), findsNothing);
    });

    testWidgets('shows create button with multiple substring matches',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      final labelsWithMultipleMatches = [
        ...testLabels,
        testLabelDefinition1.copyWith(
          id: 'label-5',
          name: 'dependencies',
          description: 'Dependency updates',
          color: '#FFA500',
        ),
        testLabelDefinition2.copyWith(
          id: 'label-6',
          name: 'continuous integration',
          description: 'CI/CD pipeline',
          color: '#00FFFF',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => labelsWithMultipleMatches,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = 'CI';
      await tester.pumpAndSettle();

      // Both substring matches should be shown
      expect(find.text('dependencies'), findsOneWidget);
      expect(find.text('continuous integration'), findsOneWidget);
      // Create button should be visible
      expect(find.text('Create "CI" label'), findsOneWidget);
    });

    testWidgets('hides create button when query is empty', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = '';
      await tester.pumpAndSettle();

      // All labels should be shown
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Backend'), findsOneWidget);
      // Create button should NOT be visible
      expect(find.textContaining('Create'), findsNothing);
    });

    testWidgets('hides create button when query is whitespace only',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => testLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = '   ';
      await tester.pumpAndSettle();

      // All labels should be shown (trimmed query is empty)
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Backend'), findsOneWidget);
      // Create button should NOT be visible
      expect(find.textContaining('Create'), findsNothing);
    });

    testWidgets('tapping create button opens label editor with prefilled name',
        (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      final labelsWithDependencies = [
        ...testLabels,
        testLabelDefinition1.copyWith(
          id: 'label-5',
          name: 'dependencies',
          description: 'Dependency updates',
          color: '#FFA500',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider(null).overrideWith(
              (ref) => labelsWithDependencies,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = 'CI';
      await tester.pumpAndSettle();

      // Tap the create button
      await tester.tap(find.text('Create "CI" label'));
      await tester.pumpAndSettle();

      // Label editor should open with "CI" as initial name
      expect(find.byType(LabelEditorSheet), findsOneWidget);
      final editorSheet =
          tester.widget<LabelEditorSheet>(find.byType(LabelEditorSheet));
      expect(editorSheet.initialName, equals('CI'));
    });

    testWidgets('create button works with category scoping', (tester) async {
      final applyController = ValueNotifier<Future<bool> Function()?>(null);
      final searchQuery = ValueNotifier<String>('');

      final categoryLabels = [
        testLabelDefinition1.copyWith(
          id: 'label-deps',
          name: 'dependencies',
          description: 'Dependency updates',
          color: '#FFA500',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableLabelsForCategoryProvider('work-category').overrideWith(
              (ref) => categoryLabels,
            ),
            labelsRepositoryProvider.overrideWithValue(repository),
          ],
          child: WidgetTestBench(
            child: Material(
              child: LabelSelectionModalContent(
                taskId: 'task-123',
                initialLabelIds: const [],
                categoryId: 'work-category',
                applyController: applyController,
                searchQuery: searchQuery,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      searchQuery.value = 'CI';
      await tester.pumpAndSettle();

      // Category-scoped label shown
      expect(find.text('dependencies'), findsOneWidget);
      // Create button visible
      expect(find.text('Create "CI" label'), findsOneWidget);
    });
  });
}
