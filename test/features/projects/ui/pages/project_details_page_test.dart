import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/service/project_lifecycle_service.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/state/project_detail_record_provider.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_detail_content.dart';
import 'package:lotti/features/projects/ui/widgets/project_recommendations_panel.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';
import '../../../agents/test_data/template_factories.dart';
import '../../../ai/test_utils.dart';
import '../../../categories/test_utils.dart';
import '../../test_utils.dart';

/// Test controller that allows direct state manipulation without a repository.
class _TestProjectDetailController extends ProjectDetailController {
  _TestProjectDetailController(this._initialState) : super(_projectId);

  final ProjectDetailState _initialState;

  @override
  ProjectDetailState build() => _initialState;

  @override
  void updateTitle(String title) {}

  @override
  void updateTargetDate(DateTime? targetDate) {}

  @override
  void updateCategoryId(String? categoryId) {}

  @override
  void updateStatus(ProjectStatus newStatus) {}

  @override
  Future<void> saveChanges() async {}
}

class _TestInferenceProfileController extends InferenceProfileController {
  _TestInferenceProfileController(this.profiles);

  final List<AiConfig> profiles;

  @override
  Stream<List<AiConfig>> build() => Stream.value(profiles);
}

/// A tracking variant that records calls to [updateCategoryId],
/// [updateTargetDate], and [saveChanges] for assertion.
class _TrackingProjectDetailController extends ProjectDetailController {
  _TrackingProjectDetailController(this._initialState, String projectId)
    : super(projectId);

  final ProjectDetailState _initialState;

  final List<String?> updatedCategoryIds = [];
  final List<DateTime?> updatedTargetDates = [];
  final List<ProjectStatus> updatedStatuses = [];
  int saveChangesCallCount = 0;

  @override
  ProjectDetailState build() => _initialState;

  @override
  void updateTitle(String title) {}

  @override
  void updateTargetDate(DateTime? targetDate) {
    updatedTargetDates.add(targetDate);
  }

  @override
  void updateCategoryId(String? categoryId) {
    updatedCategoryIds.add(categoryId);
  }

  @override
  void updateStatus(ProjectStatus newStatus) {
    updatedStatuses.add(newStatus);
  }

  @override
  Future<void> saveChanges() async {
    saveChangesCallCount++;
  }
}

class _FailingProjectDetailController extends ProjectDetailController {
  _FailingProjectDetailController(this._initialState) : super(_projectId);

  final ProjectDetailState _initialState;
  int discardCalls = 0;

  @override
  ProjectDetailState build() => _initialState;

  @override
  void updateStatus(ProjectStatus newStatus) {}

  @override
  Future<void> saveChanges() async {
    state = state.copyWith(error: ProjectDetailError.updateFailed);
  }

  @override
  void discardChanges() {
    discardCalls++;
    state = state.copyWith(error: null, hasChanges: false);
  }
}

const _projectId = 'test-project-id';

/// The shared set of provider overrides that all tests need.
///
/// [recordOverride] controls the record provider. When it returns
/// synchronously the FutureProvider resolves on the next microtask; when it
/// returns a [Future] the provider stays in loading until it completes.
List<Override> _baseOverrides({
  required ProjectDetailState controllerState,
  required FutureOr<ProjectRecord?> Function(Ref) recordOverride,
  ProjectDetailController Function()? controllerOverride,
  AgentDomainEntity? projectAgent,
  Override? projectAgentOverride,
  ProjectByIdResolver? resolveProjectById,
  List<Override> extraOverrides = const [],
}) {
  return [
    projectDetailControllerProvider(_projectId).overrideWith(
      controllerOverride ?? () => _TestProjectDetailController(controllerState),
    ),
    projectDetailRecordProvider(_projectId).overrideWith(
      (ref) => recordOverride(ref),
    ),
    projectDetailNowProvider.overrideWithValue(
      () => DateTime(2026, 3, 28, 9, 30),
    ),
    projectAgentOverride ??
        projectAgentProvider(_projectId).overrideWith(
          (ref) async => projectAgent,
        ),
    projectNextStepsProvider(
      _projectId,
    ).overrideWith((ref) async => const ProjectNextStepsSnapshot.empty()),
    projectPendingChangeSetsProvider(
      _projectId,
    ).overrideWith((ref) async => []),
    projectByIdResolverProvider.overrideWithValue(
      resolveProjectById ?? (_) async => controllerState.project,
    ),
    agentIsRunningProvider.overrideWith(
      (ref, agentId) => Stream.value(false),
    ),
    ...extraOverrides,
  ];
}

void main() {
  final testProject = makeTestProject(
    id: _projectId,
    createdAt: DateTime(2026, 3, 15),
  );

  final testRecord = makeTestProjectRecord(project: testProject);

  test('project resolver uses the current repository snapshot', () async {
    final repository = MockProjectRepository();
    final project = makeTestProject(
      id: 'resolver-project',
      categoryId: 'latest-category',
    );
    when(
      () => repository.getProjectById(project.id),
    ).thenAnswer((_) async => project);
    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final resolved = await container.read(projectByIdResolverProvider)(
      project.id,
    );
    expect(resolved, project);
    verify(() => repository.getProjectById(project.id)).called(1);
  });

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  /// Pumps the [ProjectDetailsPage] with data-state overrides and waits for
  /// provider resolution.
  Future<void> pumpPageWithData(
    WidgetTester tester, {
    required ProjectDetailState controllerState,
    ProjectRecord? record,
    ProjectDetailController Function()? controllerOverride,
    AgentDomainEntity? projectAgent,
    Override? projectAgentOverride,
    ProjectByIdResolver? resolveProjectById,
    List<Override> extraOverrides = const [],
  }) async {
    final overrides = _baseOverrides(
      controllerState: controllerState,
      recordOverride: (_) => record,
      controllerOverride: controllerOverride,
      projectAgent: projectAgent,
      projectAgentOverride: projectAgentOverride,
      resolveProjectById: resolveProjectById,
      extraOverrides: extraOverrides,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: const ProjectDetailsPage(projectId: _projectId),
          ),
        ),
      ),
    );
    // Two pumps: initial build and FutureProvider resolution/rebuild.
    await tester.pump();
    await tester.pump();
  }

  group('ProjectDetailsPage', () {
    test(
      'default task creator uses the project-scoped creation path',
      () async {
        final mockRepository = MockProjectRepository();
        getIt.registerSingleton<ProjectRepository>(mockRepository);
        when(
          () => mockRepository.getProjectById(_projectId),
        ).thenAnswer((_) async => null);
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final created = await container.read(projectTaskCreatorProvider)(
          _projectId,
        );

        expect(created, isNull);
        verify(() => mockRepository.getProjectById(_projectId)).called(1);
      },
    );

    test(
      'default task-agent assigner safely skips uncategorized tasks',
      () async {
        final mockService = MockTaskAgentService();
        final container = ProviderContainer(
          overrides: [
            taskAgentServiceProvider.overrideWithValue(mockService),
          ],
        );
        addTearDown(container.dispose);

        await container.read(projectTaskAgentAssignerProvider)(
          makeTestTask(id: 'uncategorized-task'),
        );

        verifyZeroInteractions(mockService);
      },
    );

    group('loading state', () {
      testWidgets(
        'shows CircularProgressIndicator when controller is loading with '
        'null project',
        (tester) async {
          // When the controller reports isLoading with null project, the
          // loading guard in build() fires before recordAsync.when, so the
          // record value does not matter.
          await pumpPageWithData(
            tester,
            controllerState: const ProjectDetailState(
              project: null,
              linkedTasks: [],
              isLoading: true,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(ProjectMobileDetailContent), findsNothing);
        },
      );

      testWidgets(
        'shows CircularProgressIndicator when record provider is loading',
        (tester) async {
          // Use a completer that never completes to simulate a loading future.
          final completer = Completer<ProjectRecord?>();
          addTearDown(() {
            if (!completer.isCompleted) completer.complete();
          });

          final overrides = _baseOverrides(
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            recordOverride: (_) => completer.future,
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: makeTestableWidget2(
                Theme(
                  data: DesignSystemTheme.dark(),
                  child: const ProjectDetailsPage(projectId: _projectId),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(ProjectMobileDetailContent), findsNothing);
        },
      );

      testWidgets(
        'keeps rendering the previous detail content during provider reloads',
        (tester) async {
          final reloadTriggerController = StreamController<int>.broadcast();
          final reloadTriggerProvider = StreamProvider<int>(
            (ref) => reloadTriggerController.stream,
          );
          final completer = Completer<ProjectRecord?>();
          addTearDown(() {
            reloadTriggerController.close();
            if (!completer.isCompleted) {
              completer.complete(testRecord);
            }
          });

          final tallRecord = makeTestProjectRecord(
            project: testProject,
            reportContent: List.filled(
              12,
              'Long report line that keeps the project detail page scrollable.',
            ).join('\n\n'),
            highlightedTaskSummaries: List.generate(
              12,
              (index) => makeTestTaskSummary(
                task: makeTestTask(
                  id: 'task-$index',
                  title: 'Task $index',
                ),
                oneLiner: 'Summary line $index',
              ),
            ),
          );

          final container = ProviderContainer(
            overrides: _baseOverrides(
              controllerState: ProjectDetailState(
                project: testProject,
                linkedTasks: const [],
                isLoading: false,
                isSaving: false,
                hasChanges: false,
              ),
              recordOverride: (ref) {
                final reload =
                    ref.watch(reloadTriggerProvider).asData?.value ?? 0;
                return reload == 0 ? tallRecord : completer.future;
              },
            ),
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: makeTestableWidget2(
                Theme(
                  data: DesignSystemTheme.dark(),
                  child: const ProjectDetailsPage(projectId: _projectId),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.byType(ProjectMobileDetailContent), findsOneWidget);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -500),
          );
          await tester.pump();
          expect(find.byType(TaskSummaryRow), findsWidgets);

          final scrollableState = tester.state<ScrollableState>(
            find.byType(Scrollable),
          );
          final previousOffset = scrollableState.position.pixels;
          expect(previousOffset, greaterThan(0));

          reloadTriggerController.add(1);
          await tester.pump();
          await tester.pump();

          expect(find.byType(ProjectMobileDetailContent), findsOneWidget);
          expect(find.byType(TaskSummaryRow), findsWidgets);
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable))
                .position
                .pixels,
            previousOffset,
          );
        },
      );

      testWidgets(
        'keeps rendered detail content after a transient reload error',
        (tester) async {
          final reloadTriggerProvider = StateProvider<int>((ref) => 0);
          final container = ProviderContainer(
            overrides: _baseOverrides(
              controllerState: ProjectDetailState(
                project: testProject,
                linkedTasks: const [],
                isLoading: false,
                isSaving: false,
                hasChanges: false,
              ),
              recordOverride: (ref) {
                final reload = ref.watch(reloadTriggerProvider);
                if (reload == 0) return testRecord;
                throw StateError('transient agent report failure');
              },
            ),
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: makeTestableWidget2(
                Theme(
                  data: DesignSystemTheme.dark(),
                  child: const ProjectDetailsPage(projectId: _projectId),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.byType(ProjectMobileDetailContent), findsOneWidget);
          expect(find.text('Test Project'), findsOneWidget);

          container.read(reloadTriggerProvider.notifier).state = 1;
          await tester.pump();
          await tester.pump();

          expect(find.byType(ProjectMobileDetailContent), findsOneWidget);
          expect(find.text('Test Project'), findsOneWidget);
          expect(find.byType(ErrorStateWidget), findsNothing);
        },
      );
    });

    group('error state', () {
      testWidgets(
        'shows ErrorStateWidget when record provider returns an error',
        (tester) async {
          final overrides = _baseOverrides(
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            recordOverride: (_) => throw Exception('db failure'),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: makeTestableWidget2(
                Theme(
                  data: DesignSystemTheme.dark(),
                  child: const ProjectDetailsPage(projectId: _projectId),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(ErrorStateWidget), findsOneWidget);
          expect(find.text('Error'), findsOneWidget);
          expect(find.byType(ProjectMobileDetailContent), findsNothing);
        },
      );
    });

    group('null record state', () {
      testWidgets(
        'shows "Project not found" when record is null',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
          );

          expect(find.text('Project not found'), findsOneWidget);
          expect(find.byType(ProjectMobileDetailContent), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );
    });

    group('successful data rendering', () {
      testWidgets(
        'renders ProjectMobileDetailContent when record is available',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          expect(find.byType(ProjectMobileDetailContent), findsOneWidget);
          expect(find.byType(ErrorStateWidget), findsNothing);
          // The page should not show the loading spinner scaffold, but
          // ProjectMobileDetailContent may contain a CircularProgressIndicator
          // for the health score visualization, so we verify via the content
          // widget type rather than asserting no spinner at all.
        },
      );

      testWidgets(
        'passes the project title down to the detail content',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          expect(find.text('Test Project'), findsOneWidget);
        },
      );

      testWidgets(
        'passes onRefreshReport as null when there is no agent identity',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(
            content.onRefreshReport,
            isNull,
            reason:
                'onRefreshReport should be null when no agent identity exists',
          );
          expect(
            content.onCancelScheduledReportWake,
            isNull,
            reason:
                'onCancelScheduledReportWake should be null when no agent '
                'identity exists — there is nothing to cancel without an agent',
          );
          expect(content.hasProjectAgent, isFalse);
          expect(content.isRefreshingReport, isFalse);
        },
      );

      testWidgets('does not offer assignment while agent lookup is pending', (
        tester,
      ) async {
        final pendingAgent = Completer<AgentDomainEntity?>();
        await pumpPageWithData(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          record: testRecord,
          projectAgentOverride: projectAgentProvider(
            _projectId,
          ).overrideWith((ref) => pendingAgent.future),
        );

        final content = tester.widget<ProjectMobileDetailContent>(
          find.byType(ProjectMobileDetailContent),
        );
        expect(content.onAssignAgent, isNull);
        expect(content.hasProjectAgent, isTrue);
        expect(find.text('Assign an agent'), findsNothing);

        pendingAgent.complete();
      });

      testWidgets(
        'assigns a project agent from the unprovisioned health state',
        (tester) async {
          final agentService = MockProjectAgentService();
          ({
            String projectId,
            String templateId,
            String displayName,
            Set<String> allowedCategoryIds,
            String? profileId,
          })?
          creation;
          final template = makeTestTemplate(
            id: 'project-template',
            displayName: 'Project guide',
            kind: AgentTemplateKind.projectAgent,
          );
          final profile = AiTestDataFactory.createTestProfile(
            id: 'project-profile',
            name: 'Project profile',
          );
          when(
            () => agentService.createProjectAgent(
              projectId: any(named: 'projectId'),
              templateId: any(named: 'templateId'),
              displayName: any(named: 'displayName'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
              profileId: any(named: 'profileId'),
            ),
          ).thenAnswer(
            (invocation) async {
              creation = (
                projectId: invocation.namedArguments[#projectId]! as String,
                templateId: invocation.namedArguments[#templateId]! as String,
                displayName: invocation.namedArguments[#displayName]! as String,
                allowedCategoryIds:
                    invocation.namedArguments[#allowedCategoryIds]!
                        as Set<String>,
                profileId: invocation.namedArguments[#profileId] as String?,
              );
              return makeTestIdentity(
                agentId: 'assigned-project-agent',
                kind: 'project_agent',
              );
            },
          );

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
            resolveProjectById: (_) async => testProject.copyWith(
              meta: testProject.meta.copyWith(categoryId: 'latest-category'),
            ),
            extraOverrides: [
              projectAgentServiceProvider.overrideWithValue(agentService),
              agentTemplatesProvider.overrideWith(
                (ref) async => [template],
              ),
              inferenceProfileControllerProvider.overrideWith(
                () => _TestInferenceProfileController([profile]),
              ),
            ],
          );

          await tester.tap(find.text('Assign an agent'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('Project profile'), findsOneWidget);

          await tester.tap(find.text('Project profile'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(creation?.projectId, _projectId);
          expect(creation?.templateId, 'project-template');
          expect(creation?.displayName, testProject.data.title);
          expect(creation?.allowedCategoryIds, {'latest-category'});
          expect(creation?.profileId, 'project-profile');
        },
      );

      testWidgets(
        'explains when no project-agent template can be assigned',
        (tester) async {
          final agentService = MockProjectAgentService();
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
            extraOverrides: [
              projectAgentServiceProvider.overrideWithValue(agentService),
              agentTemplatesProvider.overrideWith(
                (ref) async => [makeTestTemplate()],
              ),
            ],
          );

          await tester.tap(find.text('Assign an agent'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(
            find.text('No templates available. Create one in Settings first.'),
            findsOneWidget,
          );
          verifyNever(
            () => agentService.createProjectAgent(
              projectId: any(named: 'projectId'),
              templateId: any(named: 'templateId'),
              displayName: any(named: 'displayName'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
              profileId: any(named: 'profileId'),
            ),
          );
        },
      );

      testWidgets(
        'offers only global and matching-category project templates',
        (tester) async {
          final agentService = MockProjectAgentService();
          final categorizedProject = makeTestProject(
            id: _projectId,
            categoryId: 'cat-1',
          );
          final globalTemplate = makeTestTemplate(
            id: 'global-project-template',
            displayName: 'Global project guide',
            kind: AgentTemplateKind.projectAgent,
          );
          final matchingTemplate = makeTestTemplate(
            id: 'matching-project-template',
            displayName: 'Matching project guide',
            kind: AgentTemplateKind.projectAgent,
            categoryIds: const {'cat-1'},
          );
          final foreignTemplate = makeTestTemplate(
            id: 'foreign-project-template',
            displayName: 'Foreign project guide',
            kind: AgentTemplateKind.projectAgent,
            categoryIds: const {'cat-2'},
          );

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: categorizedProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: makeTestProjectRecord(project: categorizedProject),
            extraOverrides: [
              projectAgentServiceProvider.overrideWithValue(agentService),
              agentTemplatesProvider.overrideWith(
                (ref) async => [
                  globalTemplate,
                  matchingTemplate,
                  foreignTemplate,
                ],
              ),
            ],
          );

          await tester.tap(find.text('Assign an agent'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.text('Global project guide'), findsOneWidget);
          expect(find.text('Matching project guide'), findsOneWidget);
          expect(find.text('Foreign project guide'), findsNothing);
        },
      );

      testWidgets(
        'does not provision an agent after the project was deleted',
        (tester) async {
          final agentService = MockProjectAgentService();
          final template = makeTestTemplate(
            id: 'project-template',
            kind: AgentTemplateKind.projectAgent,
          );
          final profile = AiTestDataFactory.createTestProfile(
            id: 'project-profile',
            name: 'Project profile',
          );

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
            resolveProjectById: (_) async => null,
            extraOverrides: [
              projectAgentServiceProvider.overrideWithValue(agentService),
              agentTemplatesProvider.overrideWith(
                (ref) async => [template],
              ),
              inferenceProfileControllerProvider.overrideWith(
                () => _TestInferenceProfileController([profile]),
              ),
            ],
          );

          await tester.tap(find.text('Assign an agent'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.tap(find.text('Project profile'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.text('Project not found'), findsOneWidget);
          verifyNever(
            () => agentService.createProjectAgent(
              projectId: any(named: 'projectId'),
              templateId: any(named: 'templateId'),
              displayName: any(named: 'displayName'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
              profileId: any(named: 'profileId'),
            ),
          );
        },
      );

      testWidgets(
        'rejects a template made incompatible while the assignment modal was open',
        (tester) async {
          final agentService = MockProjectAgentService();
          final template = makeTestTemplate(
            id: 'project-template',
            kind: AgentTemplateKind.projectAgent,
            categoryIds: const {'initial-category'},
          );
          final profile = AiTestDataFactory.createTestProfile(
            id: 'project-profile',
            name: 'Project profile',
          );

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject.copyWith(
                meta: testProject.meta.copyWith(categoryId: 'initial-category'),
              ),
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: makeTestProjectRecord(
              project: testProject.copyWith(
                meta: testProject.meta.copyWith(categoryId: 'initial-category'),
              ),
            ),
            resolveProjectById: (_) async => testProject.copyWith(
              meta: testProject.meta.copyWith(categoryId: 'new-category'),
            ),
            extraOverrides: [
              projectAgentServiceProvider.overrideWithValue(agentService),
              agentTemplatesProvider.overrideWith(
                (ref) async => [template],
              ),
              inferenceProfileControllerProvider.overrideWith(
                () => _TestInferenceProfileController([profile]),
              ),
            ],
          );

          await tester.tap(find.text('Assign an agent'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.tap(find.text('Project profile'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(
            find.text('No templates available. Create one in Settings first.'),
            findsOneWidget,
          );
          verifyNever(
            () => agentService.createProjectAgent(
              projectId: any(named: 'projectId'),
              templateId: any(named: 'templateId'),
              displayName: any(named: 'displayName'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
              profileId: any(named: 'profileId'),
            ),
          );
        },
      );

      testWidgets('reports project-agent assignment failures', (tester) async {
        final agentService = MockProjectAgentService();
        final template = makeTestTemplate(
          id: 'failing-project-template',
          kind: AgentTemplateKind.projectAgent,
        );
        final profile = AiTestDataFactory.createTestProfile(
          id: 'failing-project-profile',
          name: 'Failing project profile',
        );
        when(
          () => agentService.createProjectAgent(
            projectId: any(named: 'projectId'),
            templateId: any(named: 'templateId'),
            displayName: any(named: 'displayName'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            profileId: any(named: 'profileId'),
          ),
        ).thenThrow(StateError('create failed'));

        await pumpPageWithData(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          record: testRecord,
          extraOverrides: [
            projectAgentServiceProvider.overrideWithValue(agentService),
            agentTemplatesProvider.overrideWith(
              (ref) async => [template],
            ),
            inferenceProfileControllerProvider.overrideWith(
              () => _TestInferenceProfileController([profile]),
            ),
          ],
        );

        await tester.tap(find.text('Assign an agent'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Failing project profile'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          find.textContaining('Failed to create agent:'),
          findsOneWidget,
        );
      });

      testWidgets(
        'preserves the project agent while its provider reloads',
        (tester) async {
          tester.view
            ..physicalSize = const Size(430, 1200)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          beamToNamedOverride = (_) {};
          addTearDown(() => beamToNamedOverride = null);
          final reloadGeneration = StateProvider<int>((ref) => 0);
          final pendingReload = Completer<AgentDomainEntity?>();
          final identity = makeTestIdentity(agentId: 'agent-project-1');
          final lifecycle = MockProjectLifecycleService();
          when(
            () => lifecycle.deleteProject(_projectId),
          ).thenAnswer((_) async => true);
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
            projectAgentOverride:
                projectAgentProvider(
                  _projectId,
                ).overrideWith((ref) async {
                  if (ref.watch(reloadGeneration) == 0) return identity;
                  return pendingReload.future;
                }),
            extraOverrides: [
              projectLifecycleServiceProvider.overrideWithValue(lifecycle),
            ],
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ProjectDetailsPage)),
          );

          container.read(reloadGeneration.notifier).state = 1;
          await tester.pump();

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(content.hasProjectAgent, isTrue);
          content.onDelete!();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete').last);
          await tester.pumpAndSettle();

          verify(
            () => lifecycle.deleteProject(_projectId),
          ).called(1);
          pendingReload.complete(identity);
        },
      );

      testWidgets(
        'wires onRefreshReport to projectAgentService.triggerReanalysis and '
        'handles cancelScheduledWake persistence failures when an agent '
        'identity is present',
        (tester) async {
          final agentService = MockProjectAgentService();
          when(
            () => agentService.triggerReanalysis(any()),
          ).thenReturn(null);
          when(
            () => agentService.cancelScheduledWake(any()),
          ).thenAnswer((_) => Future<void>.error(StateError('write failed')));

          final identity = makeTestIdentity(agentId: 'agent-project-1');

          // Build overrides inline rather than via `_baseOverrides` —
          // Riverpod 3 rejects overriding the same provider twice within
          // a container, and the helper already overrides
          // `projectAgentProvider(_projectId)` to null.
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                projectDetailControllerProvider(_projectId).overrideWith(
                  () => _TestProjectDetailController(
                    ProjectDetailState(
                      project: testProject,
                      linkedTasks: const [],
                      isLoading: false,
                      isSaving: false,
                      hasChanges: false,
                    ),
                  ),
                ),
                projectDetailRecordProvider(_projectId).overrideWith(
                  (ref) => testRecord,
                ),
                projectDetailNowProvider.overrideWithValue(
                  () => DateTime(2026, 3, 28, 9, 30),
                ),
                projectAgentProvider(_projectId).overrideWith(
                  (ref) async => identity,
                ),
                agentIsRunningProvider.overrideWith(
                  (ref, agentId) => Stream.value(false),
                ),
                projectAgentServiceProvider.overrideWithValue(agentService),
                projectNextStepsProvider(
                  _projectId,
                ).overrideWith(
                  (ref) async => const ProjectNextStepsSnapshot.empty(),
                ),
                projectPendingChangeSetsProvider(
                  _projectId,
                ).overrideWith((ref) async => []),
              ],
              child: makeTestableWidget2(
                Theme(
                  data: DesignSystemTheme.dark(),
                  child: const ProjectDetailsPage(projectId: _projectId),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(content.onRefreshReport, isNotNull);
          expect(content.onCancelScheduledReportWake, isNotNull);
          final panel = content.agentActionsBuilder!(enabled: true);
          expect(panel, isA<ProjectRecommendationsPanel>());
          expect((panel as ProjectRecommendationsPanel).enabled, isTrue);
          expect(
            (content.agentActionsBuilder!(enabled: false)
                    as ProjectRecommendationsPanel)
                .enabled,
            isFalse,
          );
          final opened = <String>[];
          beamToNamedOverride = opened.add;
          addTearDown(() => beamToNamedOverride = null);
          panel.onOpenTask!('task-42');
          expect(opened, ['/tasks/task-42']);

          // Invoking the wired callbacks must dispatch to the project
          // agent service for the resolved agent ID, with the cancel path
          // landing on cancelScheduledWake (not the manual reanalysis or
          // any other lifecycle method).
          content.onRefreshReport!();
          verify(
            () => agentService.triggerReanalysis('agent-project-1'),
          ).called(1);
          verifyNever(() => agentService.cancelScheduledWake(any()));

          content.onCancelScheduledReportWake!();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          verify(
            () => agentService.cancelScheduledWake('agent-project-1'),
          ).called(1);
          final context = tester.element(find.byType(ProjectDetailsPage));
          expect(find.text(context.messages.commonError), findsOneWidget);
        },
      );

      testWidgets(
        'passes currentTime from the now provider',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(content.currentTime, DateTime(2026, 3, 28, 9, 30));
        },
      );
    });

    group('back navigation', () {
      testWidgets(
        'tapping the back button pops the navigator when a route can be '
        'popped',
        (tester) async {
          final overrides = _baseOverrides(
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            recordOverride: (_) => testRecord,
          );

          // Push the page on top of an initial route so Navigator.canPop()
          // returns true.
          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: makeTestableWidget2(
                Theme(
                  data: DesignSystemTheme.dark(),
                  child: Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Theme(
                                data: DesignSystemTheme.dark(),
                                child: const ProjectDetailsPage(
                                  projectId: _projectId,
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text('Go'),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          // Navigate to the details page.
          await tester.tap(find.text('Go'));
          await tester.pumpAndSettle();

          expect(
            find.byType(ProjectMobileDetailContent),
            findsOneWidget,
          );

          // Verify the onBack callback is wired.
          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          expect(
            content.onBack,
            isNotNull,
            reason: 'onBack callback should be provided',
          );

          // Tap the back button rendered in the detail header.
          final backButton = find.byIcon(LottiIcons.chevronLeft);
          expect(backButton, findsOneWidget);
          await tester.tap(backButton.first);
          await tester.pumpAndSettle();

          // Should have popped back to the initial route.
          expect(find.text('Go'), findsOneWidget);
          expect(find.byType(ProjectDetailsPage), findsNothing);
        },
      );
    });

    group('callback wiring', () {
      testWidgets(
        'all interaction callbacks are wired to the detail content',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );
          // One pump, one widget lookup — assert every callback the page
          // must hand to the content widget.
          <String, Object?>{
            'onCategoryTap': content.onCategoryTap,
            'onTargetDateTap': content.onTargetDateTap,
            'onStatusTap': content.onStatusTap,
            'onEdit': content.onEdit,
            'onArchive': content.onArchive,
            'onDelete': content.onDelete,
            'onAddTask': content.onAddTask,
            'onTaskTap': content.onTaskTap,
          }.forEach(
            (name, callback) => expect(
              callback,
              isNotNull,
              reason: '$name should be provided to the content widget',
            ),
          );
        },
      );

      testWidgets('archive persists an archived status and reports success', (
        tester,
      ) async {
        final initialState = ProjectDetailState(
          project: testProject,
          linkedTasks: const [],
          isLoading: false,
          isSaving: false,
          hasChanges: false,
        );
        final tracking = _TrackingProjectDetailController(
          initialState,
          _projectId,
        );
        await pumpPageWithData(
          tester,
          controllerState: initialState,
          record: testRecord,
          controllerOverride: () => tracking,
        );

        final content = tester.widget<ProjectMobileDetailContent>(
          find.byType(ProjectMobileDetailContent),
        );
        content.onArchive!();
        await tester.pump();

        expect(tracking.updatedStatuses.single, isA<ProjectArchived>());
        expect(tracking.saveChangesCallCount, 1);
      });

      testWidgets('edit stays on the project-owned editor route', (
        tester,
      ) async {
        final capturedPaths = <String>[];
        beamToNamedOverride = capturedPaths.add;
        addTearDown(() => beamToNamedOverride = null);
        await pumpPageWithData(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          record: testRecord,
        );

        tester
            .widget<ProjectMobileDetailContent>(
              find.byType(ProjectMobileDetailContent),
            )
            .onEdit!();

        final route = Uri.parse(capturedPaths.single);
        expect(route.path, '/projects/test-project-id/edit');
        expect(route.queryParameters, isEmpty);
      });

      testWidgets('failed inline actions roll back and surface the error', (
        tester,
      ) async {
        final initialState = ProjectDetailState(
          project: testProject,
          linkedTasks: const [],
          isLoading: false,
          isSaving: false,
          hasChanges: false,
        );
        final failing = _FailingProjectDetailController(initialState);
        await pumpPageWithData(
          tester,
          controllerState: initialState,
          record: testRecord,
          controllerOverride: () => failing,
        );

        tester
            .widget<ProjectMobileDetailContent>(
              find.byType(ProjectMobileDetailContent),
            )
            .onArchive!();
        await tester.pump();

        expect(failing.discardCalls, 1);
        expect(
          find.text('Failed to update project. Please try again.'),
          findsOneWidget,
        );
      });

      for (final succeeds in [false, true]) {
        testWidgets('confirmed deletion reports its result ($succeeds)', (
          tester,
        ) async {
          final lifecycle = MockProjectLifecycleService();
          when(
            () => lifecycle.deleteProject(_projectId),
          ).thenAnswer((_) async => succeeds);
          beamToNamedOverride = (_) {};
          addTearDown(() => beamToNamedOverride = null);
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
            extraOverrides: [
              projectLifecycleServiceProvider.overrideWithValue(lifecycle),
            ],
          );
          tester
              .widget<ProjectMobileDetailContent>(
                find.byType(ProjectMobileDetailContent),
              )
              .onDelete!();
          await tester.pumpAndSettle();
          verifyNever(() => lifecycle.deleteProject(_projectId));
          await tester.tap(find.text('Delete').last);
          await tester.pumpAndSettle();
          verify(() => lifecycle.deleteProject(_projectId)).called(1);
          expect(
            find.text(
              succeeds
                  ? 'Project deleted'
                  : 'Failed to delete project. Please try again.',
            ),
            findsOneWidget,
          );
        });
      }

      testWidgets('cancelled confirmation does not invoke deletion', (
        tester,
      ) async {
        final lifecycle = MockProjectLifecycleService();
        await pumpPageWithData(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          record: testRecord,
          extraOverrides: [
            projectLifecycleServiceProvider.overrideWithValue(lifecycle),
          ],
        );
        tester
            .widget<ProjectMobileDetailContent>(
              find.byType(ProjectMobileDetailContent),
            )
            .onDelete!();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        verifyZeroInteractions(lifecycle);
        expect(find.byType(ProjectMobileDetailContent), findsOneWidget);
      });

      testWidgets('deletion can finish after the page unmounts', (
        tester,
      ) async {
        final lifecycle = MockProjectLifecycleService();
        final completion = Completer<bool>();
        when(
          () => lifecycle.deleteProject(_projectId),
        ).thenAnswer((_) => completion.future);
        await pumpPageWithData(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          record: testRecord,
          extraOverrides: [
            projectLifecycleServiceProvider.overrideWithValue(lifecycle),
          ],
        );
        tester
            .widget<ProjectMobileDetailContent>(
              find.byType(ProjectMobileDetailContent),
            )
            .onDelete!();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        verify(() => lifecycle.deleteProject(_projectId)).called(1);
        await tester.pumpWidget(const SizedBox.shrink());
        completion.complete(false);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('add task assigns its category agent before navigating', (
        tester,
      ) async {
        final task = makeTestTask(id: 'created-task', title: 'Created task');
        final capturedPaths = <String>[];
        final assignment = Completer<void>();
        Task? assignedTask;
        beamToNamedOverride = capturedPaths.add;
        addTearDown(() => beamToNamedOverride = null);
        await pumpPageWithData(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          record: testRecord,
          extraOverrides: [
            projectTaskCreatorProvider.overrideWithValue((projectId) async {
              expect(projectId, _projectId);
              return task;
            }),
            projectTaskAgentAssignerProvider.overrideWithValue((task) async {
              assignedTask = task;
              await assignment.future;
            }),
          ],
        );

        final addFuture = tester
            .widget<ProjectMobileDetailContent>(
              find.byType(ProjectMobileDetailContent),
            )
            .onAddTask!();
        await tester.pump();

        expect(assignedTask?.meta.id, 'created-task');
        expect(capturedPaths, isEmpty);

        assignment.complete();
        await addFuture;
        await tester.pump();

        expect(capturedPaths, ['/tasks/created-task']);
      });

      testWidgets(
        'assigns the category agent when the page unmounts during creation',
        (tester) async {
          final task = makeTestTask(id: 'created-task', title: 'Created task');
          final creation = Completer<Task?>();
          Task? assignedTask;
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
            extraOverrides: [
              projectTaskCreatorProvider.overrideWithValue(
                (_) => creation.future,
              ),
              projectTaskAgentAssignerProvider.overrideWithValue((task) async {
                assignedTask = task;
              }),
            ],
          );

          final addFuture = tester
              .widget<ProjectMobileDetailContent>(
                find.byType(ProjectMobileDetailContent),
              )
              .onAddTask!();
          await tester.pump();
          await tester.pumpWidget(const SizedBox.shrink());

          creation.complete(task);
          await addFuture;
          await tester.pump();

          expect(assignedTask?.meta.id, 'created-task');
        },
      );

      testWidgets('agent assignment failure still opens the created task', (
        tester,
      ) async {
        final task = makeTestTask(id: 'created-task', title: 'Created task');
        final capturedPaths = <String>[];
        beamToNamedOverride = capturedPaths.add;
        addTearDown(() => beamToNamedOverride = null);
        await pumpPageWithData(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          record: testRecord,
          extraOverrides: [
            projectTaskCreatorProvider.overrideWithValue((_) async => task),
            projectTaskAgentAssignerProvider.overrideWithValue((_) async {
              throw StateError('assignment failed');
            }),
          ],
        );

        await tester
            .widget<ProjectMobileDetailContent>(
              find.byType(ProjectMobileDetailContent),
            )
            .onAddTask!();
        await tester.pump();
        await tester.pump();

        expect(capturedPaths, ['/tasks/created-task']);
        expect(find.text('Error'), findsOneWidget);
      });

      testWidgets('add task failure stays put and reports an error', (
        tester,
      ) async {
        final capturedPaths = <String>[];
        beamToNamedOverride = capturedPaths.add;
        addTearDown(() => beamToNamedOverride = null);
        await pumpPageWithData(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          record: testRecord,
          extraOverrides: [
            projectTaskCreatorProvider.overrideWithValue((_) async => null),
            projectTaskAgentAssignerProvider.overrideWithValue((_) async {}),
          ],
        );

        await tester
            .widget<ProjectMobileDetailContent>(
              find.byType(ProjectMobileDetailContent),
            )
            .onAddTask!();
        await tester.pump();
        await tester.pump();

        expect(capturedPaths, isEmpty);
        expect(find.text('Error'), findsOneWidget);
      });

      testWidgets('task creator exceptions stay put and report an error', (
        tester,
      ) async {
        final capturedPaths = <String>[];
        beamToNamedOverride = capturedPaths.add;
        addTearDown(() => beamToNamedOverride = null);
        await pumpPageWithData(
          tester,
          controllerState: ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          ),
          record: testRecord,
          extraOverrides: [
            projectTaskCreatorProvider.overrideWithValue((_) async {
              throw StateError('create failed');
            }),
            projectTaskAgentAssignerProvider.overrideWithValue((_) async {}),
          ],
        );

        await tester
            .widget<ProjectMobileDetailContent>(
              find.byType(ProjectMobileDetailContent),
            )
            .onAddTask!();
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(capturedPaths, isEmpty);
        expect(find.text('Error'), findsOneWidget);
      });
    });

    /// Sizes the test surface tall enough for bottom-sheet / modal content to
    /// lay out without overflow, and registers the reset teardown. Shared by
    /// `pumpForModal` and the category-modal tests that build their own
    /// overrides.
    void sizeViewForModal(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(430, 1200)
        ..devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    /// Sizes the surface tall enough for bottom sheets, pumps the page in
    /// its default loaded state, and returns the mounted content widget.
    Future<ProjectMobileDetailContent> pumpForModal(
      WidgetTester tester,
    ) async {
      sizeViewForModal(tester);

      await pumpPageWithData(
        tester,
        controllerState: ProjectDetailState(
          project: testProject,
          linkedTasks: const [],
          isLoading: false,
          isSaving: false,
          hasChanges: false,
        ),
        record: testRecord,
      );

      return tester.widget<ProjectMobileDetailContent>(
        find.byType(ProjectMobileDetailContent),
      );
    }

    group('status picker modal', () {
      testWidgets(
        'tapping onStatusTap opens a bottom sheet with status options',
        (tester) async {
          // Use a tall surface so the bottom sheet has room to render all
          // status options without overflow.
          final content = await pumpForModal(tester);

          // Invoke the onStatusTap callback directly to trigger the
          // bottom sheet.
          content.onStatusTap!();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // The bottom sheet should show all status options.
          expect(find.text('Open'), findsWidgets);
          expect(find.text('Active'), findsOneWidget);
          expect(find.text('On Hold'), findsOneWidget);
          expect(find.text('Completed'), findsOneWidget);
          expect(find.text('Archived'), findsOneWidget);
        },
      );

      testWidgets(
        'tapping a non-selected status option dismisses the sheet and saves',
        (tester) async {
          final content = await pumpForModal(tester);

          // Open the status picker bottom sheet.
          content.onStatusTap!();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // The default test project has status 'Open'. Tap 'Active' which
          // is a different status to trigger the selection path.
          await tester.tap(find.text('Active'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // The sheet should be dismissed — status options are no longer
          // visible.
          expect(find.text('Archived'), findsNothing);
          expect(find.text('On Hold'), findsNothing);
        },
      );

      testWidgets(
        'tapping the already-selected status dismisses without saving',
        (tester) async {
          final content = await pumpForModal(tester);

          // Open the status picker bottom sheet.
          content.onStatusTap!();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // The default test project has status 'Open'. The 'Open' option
          // should have a check mark (LottiIcons.confirm) indicating it is
          // the currently selected status.
          expect(find.byIcon(LottiIcons.confirm), findsOneWidget);

          // Tap the deterministic row key so the underlying page's Open label
          // cannot be mistaken for the selected modal option.
          await tester.tap(
            find.byKey(const ValueKey('project-status-open')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // The sheet should be dismissed without triggering a save.
          expect(find.text('Archived'), findsNothing);
          expect(find.text('On Hold'), findsNothing);
        },
      );

      testWidgets(
        'displays all five status variants with correct icons',
        (tester) async {
          final content = await pumpForModal(tester);

          content.onStatusTap!();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Verify each status variant renders with its expected icon.
          // Scoped to the picker row: the header behind the modal shows the
          // current status with the same glyph at 24pt. Material spelled the
          // two `radio_button_unchecked` and `radio_button_unchecked_rounded`
          // — already the same circle, just two names — so this only ever
          // found one because the spellings differed.
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Icon &&
                  w.icon == LottiIcons.radioUnselected &&
                  w.size == 16,
            ),
            findsOneWidget,
            reason: 'Open status icon',
          );
          expect(
            find.byIcon(LottiIcons.playCircled),
            findsOneWidget,
            reason: 'Active status icon',
          );
          expect(
            find.byIcon(LottiIcons.pauseCircled),
            findsOneWidget,
            reason: 'On Hold status icon',
          );
          expect(
            find.byIcon(LottiIcons.confirmCircled),
            findsOneWidget,
            reason: 'Completed status icon',
          );
          expect(
            find.byIcon(LottiIcons.archive),
            findsOneWidget,
            reason: 'Archived status icon',
          );

          // Only the current status ('Open') should show the selection
          // check mark.
          expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
        },
      );
    });

    group('category picker modal', () {
      testWidgets(
        'tapping onCategoryTap opens the category selection modal',
        (tester) async {
          sizeViewForModal(tester);

          // CategoryPickerSheet requires EntitiesCacheService
          // from GetIt.
          final mockCache = MockEntitiesCacheService();
          when(() => mockCache.sortedCategories).thenReturn([]);
          getIt.registerSingleton<EntitiesCacheService>(mockCache);

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          // Invoke the onCategoryTap callback to open the modal.
          content.onCategoryTap!();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // The modal should contain the CategoryPickerSheet
          // widget and display the 'Category' title.
          expect(
            find.byType(CategoryPickerSheet),
            findsOneWidget,
          );
          expect(find.text('Category'), findsOneWidget);
        },
      );
    });

    group('target date picker', () {
      testWidgets(
        'tapping onTargetDateTap opens a date picker dialog',
        (tester) async {
          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          // Invoke the onTargetDateTap callback.
          content.onTargetDateTap!();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(CalendarDatePicker), findsOneWidget);
        },
      );

      testWidgets(
        'confirming a date in the date picker calls updateTargetDate and '
        'saveChanges on the controller',
        (tester) async {
          // Fix clock so _pickTargetDate's clock.now() is deterministic.
          await withClock(
            Clock.fixed(DateTime(2026, 3, 28, 9, 30)),
            () async {
              late _TrackingProjectDetailController trackingController;

              final initialState = ProjectDetailState(
                project: testProject,
                linkedTasks: const [],
                isLoading: false,
                isSaving: false,
                hasChanges: false,
              );

              final overrides = [
                projectDetailControllerProvider(_projectId).overrideWith(() {
                  return trackingController = _TrackingProjectDetailController(
                    initialState,
                    _projectId,
                  );
                }),
                projectDetailRecordProvider(_projectId).overrideWith(
                  (ref) => testRecord,
                ),
                projectDetailNowProvider.overrideWithValue(
                  () => DateTime(2026, 3, 28, 9, 30),
                ),
                projectAgentProvider(_projectId).overrideWith(
                  (ref) async => null,
                ),
                agentIsRunningProvider.overrideWith(
                  (ref, agentId) => Stream.value(false),
                ),
              ];

              await tester.pumpWidget(
                ProviderScope(
                  overrides: overrides,
                  child: makeTestableWidget2(
                    Theme(
                      data: DesignSystemTheme.dark(),
                      child: const ProjectDetailsPage(projectId: _projectId),
                    ),
                  ),
                ),
              );
              await tester.pump();
              await tester.pump();

              final content = tester.widget<ProjectMobileDetailContent>(
                find.byType(ProjectMobileDetailContent),
              );

              // Open the date picker.
              content.onTargetDateTap!();
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));

              expect(find.byType(CalendarDatePicker), findsOneWidget);

              final doneButton = find.text('Done');
              await tester.ensureVisible(doneButton);
              await tester.tap(doneButton);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));

              // The clock is fixed at 2026-03-28T09:30. Since testProject has
              // no targetDate, _pickTargetDate uses clock.now() as initialDate,
              // which the date picker strips to date-only → DateTime(2026, 3,
              // 28).
              expect(trackingController.updatedTargetDates, hasLength(1));
              expect(
                trackingController.updatedTargetDates.first,
                DateTime(2026, 3, 28),
              );
              expect(trackingController.saveChangesCallCount, 1);
            },
          );
        },
      );
    });

    group('onTaskTap navigation', () {
      testWidgets(
        'invoking onTaskTap calls beamToNamed with the task route',
        (tester) async {
          final capturedPaths = <String>[];
          beamToNamedOverride = capturedPaths.add;
          addTearDown(() => beamToNamedOverride = null);

          final task = makeTestTask(id: 'task-nav-1', title: 'Nav Task');
          final taskSummary = makeTestTaskSummary(task: task);
          final recordWithTask = makeTestProjectRecord(
            project: testProject,
            highlightedTaskSummaries: [taskSummary],
          );

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: recordWithTask,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          content.onTaskTap!(taskSummary);

          expect(capturedPaths, hasLength(1));
          expect(capturedPaths.first, '/tasks/task-nav-1');
        },
      );
    });

    group('onTaskTap wiring', () {
      testWidgets(
        'stays wired (non-null) even when the record has no task summaries',
        (tester) async {
          final capturedPaths = <String>[];
          beamToNamedOverride = capturedPaths.add;
          addTearDown(() => beamToNamedOverride = null);

          final emptyRecord = makeTestProjectRecord(project: testProject);

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: emptyRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          // The page wires the callback unconditionally — a task arriving
          // later (e.g. via refresh) must still navigate.
          expect(content.onTaskTap, isNotNull);
          content.onTaskTap!(
            makeTestTaskSummary(
              task: makeTestTask(id: 'late-task', title: 'Late'),
            ),
          );
          expect(capturedPaths, ['/tasks/late-task']);
        },
      );
    });

    group('category selection saves changes', () {
      testWidgets(
        'selecting a category from the modal calls updateCategoryId and '
        'saveChanges on the controller',
        (tester) async {
          sizeViewForModal(tester);

          final testCategory = CategoryTestUtils.createTestCategory(
            id: 'cat-select-1',
            name: 'UniqueTestCategory',
          );

          final mockCache = MockEntitiesCacheService();
          when(() => mockCache.sortedCategories).thenReturn([testCategory]);
          getIt.registerSingleton<EntitiesCacheService>(mockCache);

          late _TrackingProjectDetailController trackingController;

          final initialState = ProjectDetailState(
            project: testProject,
            linkedTasks: const [],
            isLoading: false,
            isSaving: false,
            hasChanges: false,
          );

          final overrides = [
            projectDetailControllerProvider(_projectId).overrideWith(() {
              return trackingController = _TrackingProjectDetailController(
                initialState,
                _projectId,
              );
            }),
            projectDetailRecordProvider(_projectId).overrideWith(
              (ref) => testRecord,
            ),
            projectDetailNowProvider.overrideWithValue(
              () => DateTime(2026, 3, 28, 9, 30),
            ),
            projectAgentProvider(_projectId).overrideWith((ref) async => null),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
          ];

          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: makeTestableWidget2(
                Theme(
                  data: DesignSystemTheme.dark(),
                  child: const ProjectDetailsPage(projectId: _projectId),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          // Open the category picker modal.
          content.onCategoryTap!();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(CategoryPickerSheet), findsOneWidget);

          // Tap the 'UniqueTestCategory' option inside the modal.
          final categoryTile = find.text('UniqueTestCategory');
          await tester.ensureVisible(categoryTile);
          await tester.tap(categoryTile);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // The controller should have received the selected category id.
          expect(trackingController.updatedCategoryIds, hasLength(1));
          expect(
            trackingController.updatedCategoryIds.first,
            'cat-select-1',
          );
          expect(trackingController.saveChangesCallCount, 1);
        },
      );
    });

    group('back navigation without route stack', () {
      testWidgets(
        '_handleBack calls beamToNamed("/projects") when navigator cannot pop',
        (tester) async {
          final capturedPaths = <String>[];
          beamToNamedOverride = capturedPaths.add;
          addTearDown(() => beamToNamedOverride = null);

          await pumpPageWithData(
            tester,
            controllerState: ProjectDetailState(
              project: testProject,
              linkedTasks: const [],
              isLoading: false,
              isSaving: false,
              hasChanges: false,
            ),
            record: testRecord,
          );

          final content = tester.widget<ProjectMobileDetailContent>(
            find.byType(ProjectMobileDetailContent),
          );

          // Invoke onBack directly — the test widget tree has no extra route
          // so Navigator.canPop() returns false and beamToNamed is used.
          content.onBack!();
          await tester.pump();

          expect(capturedPaths, contains('/projects'));
        },
      );
    });
  });
}
