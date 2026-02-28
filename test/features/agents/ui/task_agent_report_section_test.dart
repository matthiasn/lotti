import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/task_agent_report_section.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../test_helper.dart';
import '../test_utils.dart';

class _TestEntryController extends EntryController {
  _TestEntryController(this._task);

  final Task _task;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: _task,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) async => null;
}

/// Helper to build a [TaskAgentReportSection] with commonly needed overrides.
Widget _buildSubject({
  required String taskId,
  required List<Override> overrides,
}) {
  return RiverpodWidgetTestBench(
    overrides: overrides,
    child: TaskAgentReportSection(taskId: taskId),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersistenceLogic mockPersistenceLogic;
  late MockEditorStateService mockEditorStateService;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(<String>{});

    mockPersistenceLogic = MockPersistenceLogic();
    mockEditorStateService = MockEditorStateService();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<TimeService>(TimeService());
  });

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
    if (!getIt.isRegistered<EntitiesCacheService>()) {
      getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    }
  });

  tearDown(() {
    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  /// Builds common overrides for the "agents enabled" scenario with an
  /// existing agent identity.
  List<Override> agentExistsOverrides({
    AgentIdentityEntity? agent,
    AgentDomainEntity? report,
    AgentDomainEntity? template,
    bool isRunning = false,
    AgentDomainEntity? agentState,
  }) {
    final identity = agent ?? makeTestIdentity();
    return [
      configFlagProvider.overrideWith(
        (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
      ),
      taskAgentProvider.overrideWith(
        (ref, taskId) async => identity,
      ),
      agentReportProvider.overrideWith(
        (ref, agentId) async => report,
      ),
      templateForAgentProvider.overrideWith(
        (ref, agentId) async => template,
      ),
      agentIsRunningProvider.overrideWith(
        (ref, agentId) => Stream.value(isRunning),
      ),
      agentStateProvider.overrideWith(
        (ref, agentId) async => agentState,
      ),
    ];
  }

  group('TaskAgentReportSection - config flag', () {
    testWidgets('renders nothing when enableAgents flag is disabled',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(false),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => null,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });
  });

  group('TaskAgentReportSection - no agent', () {
    testWidgets('shows create agent chip when no agent exists', (tester) async {
      final task = testTask;
      await tester.pumpWidget(
        _buildSubject(
          taskId: task.meta.id,
          overrides: [
            entryControllerProvider(id: task.meta.id).overrideWith(
              () => _TestEntryController(task),
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => null,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskAgentReportSection));
      expect(
        find.text(context.messages.taskAgentCreateChipLabel),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('renders nothing during loading state', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) => Completer<AgentDomainEntity?>().future,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('renders nothing when provider errors', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) =>
                  Future<AgentDomainEntity?>.error(Exception('DB error')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('renders nothing when entity is not agent type',
        (tester) async {
      final nonAgentEntity = makeTestState();
      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => nonAgentEntity,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });
  });

  group('TaskAgentReportSection - create agent', () {
    testWidgets('tapping create chip calls createTaskAgent', (tester) async {
      final task = testTask;
      final mockService = MockTaskAgentService();
      final mockTemplateService = MockAgentTemplateService();
      final identity = makeTestIdentity();

      when(mockTemplateService.listTemplates)
          .thenAnswer((_) async => [makeTestTemplate()]);
      when(
        () => mockService.createTaskAgent(
          taskId: any(named: 'taskId'),
          templateId: any(named: 'templateId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      ).thenAnswer((_) async => identity);

      await tester.pumpWidget(
        _buildSubject(
          taskId: task.meta.id,
          overrides: [
            entryControllerProvider(id: task.meta.id).overrideWith(
              () => _TestEntryController(task),
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => null,
            ),
            taskAgentServiceProvider.overrideWithValue(mockService),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskAgentReportSection));
      await tester.tap(
        find.text(context.messages.taskAgentCreateChipLabel),
      );
      await tester.pumpAndSettle();

      verify(
        () => mockService.createTaskAgent(
          taskId: task.meta.id,
          templateId: any(named: 'templateId'),
          allowedCategoryIds: <String>{},
        ),
      ).called(1);
    });

    testWidgets('shows error snackbar when createTaskAgent throws',
        (tester) async {
      final task = testTask;
      final mockService = MockTaskAgentService();
      final mockTemplateService = MockAgentTemplateService();

      when(mockTemplateService.listTemplates)
          .thenAnswer((_) async => [makeTestTemplate()]);
      when(
        () => mockService.createTaskAgent(
          taskId: any(named: 'taskId'),
          templateId: any(named: 'templateId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      ).thenThrow(Exception('creation failed'));

      await tester.pumpWidget(
        _buildSubject(
          taskId: task.meta.id,
          overrides: [
            entryControllerProvider(id: task.meta.id).overrideWith(
              () => _TestEntryController(task),
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => null,
            ),
            taskAgentServiceProvider.overrideWithValue(mockService),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskAgentReportSection));
      await tester.tap(
        find.text(context.messages.taskAgentCreateChipLabel),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('creation failed'), findsOneWidget);
    });

    testWidgets('create agent does nothing when entry state is null',
        (tester) async {
      final task = testTask;
      final mockService = MockTaskAgentService();

      await tester.pumpWidget(
        _buildSubject(
          taskId: task.meta.id,
          overrides: [
            entryControllerProvider(id: task.meta.id).overrideWith(
              _NullEntryController.new,
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => null,
            ),
            taskAgentServiceProvider.overrideWithValue(mockService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskAgentReportSection));
      await tester.tap(
        find.text(context.messages.taskAgentCreateChipLabel),
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => mockService.createTaskAgent(
          taskId: any(named: 'taskId'),
          templateId: any(named: 'templateId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      );
    });

    testWidgets('create agent passes categoryId in allowedCategoryIds',
        (tester) async {
      const categoryId = 'cat-123';
      final taskWithCategory = Task(
        data: TaskData(
          status: TaskStatus.open(
            id: 'status_id',
            createdAt: DateTime(2022, 7, 7, 11),
            utcOffset: 60,
          ),
          title: 'Task with category',
          statusHistory: [],
          dateTo: DateTime(2022, 7, 7, 9),
          dateFrom: DateTime(2022, 7, 7, 9),
        ),
        meta: Metadata(
          id: testTask.meta.id,
          createdAt: DateTime(2022, 7, 7, 9),
          dateFrom: DateTime(2022, 7, 7, 9),
          dateTo: DateTime(2022, 7, 7, 11),
          updatedAt: DateTime(2022, 7, 7, 11),
          categoryId: categoryId,
        ),
        entryText: const EntryText(plainText: 'task text'),
      );

      final mockService = MockTaskAgentService();
      final mockTemplateService = MockAgentTemplateService();
      final identity = makeTestIdentity();

      when(
        () => mockTemplateService.listTemplatesForCategory(categoryId),
      ).thenAnswer((_) async => [makeTestTemplate()]);
      when(mockTemplateService.listTemplates)
          .thenAnswer((_) async => [makeTestTemplate()]);
      when(
        () => mockService.createTaskAgent(
          taskId: any(named: 'taskId'),
          templateId: any(named: 'templateId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      ).thenAnswer((_) async => identity);

      await tester.pumpWidget(
        _buildSubject(
          taskId: testTask.meta.id,
          overrides: [
            entryControllerProvider(id: testTask.meta.id).overrideWith(
              () => _TestEntryController(taskWithCategory),
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => null,
            ),
            taskAgentServiceProvider.overrideWithValue(mockService),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskAgentReportSection));
      await tester.tap(
        find.text(context.messages.taskAgentCreateChipLabel),
      );
      await tester.pumpAndSettle();

      verify(
        () => mockService.createTaskAgent(
          taskId: testTask.meta.id,
          templateId: any(named: 'templateId'),
          allowedCategoryIds: {categoryId},
        ),
      ).called(1);
    });

    testWidgets('shows snackbar when no templates available', (tester) async {
      final task = testTask;
      final mockService = MockTaskAgentService();
      final mockTemplateService = MockAgentTemplateService();

      when(mockTemplateService.listTemplates).thenAnswer((_) async => []);

      await tester.pumpWidget(
        _buildSubject(
          taskId: task.meta.id,
          overrides: [
            entryControllerProvider(id: task.meta.id).overrideWith(
              () => _TestEntryController(task),
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => null,
            ),
            taskAgentServiceProvider.overrideWithValue(mockService),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskAgentReportSection));
      await tester.tap(
        find.text(context.messages.taskAgentCreateChipLabel),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateNoTemplates),
        findsOneWidget,
      );
    });

    testWidgets('shows template selection bottom sheet for multiple templates',
        (tester) async {
      final task = testTask;
      final mockService = MockTaskAgentService();
      final mockTemplateService = MockAgentTemplateService();
      final identity = makeTestIdentity();

      final laura = makeTestTemplate(
        id: 'tpl-laura',
        agentId: 'tpl-laura',
        displayName: 'Laura',
      );
      final tom = makeTestTemplate(
        id: 'tpl-tom',
        agentId: 'tpl-tom',
        displayName: 'Tom',
      );

      when(mockTemplateService.listTemplates)
          .thenAnswer((_) async => [laura, tom]);
      when(
        () => mockService.createTaskAgent(
          taskId: any(named: 'taskId'),
          templateId: any(named: 'templateId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      ).thenAnswer((_) async => identity);

      await tester.pumpWidget(
        _buildSubject(
          taskId: task.meta.id,
          overrides: [
            entryControllerProvider(id: task.meta.id).overrideWith(
              () => _TestEntryController(task),
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => null,
            ),
            taskAgentServiceProvider.overrideWithValue(mockService),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskAgentReportSection));
      await tester.tap(
        find.text(context.messages.taskAgentCreateChipLabel),
      );
      await tester.pumpAndSettle();

      // Bottom sheet should show both template names
      expect(find.text('Laura'), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);
      expect(
        find.text(context.messages.agentTemplateSelectTitle),
        findsOneWidget,
      );

      // Select Laura
      await tester.tap(find.text('Laura'));
      await tester.pumpAndSettle();

      verify(
        () => mockService.createTaskAgent(
          taskId: task.meta.id,
          templateId: 'tpl-laura',
          allowedCategoryIds: <String>{},
        ),
      ).called(1);
    });
  });

  group('TaskAgentReportSection - agent header controls', () {
    testWidgets('shows agent icon and report title when agent exists',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: agentExistsOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskAgentReportSection));
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
      expect(
        find.textContaining(context.messages.agentReportSectionTitle),
        findsOneWidget,
      );
    });

    testWidgets('shows spinner when agent is running', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: agentExistsOverrides(isRunning: true),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Robot icon stays stable on the left; spinner is on the right
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets('shows refresh button when agent is idle', (tester) async {
      final mockService = MockTaskAgentService();
      final agentEntity = makeTestIdentity();

      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: [
            ...agentExistsOverrides(agent: agentEntity),
            taskAgentServiceProvider.overrideWithValue(mockService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      // Tap the refresh button.
      when(() => mockService.triggerReanalysis(any())).thenReturn(null);
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();

      verify(() => mockService.triggerReanalysis(agentEntity.agentId))
          .called(1);
    });

    testWidgets('hides refresh button when agent is running', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: agentExistsOverrides(isRunning: true),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    });

    testWidgets('shows countdown when nextWakeAt is in the future',
        (tester) async {
      final now = DateTime(2024, 3, 15, 12);
      await withClock(Clock.fixed(now), () async {
        final agentEntity = makeTestIdentity();
        final nextWakeAt = now.add(const Duration(seconds: 90));
        final stateEntity = makeTestState(
          agentId: agentEntity.agentId,
          nextWakeAt: nextWakeAt,
        );

        await tester.pumpWidget(
          _buildSubject(
            taskId: 'task-1',
            overrides: [
              ...agentExistsOverrides(
                agent: agentEntity,
                agentState: stateEntity,
              ),
              taskAgentServiceProvider
                  .overrideWithValue(MockTaskAgentService()),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('1:30'), findsOneWidget);
      });
    });

    testWidgets('does not show countdown when nextWakeAt is in the past',
        (tester) async {
      final now = DateTime(2024, 3, 15, 12);
      await withClock(Clock.fixed(now), () async {
        final agentEntity = makeTestIdentity();
        final nextWakeAt = now.subtract(const Duration(seconds: 100));
        final stateEntity = makeTestState(
          agentId: agentEntity.agentId,
          nextWakeAt: nextWakeAt,
        );

        await tester.pumpWidget(
          _buildSubject(
            taskId: 'task-1',
            overrides: [
              ...agentExistsOverrides(
                agent: agentEntity,
                agentState: stateEntity,
              ),
              taskAgentServiceProvider
                  .overrideWithValue(MockTaskAgentService()),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(RegExp(r'\d:\d{2}')),
          findsNothing,
        );
      });
    });

    testWidgets('during countdown shows play-now, pill, cancel; hides refresh',
        (tester) async {
      final now = DateTime(2024, 3, 15, 12);
      await withClock(Clock.fixed(now), () async {
        final agentEntity = makeTestIdentity();
        final nextWakeAt = now.add(const Duration(seconds: 90));
        final stateEntity = makeTestState(
          agentId: agentEntity.agentId,
          nextWakeAt: nextWakeAt,
        );
        final mockService = MockTaskAgentService();

        await tester.pumpWidget(
          _buildSubject(
            taskId: 'task-1',
            overrides: [
              ...agentExistsOverrides(
                agent: agentEntity,
                agentState: stateEntity,
              ),
              taskAgentServiceProvider.overrideWithValue(mockService),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));

        // During countdown: play button, pill, cancel X visible; refresh hidden
        expect(find.text('1:30'), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsNothing);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Tap cancel
        when(() => mockService.cancelScheduledWake(any())).thenReturn(null);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        verify(() => mockService.cancelScheduledWake(agentEntity.agentId))
            .called(1);
      });
    });

    testWidgets(
        'cancel prevents countdown re-seed until provider clears nextWakeAt',
        (tester) async {
      final now = DateTime(2024, 3, 15, 12);
      await withClock(Clock.fixed(now), () async {
        final agentEntity = makeTestIdentity();
        final nextWakeAt = now.add(const Duration(seconds: 90));
        final stateEntity = makeTestState(
          agentId: agentEntity.agentId,
          nextWakeAt: nextWakeAt,
        );
        final mockService = MockTaskAgentService();

        await tester.pumpWidget(
          _buildSubject(
            taskId: 'task-1',
            overrides: [
              ...agentExistsOverrides(
                agent: agentEntity,
                agentState: stateEntity,
              ),
              taskAgentServiceProvider.overrideWithValue(mockService),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));

        // Countdown visible before cancel.
        expect(find.text('1:30'), findsOneWidget);

        // Cancel the countdown.
        when(() => mockService.cancelScheduledWake(any())).thenReturn(null);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        // Countdown gone, refresh button should appear instead.
        expect(find.byIcon(Icons.close), findsNothing);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      });
    });

    testWidgets(
        'spinner shown and countdown hidden when agent transitions to running',
        (tester) async {
      final now = DateTime(2024, 3, 15, 12);
      await withClock(Clock.fixed(now), () async {
        final agentEntity = makeTestIdentity();
        final nextWakeAt = now.add(const Duration(seconds: 90));
        final stateEntity = makeTestState(
          agentId: agentEntity.agentId,
          nextWakeAt: nextWakeAt,
        );

        await tester.pumpWidget(
          _buildSubject(
            taskId: 'task-1',
            overrides: agentExistsOverrides(
              agent: agentEntity,
              agentState: stateEntity,
              isRunning: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // Running spinner should be shown, countdown buttons hidden.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
        expect(find.byIcon(Icons.close), findsNothing);
      });
    });

    testWidgets('play-now button during countdown triggers reanalysis',
        (tester) async {
      final now = DateTime(2024, 3, 15, 12);
      await withClock(Clock.fixed(now), () async {
        final agentEntity = makeTestIdentity();
        final nextWakeAt = now.add(const Duration(seconds: 90));
        final stateEntity = makeTestState(
          agentId: agentEntity.agentId,
          nextWakeAt: nextWakeAt,
        );
        final mockService = MockTaskAgentService();

        await tester.pumpWidget(
          _buildSubject(
            taskId: 'task-1',
            overrides: [
              ...agentExistsOverrides(
                agent: agentEntity,
                agentState: stateEntity,
              ),
              taskAgentServiceProvider.overrideWithValue(mockService),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));

        // Play button visible during countdown.
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

        when(() => mockService.triggerReanalysis(any())).thenReturn(null);
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pump();

        verify(() => mockService.triggerReanalysis(agentEntity.agentId))
            .called(1);
      });
    });
  });

  group('TaskAgentReportSection - report content', () {
    testWidgets('renders report content when agent has report', (tester) async {
      final report = makeTestReport(
        content: '## 📋 TLDR\nGood progress on task.\n\n'
            '## ✅ Achieved\n- Item A\n',
      );

      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: agentExistsOverrides(report: report),
        ),
      );
      await tester.pumpAndSettle();

      final markdowns =
          tester.widgetList<GptMarkdown>(find.byType(GptMarkdown)).toList();
      expect(markdowns, isNotEmpty);
      expect(markdowns.first.data, contains('TLDR'));
      expect(markdowns.first.data, contains('Good progress'));
    });

    testWidgets('renders no report content when report is empty',
        (tester) async {
      final report = makeTestReport(
        content: '',
      );

      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: agentExistsOverrides(report: report),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GptMarkdown), findsNothing);
    });

    testWidgets('renders no report content when report is null',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: agentExistsOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GptMarkdown), findsNothing);
    });
  });

  group('TaskAgentReportSection - template header', () {
    testWidgets('header shows template name when template exists',
        (tester) async {
      final template = makeTestTemplate(
        id: 'tpl-1',
        agentId: 'tpl-1',
        displayName: 'Laura',
      );

      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: agentExistsOverrides(
            report: makeTestReport(
              content: '## 📋 TLDR\nSome content.',
            ),
            template: template,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Laura'), findsOneWidget);
      // Chevron removed — tapping title navigates instead
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('tapping title navigates to agent detail page', (tester) async {
      final agentEntity = makeTestIdentity();
      final template = makeTestTemplate(
        id: 'tpl-1',
        agentId: 'tpl-1',
        displayName: 'Laura',
      );

      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: [
            ...agentExistsOverrides(agent: agentEntity, template: template),
            // Overrides needed by AgentDetailPage
            agentIdentityProvider.overrideWith(
              (ref, agentId) async => agentEntity,
            ),
            agentRecentMessagesProvider.overrideWith(
              (ref, agentId) async => <AgentDomainEntity>[],
            ),
            agentReportHistoryProvider.overrideWith(
              (ref, agentId) async => <AgentDomainEntity>[],
            ),
            agentObservationMessagesProvider.overrideWith(
              (ref, agentId) async => <AgentDomainEntity>[],
            ),
            agentMessagesByThreadProvider.overrideWith(
              (ref, agentId) async => <String, List<AgentDomainEntity>>{},
            ),
            agentTokenUsageRecordsProvider.overrideWith(
              (ref, agentId) async => <AgentDomainEntity>[],
            ),
            agentTokenUsageSummariesProvider.overrideWith(
              (ref, agentId) async => <AgentTokenUsageSummary>[],
            ),
            agentServiceProvider.overrideWithValue(MockAgentService()),
            taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Laura'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentDetailPage), findsOneWidget);
    });

    testWidgets(
        'tapping agent icon navigates to AgentDetailPage when no template',
        (tester) async {
      final agentEntity = makeTestIdentity();
      await tester.pumpWidget(
        _buildSubject(
          taskId: 'task-1',
          overrides: [
            ...agentExistsOverrides(agent: agentEntity),
            // Overrides needed by AgentDetailPage
            agentIdentityProvider.overrideWith(
              (ref, agentId) async => agentEntity,
            ),
            agentRecentMessagesProvider.overrideWith(
              (ref, agentId) async => <AgentDomainEntity>[],
            ),
            agentReportHistoryProvider.overrideWith(
              (ref, agentId) async => <AgentDomainEntity>[],
            ),
            agentObservationMessagesProvider.overrideWith(
              (ref, agentId) async => <AgentDomainEntity>[],
            ),
            agentMessagesByThreadProvider.overrideWith(
              (ref, agentId) async => <String, List<AgentDomainEntity>>{},
            ),
            agentTokenUsageRecordsProvider.overrideWith(
              (ref, agentId) async => <AgentDomainEntity>[],
            ),
            agentTokenUsageSummariesProvider.overrideWith(
              (ref, agentId) async => <AgentTokenUsageSummary>[],
            ),
            agentServiceProvider.overrideWithValue(MockAgentService()),
            taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.smart_toy_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(AgentDetailPage), findsOneWidget);
    });
  });

  group('TaskAgentReportSection - template selection edge cases', () {
    testWidgets(
        'dismissing bottom sheet without selecting does not create agent',
        (tester) async {
      final task = testTask;
      final mockService = MockTaskAgentService();
      final mockTemplateService = MockAgentTemplateService();

      final laura = makeTestTemplate(
        id: 'tpl-laura',
        agentId: 'tpl-laura',
        displayName: 'Laura',
      );
      final tom = makeTestTemplate(
        id: 'tpl-tom',
        agentId: 'tpl-tom',
        displayName: 'Tom',
      );

      when(mockTemplateService.listTemplates)
          .thenAnswer((_) async => [laura, tom]);

      await tester.pumpWidget(
        _buildSubject(
          taskId: task.meta.id,
          overrides: [
            entryControllerProvider(id: task.meta.id).overrideWith(
              () => _TestEntryController(task),
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => null,
            ),
            taskAgentServiceProvider.overrideWithValue(mockService),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskAgentReportSection));
      await tester.tap(
        find.text(context.messages.taskAgentCreateChipLabel),
      );
      await tester.pumpAndSettle();

      // Bottom sheet is shown
      expect(find.text('Laura'), findsOneWidget);

      // Dismiss the bottom sheet by tapping the modal barrier
      await tester.tap(find.byType(ModalBarrier).last);
      await tester.pumpAndSettle();

      // createTaskAgent must NOT be called
      verifyNever(
        () => mockService.createTaskAgent(
          taskId: any(named: 'taskId'),
          templateId: any(named: 'templateId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      );
    });

    testWidgets('falls back to listTemplates when category templates are empty',
        (tester) async {
      const categoryId = 'cat-123';
      final taskWithCategory = Task(
        data: TaskData(
          status: TaskStatus.open(
            id: 'status_id',
            createdAt: DateTime(2022, 7, 7, 11),
            utcOffset: 60,
          ),
          title: 'Task with category',
          statusHistory: [],
          dateTo: DateTime(2022, 7, 7, 9),
          dateFrom: DateTime(2022, 7, 7, 9),
        ),
        meta: Metadata(
          id: testTask.meta.id,
          createdAt: DateTime(2022, 7, 7, 9),
          dateFrom: DateTime(2022, 7, 7, 9),
          dateTo: DateTime(2022, 7, 7, 11),
          updatedAt: DateTime(2022, 7, 7, 11),
          categoryId: categoryId,
        ),
        entryText: const EntryText(plainText: 'task text'),
      );

      final mockService = MockTaskAgentService();
      final mockTemplateService = MockAgentTemplateService();
      final identity = makeTestIdentity();

      // Category-specific returns empty → falls back to listTemplates
      when(
        () => mockTemplateService.listTemplatesForCategory(categoryId),
      ).thenAnswer((_) async => []);
      when(mockTemplateService.listTemplates)
          .thenAnswer((_) async => [makeTestTemplate()]);
      when(
        () => mockService.createTaskAgent(
          taskId: any(named: 'taskId'),
          templateId: any(named: 'templateId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      ).thenAnswer((_) async => identity);

      await tester.pumpWidget(
        _buildSubject(
          taskId: testTask.meta.id,
          overrides: [
            entryControllerProvider(id: testTask.meta.id).overrideWith(
              () => _TestEntryController(taskWithCategory),
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => null,
            ),
            taskAgentServiceProvider.overrideWithValue(mockService),
            agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskAgentReportSection));
      await tester.tap(
        find.text(context.messages.taskAgentCreateChipLabel),
      );
      await tester.pumpAndSettle();

      // listTemplatesForCategory was called first
      verify(
        () => mockTemplateService.listTemplatesForCategory(categoryId),
      ).called(1);
      // Fell back to listTemplates
      verify(mockTemplateService.listTemplates).called(1);
      // Created agent with the fallback template
      verify(
        () => mockService.createTaskAgent(
          taskId: testTask.meta.id,
          templateId: any(named: 'templateId'),
          allowedCategoryIds: {categoryId},
        ),
      ).called(1);
    });
  });
}
