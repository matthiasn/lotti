import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/ui/pages/project_create_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';
import '../../test_utils.dart';

void main() {
  late MockPersistenceLogic mockPersistenceLogic;
  late MockProjectRepository mockProjectRepo;
  late MockAgentTemplateService mockTemplateService;
  late MockProjectAgentService mockAgentService;
  late MockEntitiesCacheService mockEntitiesCacheService;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockPersistenceLogic = MockPersistenceLogic();
    mockProjectRepo = MockProjectRepository();
    mockTemplateService = MockAgentTemplateService();
    mockAgentService = MockProjectAgentService();
    mockEntitiesCacheService = MockEntitiesCacheService();

    // CategoryField (rendered by ProjectCreatePage) reads the category
    // name through `getIt<EntitiesCacheService>()`. Default the lookup
    // to "no category" so tests that don't preselect one don't trip
    // GetIt's missing-registration guard.
    when(
      () => mockEntitiesCacheService.getCategoryById(any()),
    ).thenReturn(null);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
      },
    );

    // Default: no templates available (agent provisioning is skipped).
    when(
      () => mockTemplateService.listTemplates(),
    ).thenAnswer((_) async => []);
    when(
      () => mockTemplateService.listTemplatesForCategory(any()),
    ).thenAnswer((_) async => []);
  });

  tearDown(tearDownTestGetIt);

  /// Pumps the [ProjectCreatePage] inside a [Navigator] so that
  /// `Navigator.of(context).pop()` works correctly.
  Future<void> pumpPage(
    WidgetTester tester, {
    String? categoryId,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ProjectCreatePage(categoryId: categoryId),
          ),
        ),
        overrides: [
          projectRepositoryProvider.overrideWithValue(mockProjectRepo),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          projectAgentServiceProvider.overrideWithValue(mockAgentService),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Metadata makeMetadata({String? categoryId}) {
    final date = DateTime(2024, 3, 15);
    return Metadata(
      id: 'test-meta-id',
      createdAt: date,
      updatedAt: date,
      dateFrom: date,
      dateTo: date,
      categoryId: categoryId,
    );
  }

  void stubCreateMetadata({String? categoryId}) {
    when(
      () => mockPersistenceLogic.createMetadata(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        categoryId: categoryId,
      ),
    ).thenAnswer((_) async => makeMetadata(categoryId: categoryId));
  }

  void stubCreateProject({ProjectEntry? result}) {
    final project = result ?? makeTestProject(id: 'test-meta-id');
    when(
      () => mockProjectRepo.createProject(project: any(named: 'project')),
    ).thenAnswer((_) async => project);
  }

  group('ProjectCreatePage', () {
    testWidgets(
      'CategoryField onSave updates the categoryId passed to createMetadata',
      (tester) async {
        const pickedCategoryId = 'cat-picked';
        // Stub the cache so the field re-renders with the picked
        // category's name once the onSave callback fires.
        when(
          () => mockEntitiesCacheService.getCategoryById(pickedCategoryId),
        ).thenReturn(
          CategoryTestUtils.createTestCategory(
            id: pickedCategoryId,
            name: 'Picked',
          ),
        );
        stubCreateMetadata(categoryId: pickedCategoryId);
        stubCreateProject();

        await pumpPage(tester);

        // Reach into the CategoryField and invoke its onSave directly.
        // Driving the picker modal end-to-end would be a wider integration
        // test; what matters here is the wiring between the field's
        // callback and the page's `_categoryId` state.
        final field = tester.widget<CategoryField>(find.byType(CategoryField));
        field.onSave(
          CategoryTestUtils.createTestCategory(
            id: pickedCategoryId,
            name: 'Picked',
          ),
        );
        await tester.pump();

        await tester.enterText(
          find.byType(LottiTextField),
          'Picked Project',
        );
        await tester.pump();

        await tester.tap(find.text('Create'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The new id flows from the field through `_categoryId` into
        // `createMetadata`. The FAB-driven flow opens the form with
        // `categoryId == null`, so without the wiring this verify would
        // see `null` and fail.
        verify(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: pickedCategoryId,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'didUpdateWidget re-seeds _categoryId when the same State sees a '
      'new widget.categoryId — without it, swapping the route query '
      'param would silently keep the original prefill on save',
      (tester) async {
        const oldCategoryId = 'cat-old';
        const newCategoryId = 'cat-new';
        for (final id in const [oldCategoryId, newCategoryId]) {
          when(
            () => mockEntitiesCacheService.getCategoryById(id),
          ).thenReturn(
            CategoryTestUtils.createTestCategory(id: id, name: id),
          );
        }
        stubCreateMetadata(categoryId: newCategoryId);
        stubCreateProject();

        // Drive the same Navigator route through two builds with
        // different categoryId inputs — wrapping in a StatefulBuilder
        // gives the test a setState handle to swap the widget input
        // without disposing the page state.
        var currentCategoryId = oldCategoryId;
        late void Function(void Function()) setOuterState;
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            StatefulBuilder(
              builder: (context, setState) {
                setOuterState = setState;
                return ProjectCreatePage(categoryId: currentCategoryId);
              },
            ),
            overrides: [
              projectRepositoryProvider.overrideWithValue(mockProjectRepo),
              agentTemplateServiceProvider.overrideWithValue(
                mockTemplateService,
              ),
              projectAgentServiceProvider.overrideWithValue(mockAgentService),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Swap the input. didUpdateWidget should observe this and
        // refresh `_categoryId`.
        setOuterState(() => currentCategoryId = newCategoryId);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(LottiTextField),
          'Reseeded Project',
        );
        await tester.pump();
        await tester.tap(find.text('Create'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: newCategoryId,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'CategoryField onSave clearing the selection nulls categoryId again',
      (tester) async {
        const seededCategoryId = 'cat-seed';
        when(
          () => mockEntitiesCacheService.getCategoryById(seededCategoryId),
        ).thenReturn(
          CategoryTestUtils.createTestCategory(
            id: seededCategoryId,
            name: 'Seed',
          ),
        );
        // After clearing the selection the form must call
        // `createMetadata` with `null`, so stub that variant explicitly.
        stubCreateMetadata();
        stubCreateProject();

        await pumpPage(tester, categoryId: seededCategoryId);

        // Clear the category by passing `null` to onSave, mirroring the
        // ✕ tap inside CategoryField.
        final field = tester.widget<CategoryField>(find.byType(CategoryField));
        field.onSave(null);
        await tester.pump();

        await tester.enterText(
          find.byType(LottiTextField),
          'Uncategorised Project',
        );
        await tester.pump();

        await tester.tap(find.text('Create'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            // ignore: avoid_redundant_argument_values
            categoryId: null,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'renders title, category, target date fields, and action buttons',
      (tester) async {
        await pumpPage(tester);

        // App bar title
        expect(find.text('Create Project'), findsOneWidget);

        // Title text field label (appears in input decoration)
        expect(find.text('Project Title'), findsWidgets);

        // Category picker — present even when nothing is selected. The
        // field uses the read-only TextField pattern so picking happens
        // inside a modal triggered by tapping the field.
        expect(find.byType(CategoryField), findsOneWidget);

        // Target date field
        expect(find.text('Target Date'), findsOneWidget);

        // Bottom bar buttons
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Create'), findsOneWidget);
      },
    );

    testWidgets(
      'shows error snackbar when title is empty and create is tapped',
      (tester) async {
        await pumpPage(tester);

        // Tap create without entering a title.
        await tester.tap(find.text('Create'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Project title cannot be empty'),
          findsOneWidget,
        );

        // Repository should never be called.
        verifyNever(
          () => mockProjectRepo.createProject(project: any(named: 'project')),
        );
      },
    );

    testWidgets('successful creation calls repository and pops navigator', (
      tester,
    ) async {
      stubCreateMetadata();
      stubCreateProject();

      // Wrap in a parent route so that Navigator.pop() is verifiable.
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProjectCreatePage(),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockProjectRepo),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
            projectAgentServiceProvider.overrideWithValue(mockAgentService),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Navigate to the create page.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter a title.
      await tester.enterText(find.byType(LottiTextField), 'My New Project');
      await tester.pump();

      // Tap create.
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      verify(
        () => mockPersistenceLogic.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          // ignore: avoid_redundant_argument_values
          categoryId: null,
        ),
      ).called(1);

      verify(
        () => mockProjectRepo.createProject(project: any(named: 'project')),
      ).called(1);

      // After successful creation the page pops, so the create page is gone.
      expect(find.text('Create Project'), findsNothing);
      expect(find.text('Open'), findsOneWidget);

      // No success SnackBar — the freshly-created project showing up in
      // the projects list is the success signal, and a Material
      // floating SnackBar would push the list's FAB up to fit, which
      // reads as more disruptive than informative for a one-shot
      // create flow.
      expect(find.text('Saved successfully'), findsNothing);
    });

    testWidgets(
      'creation failure (createProject returns null) shows the error toast '
      'and keeps the page open',
      (tester) async {
        stubCreateMetadata();
        when(
          () => mockProjectRepo.createProject(project: any(named: 'project')),
        ).thenAnswer((_) async => null);

        await pumpPage(tester);

        await tester.enterText(find.byType(LottiTextField), 'Doomed Project');
        await tester.pump();

        await tester.tap(find.text('Create'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // No navigation: the page stays open with the error toast shown.
        final context = tester.element(find.byType(ProjectCreatePage));
        expect(
          find.text(context.messages.projectErrorCreateFailed),
          findsOneWidget,
        );
        expect(find.byType(ProjectCreatePage), findsOneWidget);
        // No agent provisioning for a failed create.
        verifyNever(
          () => mockAgentService.createProjectAgent(
            projectId: any(named: 'projectId'),
            templateId: any(named: 'templateId'),
            displayName: any(named: 'displayName'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );
  });
}
