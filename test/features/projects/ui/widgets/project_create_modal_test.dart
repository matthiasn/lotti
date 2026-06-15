import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/ui/widgets/project_create_modal.dart';
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

    // CategoryField (rendered by the form) reads the category name through
    // `getIt<EntitiesCacheService>()`. Default the lookup to "no category" so
    // tests that don't preselect one don't trip GetIt's missing-registration
    // guard.
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

  List<Override> overrides() => [
    projectRepositoryProvider.overrideWithValue(mockProjectRepo),
    agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
    projectAgentServiceProvider.overrideWithValue(mockAgentService),
  ];

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

  AgentIdentityEntity makeAgent() =>
      AgentDomainEntity.agent(
            id: 'agent-1',
            agentId: 'agent-1',
            kind: 'project_agent',
            displayName: 'Test Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  AgentTemplateEntity makeProjectAgentTemplate({
    String id = 'tpl-1',
    Set<String> categoryIds = const {},
  }) =>
      AgentDomainEntity.agentTemplate(
            id: id,
            agentId: id,
            displayName: 'Project Agent Template',
            kind: AgentTemplateKind.projectAgent,
            modelId: 'models/test',
            categoryIds: categoryIds,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          )
          as AgentTemplateEntity;

  /// Pumps [ProjectCreateForm] pushed on top of a base route so that the
  /// form's `Navigator.pop` (on save/cancel) is exercised exactly as it is
  /// inside the real modal.
  Future<void> pumpForm(
    WidgetTester tester, {
    String? categoryId,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          body: ProjectCreateForm(categoryId: categoryId),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
        overrides: overrides(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('ProjectCreateForm', () {
    testWidgets('renders title field, category field, target date field, and '
        'action buttons', (tester) async {
      await pumpForm(tester);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;

      expect(find.byType(LottiTextField), findsOneWidget);
      expect(find.byType(CategoryField), findsOneWidget);
      expect(find.text(messages.projectTargetDateLabel), findsOneWidget);
      expect(find.text(messages.cancelButton), findsOneWidget);
      expect(find.text(messages.createButton), findsOneWidget);
    });

    testWidgets('empty title shows an error toast and never calls the '
        'repository', (tester) async {
      await pumpForm(tester);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;

      await tester.tap(find.text(messages.createButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(messages.projectTitleRequired), findsOneWidget);
      verifyNever(
        () => mockProjectRepo.createProject(project: any(named: 'project')),
      );
    });

    testWidgets(
      'successful creation persists the project and closes the form',
      (tester) async {
        stubCreateMetadata();
        stubCreateProject();

        await pumpForm(tester);
        final messages = tester
            .element(find.byType(ProjectCreateForm))
            .messages;

        await tester.enterText(find.byType(LottiTextField), 'My New Project');
        await tester.pump();

        await tester.tap(find.text(messages.createButton));
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

        // The form closed (popped) on success; the base route is shown again.
        expect(find.byType(ProjectCreateForm), findsNothing);
        expect(find.text('open'), findsOneWidget);
      },
    );

    testWidgets('createProject returning null shows an error toast and keeps '
        'the form open', (tester) async {
      stubCreateMetadata();
      when(
        () => mockProjectRepo.createProject(project: any(named: 'project')),
      ).thenAnswer((_) async => null);

      await pumpForm(tester);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;

      await tester.enterText(find.byType(LottiTextField), 'Doomed Project');
      await tester.pump();

      await tester.tap(find.text(messages.createButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(messages.projectErrorCreateFailed), findsOneWidget);
      expect(find.byType(ProjectCreateForm), findsOneWidget);
      verifyNever(
        () => mockAgentService.createProjectAgent(
          projectId: any(named: 'projectId'),
          templateId: any(named: 'templateId'),
          displayName: any(named: 'displayName'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      );
    });

    testWidgets('repository throwing shows an error toast', (tester) async {
      stubCreateMetadata();
      when(
        () => mockProjectRepo.createProject(project: any(named: 'project')),
      ).thenThrow(Exception('DB failure'));

      await pumpForm(tester);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;

      await tester.enterText(find.byType(LottiTextField), 'Failing Project');
      await tester.pump();

      await tester.tap(find.text(messages.createButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(messages.projectErrorCreateFailed), findsOneWidget);
      expect(find.byType(ProjectCreateForm), findsOneWidget);
    });

    testWidgets('preselected categoryId flows into createMetadata', (
      tester,
    ) async {
      const categoryId = 'cat-1';
      stubCreateMetadata(categoryId: categoryId);
      stubCreateProject();

      await pumpForm(tester, categoryId: categoryId);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;

      await tester.enterText(find.byType(LottiTextField), 'Categorised');
      await tester.pump();

      await tester.tap(find.text(messages.createButton));
      await tester.pumpAndSettle();

      verify(
        () => mockPersistenceLogic.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          categoryId: categoryId,
        ),
      ).called(1);
    });

    testWidgets('CategoryField onSave updates the categoryId used on save', (
      tester,
    ) async {
      const pickedCategoryId = 'cat-picked';
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

      await pumpForm(tester);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;

      // Driving the picker modal end-to-end would be a wider integration
      // test; what matters here is the wiring between the field's callback
      // and the form's `_categoryId` state.
      tester
          .widget<CategoryField>(find.byType(CategoryField))
          .onSave(
            CategoryTestUtils.createTestCategory(
              id: pickedCategoryId,
              name: 'Picked',
            ),
          );
      await tester.pump();

      await tester.enterText(find.byType(LottiTextField), 'Picked Project');
      await tester.pump();

      await tester.tap(find.text(messages.createButton));
      await tester.pumpAndSettle();

      verify(
        () => mockPersistenceLogic.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          categoryId: pickedCategoryId,
        ),
      ).called(1);
    });

    testWidgets('clearing the category nulls the categoryId on save', (
      tester,
    ) async {
      const seededCategoryId = 'cat-seed';
      when(
        () => mockEntitiesCacheService.getCategoryById(seededCategoryId),
      ).thenReturn(
        CategoryTestUtils.createTestCategory(
          id: seededCategoryId,
          name: 'Seed',
        ),
      );
      stubCreateMetadata();
      stubCreateProject();

      await pumpForm(tester, categoryId: seededCategoryId);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;

      tester.widget<CategoryField>(find.byType(CategoryField)).onSave(null);
      await tester.pump();

      await tester.enterText(find.byType(LottiTextField), 'Uncategorised');
      await tester.pump();

      await tester.tap(find.text(messages.createButton));
      await tester.pumpAndSettle();

      verify(
        () => mockPersistenceLogic.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          // ignore: avoid_redundant_argument_values
          categoryId: null,
        ),
      ).called(1);
    });

    testWidgets('provisions a project agent from a global template', (
      tester,
    ) async {
      stubCreateMetadata();
      stubCreateProject();
      when(
        () => mockTemplateService.listTemplates(),
      ).thenAnswer((_) async => [makeProjectAgentTemplate()]);
      when(
        () => mockAgentService.createProjectAgent(
          projectId: any(named: 'projectId'),
          templateId: any(named: 'templateId'),
          displayName: any(named: 'displayName'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      ).thenAnswer((_) async => makeAgent());

      await pumpForm(tester);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;

      await tester.enterText(find.byType(LottiTextField), 'Agent Project');
      await tester.pump();

      await tester.tap(find.text(messages.createButton));
      await tester.pumpAndSettle();

      verify(
        () => mockAgentService.createProjectAgent(
          projectId: 'test-meta-id',
          templateId: 'tpl-1',
          displayName: 'Agent Project',
          allowedCategoryIds: <String>{},
        ),
      ).called(1);
    });

    testWidgets('prefers a category-scoped template when a category is set', (
      tester,
    ) async {
      const categoryId = 'cat-1';
      stubCreateMetadata(categoryId: categoryId);
      stubCreateProject();
      when(
        () => mockTemplateService.listTemplatesForCategory(categoryId),
      ).thenAnswer(
        (_) async => [
          makeProjectAgentTemplate(id: 'tpl-cat', categoryIds: {categoryId}),
        ],
      );
      when(
        () => mockAgentService.createProjectAgent(
          projectId: any(named: 'projectId'),
          templateId: any(named: 'templateId'),
          displayName: any(named: 'displayName'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      ).thenAnswer((_) async => makeAgent());

      await pumpForm(tester, categoryId: categoryId);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;

      await tester.enterText(find.byType(LottiTextField), 'Cat Project');
      await tester.pump();

      await tester.tap(find.text(messages.createButton));
      await tester.pumpAndSettle();

      verify(
        () => mockTemplateService.listTemplatesForCategory(categoryId),
      ).called(1);
      verify(
        () => mockAgentService.createProjectAgent(
          projectId: 'test-meta-id',
          templateId: 'tpl-cat',
          displayName: 'Cat Project',
          allowedCategoryIds: {categoryId},
        ),
      ).called(1);
    });

    testWidgets('target date can be picked and cleared', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After picking, a clear affordance appears.
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('Ctrl+S triggers create', (tester) async {
      stubCreateMetadata();
      stubCreateProject();

      await pumpForm(tester);

      await tester.enterText(find.byType(LottiTextField), 'Shortcut Project');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      verify(
        () => mockProjectRepo.createProject(project: any(named: 'project')),
      ).called(1);
    });

    testWidgets('cancel closes the form without creating anything', (
      tester,
    ) async {
      await pumpForm(tester);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;

      await tester.tap(find.text(messages.cancelButton));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectCreateForm), findsNothing);
      expect(find.text('open'), findsOneWidget);
      verifyNever(
        () => mockProjectRepo.createProject(project: any(named: 'project')),
      );
    });
  });

  group('showProjectCreateModal', () {
    /// Pumps a launcher button that opens the modal and records its result.
    Future<ValueNotifier<ProjectEntry?>> pumpLauncher(
      WidgetTester tester,
    ) async {
      final result = ValueNotifier<ProjectEntry?>(null);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result.value = await showProjectCreateModal(
                      context: context,
                    );
                  },
                  child: const Text('launch'),
                ),
              ),
            ),
          ),
          overrides: overrides(),
        ),
      );
      await tester.pump();
      return result;
    }

    testWidgets('opens the modal and resolves to the created project on save', (
      tester,
    ) async {
      stubCreateMetadata();
      final created = makeTestProject(id: 'test-meta-id', title: 'Modal');
      stubCreateProject(result: created);

      final result = await pumpLauncher(tester);

      await tester.tap(find.text('launch'));
      await tester.pumpAndSettle();

      // The modal is showing the form.
      expect(find.byType(ProjectCreateForm), findsOneWidget);
      final messages = tester.element(find.byType(ProjectCreateForm)).messages;
      expect(find.text(messages.projectCreateTitle), findsWidgets);

      await tester.enterText(find.byType(LottiTextField), 'Modal');
      await tester.pump();

      await tester.tap(find.text(messages.createButton));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectCreateForm), findsNothing);
      expect(result.value, isNotNull);
      expect(result.value!.meta.id, 'test-meta-id');
    });

    testWidgets('resolves to null when dismissed via Cancel', (tester) async {
      final result = await pumpLauncher(tester);

      await tester.tap(find.text('launch'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectCreateForm), findsOneWidget);

      final messages = tester.element(find.byType(ProjectCreateForm)).messages;
      await tester.tap(find.text(messages.cancelButton));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectCreateForm), findsNothing);
      expect(result.value, isNull);
      verifyNever(
        () => mockProjectRepo.createProject(project: any(named: 'project')),
      );
    });
  });
}
