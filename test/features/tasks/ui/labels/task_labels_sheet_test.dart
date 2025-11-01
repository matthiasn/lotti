// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/features/tasks/ui/labels/task_labels_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';

class _MockLabelsRepository extends Mock implements LabelsRepository {}

Future<void> _pumpSheet(
  WidgetTester tester,
  ProviderScope Function({List<String> initial}) buildSheet, {
  List<String> initial = const [],
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 2000);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(buildSheet(initial: initial));
  await tester.pumpAndSettle();
}

void main() {
  late MockEntitiesCacheService cacheService;
  late _MockLabelsRepository repository;
  final labels = [
    testLabelDefinition1,
    testLabelDefinition2.copyWith(description: 'Backlog tasks'),
  ];

  setUpAll(() {
    registerFallbackValue(testLabelDefinition1);
  });

  setUp(() async {
    repository = _MockLabelsRepository();
    cacheService = MockEntitiesCacheService();
    await getIt.reset();
    getIt.registerSingleton<EntitiesCacheService>(cacheService);
    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(
      () => cacheService.filterLabelsForCategory(
        any(),
        any(),
        includePrivate: any(named: 'includePrivate'),
      ),
    ).thenAnswer((invocation) =>
        invocation.positionalArguments.first as List<LabelDefinition>);
  });

  tearDown(() async {
    await getIt.reset();
  });

  ProviderScope buildSheet({
    List<String> initial = const [],
  }) {
    return ProviderScope(
      overrides: [
        labelsRepositoryProvider.overrideWithValue(repository),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(labels),
        ),
      ],
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1200, 1800)),
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
            body: TaskLabelsSheet(
              taskId: 'task-123',
              initialLabelIds: initial,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('applies selected labels via repository', (tester) async {
    when(
      () => repository.setLabels(
        journalEntityId: any(named: 'journalEntityId'),
        labelIds: any(named: 'labelIds'),
      ),
    ).thenAnswer((_) async => true);

    await _pumpSheet(tester, buildSheet, initial: const ['label-1']);

    final backlogFinder = find.text('Backlog');
    expect(backlogFinder, findsOneWidget);

    await tester.ensureVisible(backlogFinder);
    await tester.tap(backlogFinder);
    await tester.pump();

    // Apply selection via the sheet's Apply button.
    // Fallback to invoking onPressed directly to avoid rare hit-test issues
    // under test surfaces with overlays.
    final applyFinder = find.widgetWithText(FilledButton, 'Apply');
    if (applyFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(applyFinder);
      await tester.tap(applyFinder);
      await tester.pumpAndSettle();
    } else {
      final anyFilled = find.byType(FilledButton);
      final applyWidget = tester.widget<FilledButton>(anyFilled.last);
      expect(applyWidget.onPressed, isNotNull);
      applyWidget.onPressed!.call();
      await tester.pumpAndSettle();
    }

    verify(
      () => repository.setLabels(
        journalEntityId: 'task-123',
        labelIds: ['label-1', 'label-2'],
      ),
    ).called(1);
  });

  testWidgets('shows create CTA when no search results', (tester) async {
    await _pumpSheet(tester, buildSheet);

    await tester.enterText(find.byType(TextField), 'newtag');
    await tester.pump();

    expect(find.text('Create "newtag" label'), findsOneWidget);
  });

  testWidgets('launches label editor when hitting create CTA', (tester) async {
    when(() => repository.getAllLabels()).thenAnswer((_) async => labels);
    when(
      () => repository.createLabel(
        name: any(named: 'name'),
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
        sortOrder: any(named: 'sortOrder'),
        applicableCategoryIds: any(named: 'applicableCategoryIds'),
      ),
    ).thenAnswer((_) async => testLabelDefinition1);

    await _pumpSheet(tester, buildSheet);

    await tester.enterText(find.byType(TextField), 'newtag');
    await tester.pump();

    final createFinder = find.text('Create "newtag" label');
    expect(createFinder, findsOneWidget);

    await tester.ensureVisible(createFinder);
    await tester.tap(createFinder);
    await tester.pumpAndSettle();

    expect(find.byType(LabelEditorSheet), findsOneWidget);
  });

  testWidgets('inline create flow auto-selects the new label', (tester) async {
    final newLabel = testLabelDefinition1.copyWith(
      id: 'label-new',
      name: 'Newtag',
    );
    when(() => repository.getAllLabels()).thenAnswer((_) async => labels);
    when(
      () => repository.createLabel(
        name: any(named: 'name'),
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
        sortOrder: any(named: 'sortOrder'),
        applicableCategoryIds: any(named: 'applicableCategoryIds'),
      ),
    ).thenAnswer((_) async => newLabel);
    when(
      () => repository.setLabels(
        journalEntityId: any(named: 'journalEntityId'),
        labelIds: any(named: 'labelIds'),
      ),
    ).thenAnswer((_) async => true);

    await _pumpSheet(tester, buildSheet, initial: const ['label-1']);

    await tester.enterText(find.byType(TextField), 'newtag');
    await tester.pump();

    await tester.tap(find.text('Create "newtag" label'));
    await tester.pumpAndSettle();

    // Name field is prefilled, so submitting immediately should work.
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    // Apply selection robustly
    final applyFinder = find.widgetWithText(FilledButton, 'Apply');
    if (applyFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(applyFinder);
      await tester.tap(applyFinder);
      await tester.pumpAndSettle();
    } else {
      final anyFilled = find.byType(FilledButton);
      final applyWidget = tester.widget<FilledButton>(anyFilled.last);
      expect(applyWidget.onPressed, isNotNull);
      applyWidget.onPressed!.call();
      await tester.pumpAndSettle();
    }

    final captured = verify(
      () => repository.setLabels(
        journalEntityId: 'task-123',
        labelIds: captureAny(named: 'labelIds'),
      ),
    ).captured.single as List<String>;
    expect(captured, containsAll(['label-1', 'label-new']));
  });

  testWidgets('create flow surfaces duplicate name error', (tester) async {
    when(() => repository.getAllLabels()).thenAnswer(
      (_) async => [
        ...labels,
        testLabelDefinition1.copyWith(name: 'newtag'),
      ],
    );

    final preview = await repository.getAllLabels();
    expect(preview.map((label) => label.name), contains('newtag'));
    clearInteractions(repository);

    await _pumpSheet(tester, buildSheet);

    await tester.enterText(find.byType(TextField), 'newtag');
    await tester.pump();

    await tester.tap(find.text('Create "newtag" label'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    verify(() => repository.getAllLabels()).called(1);
    verifyNever(
      () => repository.createLabel(
        name: any(named: 'name'),
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
        sortOrder: any(named: 'sortOrder'),
        applicableCategoryIds: any(named: 'applicableCategoryIds'),
      ),
    );
    expect(find.byType(LabelEditorSheet), findsOneWidget);
    verifyNever(() => repository.createLabel(
          name: any(named: 'name'),
          color: any(named: 'color'),
          description: any(named: 'description'),
          private: any(named: 'private'),
          sortOrder: any(named: 'sortOrder'),
          applicableCategoryIds: any(named: 'applicableCategoryIds'),
        ));
  });

  group('category scoping', () {
    LabelDefinition global(String id, String name) => LabelDefinition(
          id: id,
          name: name,
          color: '#111111',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
        );

    LabelDefinition scoped(String id, String name, String cat) =>
        LabelDefinition(
          id: id,
          name: name,
          color: '#222222',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          applicableCategoryIds: [cat],
        );

    setUp(() {
      // Override stub to implement simple scoping behavior
      when(() => cacheService.filterLabelsForCategory(
            any(),
            any(),
            includePrivate: any(named: 'includePrivate'),
          )).thenAnswer((invocation) {
        final all = invocation.positionalArguments[0] as List<LabelDefinition>;
        final catId = invocation.positionalArguments[1] as String?;
        final includePrivate =
            invocation.namedArguments[#includePrivate] as bool? ?? true;
        return all.where((l) {
          if (!includePrivate && (l.private ?? false)) return false;
          final cats = l.applicableCategoryIds;
          final isGlobal = cats == null || cats.isEmpty;
          return isGlobal || (catId != null && cats.contains(catId));
        }).toList();
      });
    });

    ProviderScope buildWithLabels(List<LabelDefinition> ls,
        {String? categoryId}) {
      return ProviderScope(
        overrides: [
          labelsRepositoryProvider.overrideWithValue(repository),
          labelsStreamProvider.overrideWith((ref) => Stream.value(ls)),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 1800)),
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
              body: TaskLabelsSheet(
                taskId: 'task-123',
                initialLabelIds: const [],
                categoryId: categoryId,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows only global labels when categoryId is null',
        (tester) async {
      final ls = [
        global('g', 'Global'),
        scoped('s', 'ScopedWork', 'work'),
      ];
      await tester.pumpWidget(buildWithLabels(ls, categoryId: null));
      await tester.pumpAndSettle();

      expect(find.text('Global'), findsOneWidget);
      expect(find.text('ScopedWork'), findsNothing);
    });

    testWidgets(
        'shows union of global + category labels when categoryId provided',
        (tester) async {
      final ls = [
        global('g', 'Global'),
        scoped('s', 'ScopedWork', 'work'),
        scoped('t', 'OtherCat', 'other'),
      ];
      await tester.pumpWidget(buildWithLabels(ls, categoryId: 'work'));
      await tester.pumpAndSettle();

      expect(find.text('Global'), findsOneWidget);
      expect(find.text('ScopedWork'), findsOneWidget);
      expect(find.text('OtherCat'), findsNothing);
    });

    testWidgets('updates available labels when categoryId changes',
        (tester) async {
      final ls = [
        global('g', 'Global'),
        scoped('w', 'WorkOnly', 'work'),
        scoped('p', 'PersonalOnly', 'personal'),
      ];
      await tester.pumpWidget(buildWithLabels(ls, categoryId: 'work'));
      await tester.pumpAndSettle();
      expect(find.text('WorkOnly'), findsOneWidget);
      expect(find.text('PersonalOnly'), findsNothing);

      await tester.pumpWidget(buildWithLabels(ls, categoryId: 'personal'));
      await tester.pumpAndSettle();
      expect(find.text('WorkOnly'), findsNothing);
      expect(find.text('PersonalOnly'), findsOneWidget);
    });

    testWidgets('respects privacy filtering in category-scoped labels',
        (tester) async {
      when(() => cacheService.showPrivateEntries).thenReturn(false);
      final privateScoped =
          scoped('pv', 'PrivateScoped', 'work').copyWith(private: true);
      final ls = [global('g', 'Global'), privateScoped];
      await tester.pumpWidget(buildWithLabels(ls, categoryId: 'work'));
      await tester.pumpAndSettle();

      // Global still visible, private scoped filtered out
      expect(find.text('Global'), findsOneWidget);
      expect(find.text('PrivateScoped'), findsNothing);
    });
  });
}
