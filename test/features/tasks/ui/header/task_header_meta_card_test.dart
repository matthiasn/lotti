import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_category_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_creation_date_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_header_meta_card.dart';
import 'package:lotti/features/tasks/ui/header/task_language_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_priority_wrapper.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/task_progress_test_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';
import '../../../agents/test_utils.dart';

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

  testWidgets('TaskHeaderMetaCard renders date row and metadata items',
      (tester) async {
    final task = testTask;

    final overrides = <Override>[
      entryControllerProvider(id: task.meta.id).overrideWith(
        () => _TestEntryController(task),
      ),
    ];

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        child: TaskHeaderMetaCard(taskId: task.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TaskHeaderMetaCard), findsOneWidget);
    expect(find.byType(TaskCreationDateWidget), findsOneWidget);

    // All metadata wrappers should be present
    expect(find.byType(TaskPriorityWrapper), findsOneWidget);
    expect(find.byType(TaskCategoryWrapper), findsOneWidget);
    expect(find.byType(TaskLanguageWrapper), findsOneWidget);
  });

  testWidgets('TaskHeaderMetaCard keeps metadata visible on narrow layouts',
      (tester) async {
    final task = testTask;

    final overrides = <Override>[
      taskProgressControllerProvider(id: task.meta.id).overrideWith(
        () => TestTaskProgressController(
          progress: const Duration(hours: 1),
          estimate: const Duration(hours: 4),
        ),
      ),
      entryControllerProvider(id: task.meta.id).overrideWith(
        () => _TestEntryController(task),
      ),
    ];

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: overrides,
        mediaQueryData: const MediaQueryData(
          size: Size(360, 640),
        ),
        child: TaskHeaderMetaCard(taskId: task.meta.id),
      ),
    );
    await tester.pumpAndSettle();

    // Even on narrow layouts, all metadata items should remain visible.
    expect(find.byType(TaskPriorityWrapper), findsOneWidget);
    expect(find.byType(TaskCategoryWrapper), findsOneWidget);
    expect(find.byType(TaskLanguageWrapper), findsOneWidget);
  });

  group('TaskAgentChip', () {
    testWidgets('not visible when enableAgents flag is disabled',
        (tester) async {
      final task = testTask;

      final overrides = <Override>[
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
        configFlagProvider.overrideWith(
          (ref, flagName) => Stream.value(false),
        ),
        taskAgentProvider.overrideWith(
          (ref, taskId) async => null,
        ),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: TaskHeaderMetaCard(taskId: task.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      // The agent chip should not appear when the flag is disabled.
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets(
        'shows "Create Agent" label when flag is enabled and no agent exists',
        (tester) async {
      final task = testTask;

      final overrides = <Override>[
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
        configFlagProvider.overrideWith(
          (ref, flagName) => Stream.value(
            flagName == enableAgentsFlag,
          ),
        ),
        taskAgentProvider.overrideWith(
          (ref, taskId) async => null,
        ),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: TaskHeaderMetaCard(taskId: task.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskHeaderMetaCard));
      expect(
        find.text(context.messages.taskAgentCreateChipLabel),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets(
      'shows SizedBox.shrink during loading state',
      (tester) async {
        final task = testTask;

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) => Completer<AgentDomainEntity?>().future,
          ),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pump();

        // During loading, no agent chip icons should appear
        expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
        expect(find.byIcon(Icons.add), findsNothing);
      },
    );

    testWidgets(
      'shows SizedBox.shrink when taskAgent provider errors',
      (tester) async {
        final task = testTask;

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) =>
                Future<AgentDomainEntity?>.error(Exception('DB error')),
          ),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        // On error, no agent chip icons should appear
        expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
        expect(find.byIcon(Icons.add), findsNothing);
      },
    );

    testWidgets(
      'shows SizedBox.shrink when agent entity is not agent type',
      (tester) async {
        final task = testTask;
        // Return a state entity instead of identity — mapOrNull returns null
        final nonAgentEntity = makeTestState();

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => nonAgentEntity,
          ),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        // Non-agent entity is filtered out, no chip visible
        expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
        expect(find.byIcon(Icons.add), findsNothing);
      },
    );

    testWidgets('shows "Agent" label when flag is enabled and agent exists',
        (tester) async {
      final task = testTask;
      final agentEntity = makeTestIdentity();

      final overrides = <Override>[
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
        configFlagProvider.overrideWith(
          (ref, flagName) => Stream.value(
            flagName == enableAgentsFlag,
          ),
        ),
        taskAgentProvider.overrideWith(
          (ref, taskId) async => agentEntity,
        ),
        agentIsRunningProvider.overrideWith(
          (ref, agentId) => Stream.value(false),
        ),
        agentStateProvider.overrideWith(
          (ref, agentId) async => null,
        ),
      ];

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: overrides,
          child: TaskHeaderMetaCard(taskId: task.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(TaskHeaderMetaCard));
      expect(
        find.text(context.messages.taskAgentChipLabel),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets(
      'shows spinner instead of icon when agent is running',
      (tester) async {
        final task = testTask;
        final agentEntity = makeTestIdentity();

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => agentEntity,
          ),
          agentIsRunningProvider.overrideWith(
            (ref, agentId) => Stream.value(true),
          ),
          agentStateProvider.overrideWith(
            (ref, agentId) async => null,
          ),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        // Pump multiple times to let the stream provider and async providers
        // resolve through their loading → data transitions.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // Spinner should appear instead of the static icon.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);

        // Tooltip should show the running indicator label.
        final context = tester.element(find.byType(TaskHeaderMetaCard));
        expect(
          find.byTooltip(context.messages.agentRunningIndicator),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping "Create Agent" chip calls createTaskAgent and invalidates '
      'provider',
      (tester) async {
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

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => null,
          ),
          taskAgentServiceProvider.overrideWithValue(mockService),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(TaskHeaderMetaCard));
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
      },
    );

    testWidgets(
      'shows error snackbar when createTaskAgent throws',
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

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => null,
          ),
          taskAgentServiceProvider.overrideWithValue(mockService),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(TaskHeaderMetaCard));
        await tester.tap(
          find.text(context.messages.taskAgentCreateChipLabel),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('creation failed'), findsOneWidget);
      },
    );

    testWidgets(
      'create agent does nothing when entry state is null',
      (tester) async {
        final task = testTask;
        final mockService = MockTaskAgentService();

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            _NullEntryController.new,
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => null,
          ),
          taskAgentServiceProvider.overrideWithValue(mockService),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(TaskHeaderMetaCard));
        await tester.tap(
          find.text(context.messages.taskAgentCreateChipLabel),
        );
        await tester.pumpAndSettle();

        // createTaskAgent should NOT have been called
        verifyNever(
          () => mockService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    testWidgets(
      'create agent passes categoryId in allowedCategoryIds',
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

        final overrides = <Override>[
          entryControllerProvider(id: testTask.meta.id).overrideWith(
            () => _TestEntryController(taskWithCategory),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => null,
          ),
          taskAgentServiceProvider.overrideWithValue(mockService),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: testTask.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(TaskHeaderMetaCard));
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
      },
    );

    testWidgets(
      'tapping "Agent" chip navigates to AgentDetailPage',
      (tester) async {
        final task = testTask;
        final agentEntity = makeTestIdentity();

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => agentEntity,
          ),
          // Overrides needed by AgentDetailPage after navigation.
          agentIdentityProvider.overrideWith(
            (ref, agentId) async => agentEntity,
          ),
          agentStateProvider.overrideWith(
            (ref, agentId) async => null,
          ),
          agentReportProvider.overrideWith(
            (ref, agentId) async => null,
          ),
          agentRecentMessagesProvider.overrideWith(
            (ref, agentId) async => <AgentDomainEntity>[],
          ),
          agentIsRunningProvider.overrideWith(
            (ref, agentId) => Stream.value(false),
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
          templateForAgentProvider.overrideWith(
            (ref, agentId) async => null,
          ),
          agentTokenUsageRecordsProvider.overrideWith(
            (ref, agentId) async => <AgentDomainEntity>[],
          ),
          agentTokenUsageSummariesProvider.overrideWith(
            (ref, agentId) async => <AgentTokenUsageSummary>[],
          ),
          agentServiceProvider.overrideWithValue(MockAgentService()),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(TaskHeaderMetaCard));
        await tester.tap(find.text(context.messages.taskAgentChipLabel));
        await tester.pumpAndSettle();

        // After navigation, the AgentDetailPage should be on screen
        expect(find.byType(AgentDetailPage), findsOneWidget);
      },
    );

    testWidgets(
      'shows snackbar when no templates available',
      (tester) async {
        final task = testTask;
        final mockService = MockTaskAgentService();
        final mockTemplateService = MockAgentTemplateService();

        when(mockTemplateService.listTemplates).thenAnswer((_) async => []);

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => null,
          ),
          taskAgentServiceProvider.overrideWithValue(mockService),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(TaskHeaderMetaCard));
        await tester.tap(
          find.text(context.messages.taskAgentCreateChipLabel),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(context.messages.agentTemplateNoTemplates),
          findsOneWidget,
        );

        // createTaskAgent should NOT have been called
        verifyNever(
          () => mockService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    testWidgets(
      'shows "Run Now" button when agent exists and is not running',
      (tester) async {
        final task = testTask;
        final agentEntity = makeTestIdentity();
        final mockService = MockTaskAgentService();

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => agentEntity,
          ),
          agentIsRunningProvider.overrideWith(
            (ref, agentId) => Stream.value(false),
          ),
          agentStateProvider.overrideWith(
            (ref, agentId) async => null,
          ),
          taskAgentServiceProvider.overrideWithValue(mockService),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        // Play button should be visible.
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

        // Tap the play button.
        when(() => mockService.triggerReanalysis(any())).thenReturn(null);
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pumpAndSettle();

        verify(() => mockService.triggerReanalysis(agentEntity.agentId))
            .called(1);
      },
    );

    testWidgets(
      'hides "Run Now" button when agent is running',
      (tester) async {
        final task = testTask;
        final agentEntity = makeTestIdentity();

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => agentEntity,
          ),
          agentIsRunningProvider.overrideWith(
            (ref, agentId) => Stream.value(true),
          ),
          agentStateProvider.overrideWith(
            (ref, agentId) async => null,
          ),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // Play button should not be visible when running.
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      },
    );

    testWidgets(
      'shows countdown when nextWakeAt is in the future',
      (tester) async {
        // Use a fixed clock so the test is fully deterministic.
        final now = DateTime(2024, 3, 15, 12);
        await withClock(Clock.fixed(now), () async {
          final task = testTask;
          final agentEntity = makeTestIdentity();

          // nextWakeAt 90 seconds in the future → countdown "1:30".
          final nextWakeAt = now.add(const Duration(seconds: 90));
          final stateEntity = makeTestState(
            agentId: agentEntity.agentId,
            nextWakeAt: nextWakeAt,
          );

          final overrides = <Override>[
            entryControllerProvider(id: task.meta.id).overrideWith(
              () => _TestEntryController(task),
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(
                flagName == enableAgentsFlag,
              ),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => agentEntity,
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            agentStateProvider.overrideWith(
              (ref, agentId) async => stateEntity,
            ),
            taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          ];

          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: overrides,
              child: TaskHeaderMetaCard(taskId: task.meta.id),
            ),
          );
          await tester.pumpAndSettle();
          // Let the post-frame callback run and start the countdown.
          await tester.pump(const Duration(milliseconds: 100));

          // With 90s remaining the chip label and countdown pill are shown.
          final context = tester.element(find.byType(TaskHeaderMetaCard));
          final label = context.messages.taskAgentChipLabel;
          expect(find.text(label), findsOneWidget);
          expect(find.text('1:30'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'does not show countdown when nextWakeAt is in the past',
      (tester) async {
        // Use a fixed clock so the test is fully deterministic.
        final now = DateTime(2024, 3, 15, 12);
        await withClock(Clock.fixed(now), () async {
          final task = testTask;
          final agentEntity = makeTestIdentity();

          // nextWakeAt 100 seconds in the past → no countdown.
          final nextWakeAt = now.subtract(const Duration(seconds: 100));
          final stateEntity = makeTestState(
            agentId: agentEntity.agentId,
            nextWakeAt: nextWakeAt,
          );

          final overrides = <Override>[
            entryControllerProvider(id: task.meta.id).overrideWith(
              () => _TestEntryController(task),
            ),
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(
                flagName == enableAgentsFlag,
              ),
            ),
            taskAgentProvider.overrideWith(
              (ref, taskId) async => agentEntity,
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            agentStateProvider.overrideWith(
              (ref, agentId) async => stateEntity,
            ),
            taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          ];

          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: overrides,
              child: TaskHeaderMetaCard(taskId: task.meta.id),
            ),
          );
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(TaskHeaderMetaCard));
          // Should show just "Agent" without countdown.
          expect(
            find.text(context.messages.taskAgentChipLabel),
            findsOneWidget,
          );
          expect(
            find.textContaining(RegExp(r'\d:\d{2}')),
            findsNothing,
          );
        });
      },
    );

    testWidgets(
      'shows template selection bottom sheet when multiple templates',
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

        final overrides = <Override>[
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(
              flagName == enableAgentsFlag,
            ),
          ),
          taskAgentProvider.overrideWith(
            (ref, taskId) async => null,
          ),
          taskAgentServiceProvider.overrideWithValue(mockService),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
        ];

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: overrides,
            child: TaskHeaderMetaCard(taskId: task.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(TaskHeaderMetaCard));
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
      },
    );
  });
}
