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

    when(() => cacheService.getLabelById(any())).thenReturn(null);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget buildWidget({
    required List<String> initialLabelIds,
    String? categoryId,
    List<LabelDefinition>? availableLabels,
    ValueNotifier<String>? searchQuery,
  }) {
    final applyController = ValueNotifier<Future<bool> Function()?>(null);
    final query = searchQuery ?? ValueNotifier<String>('');

    return ProviderScope(
      overrides: [
        availableLabelsForCategoryProvider(categoryId).overrideWith(
          (ref) => availableLabels ?? testLabels,
        ),
        labelsRepositoryProvider.overrideWithValue(repository),
        labelsStreamProvider.overrideWith((ref) => Stream.value(testLabels)),
      ],
      child: WidgetTestBench(
        child: Material(
          child: CustomScrollView(
            slivers: [
              LabelSelectionSliverContent(
                entryId: 'task-123',
                initialLabelIds: initialLabelIds,
                categoryId: categoryId,
                applyController: applyController,
                searchQuery: query,
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('LabelSelectionSliverContent', () {
    group('Label rendering', () {
      testWidgets('renders all available labels', (tester) async {
        await tester.pumpWidget(buildWidget(initialLabelIds: const []));
        await tester.pumpAndSettle();

        expect(find.text('Urgent'), findsOneWidget);
        expect(find.text('Backend'), findsOneWidget);
        expect(find.text('Frontend'), findsOneWidget);
        expect(find.text('Bug'), findsOneWidget);
      });

      testWidgets('shows checked state for initially selected labels',
          (tester) async {
        await tester
            .pumpWidget(buildWidget(initialLabelIds: const ['label-1']));
        await tester.pumpAndSettle();

        final checkbox = tester.widget<CheckboxListTile>(
          find.ancestor(
            of: find.text('Urgent'),
            matching: find.byType(CheckboxListTile),
          ),
        );
        expect(checkbox.value, isTrue);
      });

      testWidgets('toggles selection when checkbox is tapped', (tester) async {
        await tester.pumpWidget(buildWidget(initialLabelIds: const []));
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

        checkbox = tester.widget<CheckboxListTile>(
          find.ancestor(
            of: find.text('Urgent'),
            matching: find.byType(CheckboxListTile),
          ),
        );
        expect(checkbox.value, isTrue);

        // Tap to deselect
        await tester.tap(find.text('Urgent'));
        await tester.pumpAndSettle();

        checkbox = tester.widget<CheckboxListTile>(
          find.ancestor(
            of: find.text('Urgent'),
            matching: find.byType(CheckboxListTile),
          ),
        );
        expect(checkbox.value, isFalse);
      });

      testWidgets('shows label description as subtitle when present',
          (tester) async {
        await tester.pumpWidget(buildWidget(initialLabelIds: const []));
        await tester.pumpAndSettle();

        expect(find.text('Requires immediate attention'), findsOneWidget);
        expect(find.text('Backend development task'), findsOneWidget);
      });

      testWidgets('shows colored circle avatar for each label', (tester) async {
        await tester.pumpWidget(buildWidget(initialLabelIds: const []));
        await tester.pumpAndSettle();

        final circleAvatars = tester.widgetList<CircleAvatar>(
          find.byType(CircleAvatar),
        );
        expect(circleAvatars.length, 4);
      });
    });

    group('Search functionality', () {
      testWidgets('filters labels by name', (tester) async {
        final searchQuery = ValueNotifier<String>('');
        await tester.pumpWidget(buildWidget(
          initialLabelIds: const [],
          searchQuery: searchQuery,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Urgent'), findsOneWidget);
        expect(find.text('Backend'), findsOneWidget);

        searchQuery.value = 'Urg';
        await tester.pumpAndSettle();

        expect(find.text('Urgent'), findsOneWidget);
        expect(find.text('Backend'), findsNothing);
      });

      testWidgets('filters labels by description', (tester) async {
        final searchQuery = ValueNotifier<String>('');
        await tester.pumpWidget(buildWidget(
          initialLabelIds: const [],
          searchQuery: searchQuery,
        ));
        await tester.pumpAndSettle();

        searchQuery.value = 'immediate';
        await tester.pumpAndSettle();

        expect(find.text('Urgent'), findsOneWidget);
        expect(find.text('Backend'), findsNothing);
      });

      testWidgets('search is case insensitive', (tester) async {
        final searchQuery = ValueNotifier<String>('');
        await tester.pumpWidget(buildWidget(
          initialLabelIds: const [],
          searchQuery: searchQuery,
        ));
        await tester.pumpAndSettle();

        searchQuery.value = 'URGENT';
        await tester.pumpAndSettle();

        expect(find.text('Urgent'), findsOneWidget);
      });
    });

    group('Empty states', () {
      testWidgets('shows empty state when no labels available', (tester) async {
        await tester.pumpWidget(buildWidget(
          initialLabelIds: const [],
          availableLabels: const [],
        ));
        await tester.pumpAndSettle();

        expect(find.text('No labels available yet.'), findsOneWidget);
        expect(find.byIcon(Icons.label_outline), findsOneWidget);
      });

      testWidgets('shows empty state when search has no matches',
          (tester) async {
        final searchQuery = ValueNotifier<String>('');
        await tester.pumpWidget(buildWidget(
          initialLabelIds: const [],
          searchQuery: searchQuery,
        ));
        await tester.pumpAndSettle();

        searchQuery.value = 'nonexistent';
        await tester.pumpAndSettle();

        expect(find.textContaining('No labels match'), findsOneWidget);
      });
    });

    group('Label creation', () {
      testWidgets('opens label editor when create button is tapped',
          (tester) async {
        await tester.pumpWidget(buildWidget(
          initialLabelIds: const [],
          availableLabels: const [],
        ));
        await tester.pumpAndSettle();

        // Find the FilledButton.icon in the empty state by finding the add icon
        final createButton = find.byIcon(Icons.add);
        expect(createButton, findsOneWidget);

        await tester.tap(createButton);
        await tester.pumpAndSettle();

        expect(find.byType(LabelEditorSheet), findsOneWidget);
      });

      testWidgets('shows create button when search has substring match',
          (tester) async {
        final searchQuery = ValueNotifier<String>('');
        await tester.pumpWidget(buildWidget(
          initialLabelIds: const [],
          searchQuery: searchQuery,
        ));
        await tester.pumpAndSettle();

        searchQuery.value = 'Urg';
        await tester.pumpAndSettle();

        // Should find create button since 'Urg' is not an exact match
        expect(find.textContaining('Create "Urg" label'), findsOneWidget);
      });

      testWidgets('hides create button when exact match exists',
          (tester) async {
        final searchQuery = ValueNotifier<String>('');
        await tester.pumpWidget(buildWidget(
          initialLabelIds: const [],
          searchQuery: searchQuery,
        ));
        await tester.pumpAndSettle();

        searchQuery.value = 'Urgent';
        await tester.pumpAndSettle();

        // Should not find create button since 'Urgent' is an exact match
        expect(find.textContaining('Create "Urgent" label'), findsNothing);
      });
    });

    group('Apply functionality', () {
      testWidgets('initializes applyController on init', (tester) async {
        final applyController = ValueNotifier<Future<bool> Function()?>(null);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              availableLabelsForCategoryProvider(null).overrideWith(
                (ref) => testLabels,
              ),
              labelsRepositoryProvider.overrideWithValue(repository),
              labelsStreamProvider
                  .overrideWith((ref) => Stream.value(testLabels)),
            ],
            child: WidgetTestBench(
              child: Material(
                child: CustomScrollView(
                  slivers: [
                    LabelSelectionSliverContent(
                      entryId: 'task-123',
                      initialLabelIds: const [],
                      applyController: applyController,
                      searchQuery: ValueNotifier<String>(''),
                    ),
                  ],
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
        final applyController = ValueNotifier<Future<bool> Function()?>(null);

        when(() => repository.setLabels(
              journalEntityId: any(named: 'journalEntityId'),
              labelIds: any(named: 'labelIds'),
            )).thenAnswer((_) async => true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              availableLabelsForCategoryProvider(null).overrideWith(
                (ref) => testLabels,
              ),
              labelsRepositoryProvider.overrideWithValue(repository),
              labelsStreamProvider
                  .overrideWith((ref) => Stream.value(testLabels)),
            ],
            child: WidgetTestBench(
              child: Material(
                child: CustomScrollView(
                  slivers: [
                    LabelSelectionSliverContent(
                      entryId: 'task-123',
                      initialLabelIds: const ['label-1'],
                      applyController: applyController,
                      searchQuery: ValueNotifier<String>(''),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final result = await applyController.value!();
        expect(result, isTrue);

        verify(() => repository.setLabels(
              journalEntityId: 'task-123',
              labelIds: ['label-1'],
            )).called(1);
      });

      testWidgets('returns false when repository.setLabels fails',
          (tester) async {
        final applyController = ValueNotifier<Future<bool> Function()?>(null);

        when(() => repository.setLabels(
              journalEntityId: any(named: 'journalEntityId'),
              labelIds: any(named: 'labelIds'),
            )).thenAnswer((_) async => false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              availableLabelsForCategoryProvider(null).overrideWith(
                (ref) => testLabels,
              ),
              labelsRepositoryProvider.overrideWithValue(repository),
              labelsStreamProvider
                  .overrideWith((ref) => Stream.value(testLabels)),
            ],
            child: WidgetTestBench(
              child: Material(
                child: CustomScrollView(
                  slivers: [
                    LabelSelectionSliverContent(
                      entryId: 'task-123',
                      initialLabelIds: const [],
                      applyController: applyController,
                      searchQuery: ValueNotifier<String>(''),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final result = await applyController.value!();
        expect(result, isFalse);
      });
    });

    group('Category filtering', () {
      testWidgets('uses availableLabelsForCategoryProvider with category',
          (tester) async {
        final categoryLabels = [testLabels.first];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              availableLabelsForCategoryProvider('work').overrideWith(
                (ref) => categoryLabels,
              ),
              labelsRepositoryProvider.overrideWithValue(repository),
              labelsStreamProvider
                  .overrideWith((ref) => Stream.value(testLabels)),
            ],
            child: WidgetTestBench(
              child: Material(
                child: CustomScrollView(
                  slivers: [
                    LabelSelectionSliverContent(
                      entryId: 'task-123',
                      initialLabelIds: const [],
                      categoryId: 'work',
                      applyController:
                          ValueNotifier<Future<bool> Function()?>(null),
                      searchQuery: ValueNotifier<String>(''),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Urgent'), findsOneWidget);
        expect(find.text('Backend'), findsNothing);
      });
    });
  });
}
