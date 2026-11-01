import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/assign_agent_cta_part.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';
import '../../test_data/ai_config_factories.dart';
import '../../test_data/entity_factories.dart';
import '../../test_data/template_factories.dart';

/// Tests for the AI summary card's "Assign Agent" CTA path. The CTA
/// drives `_createTaskAgent` in `assign_agent_cta_part.dart`, which
/// handles three branches:
///
/// * the entry resolves to a non-`Task` (or null) — short-circuit
/// * templates are unavailable — warning toast, no agent created
/// * the template service throws — error toast, no agent created
/// * the full success path — a category-scoped template lookup, the
///   creation modal opening, and `createTaskAgent` being dispatched
///   with the task's category in `allowedCategoryIds`
class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build() async => null;
}

/// Emits a fixed list of inference profiles so the creation modal's
/// profile page renders selectable rows.
class _FakeInferenceProfileController extends InferenceProfileController {
  _FakeInferenceProfileController(this._profiles);

  final List<AiConfig> _profiles;

  @override
  Stream<List<AiConfig>> build() => Stream.value(_profiles);
}

class _TaskEntryController extends EntryController {
  _TaskEntryController(this._task);

  final Task _task;

  @override
  Future<EntryState?> build() async {
    return EntryState.saved(
      entryId: id,
      entry: _task,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<TimeService>(TimeService());
        final mockEntitiesCacheService = MockEntitiesCacheService();
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        when(() => mockEntitiesCacheService.sortedLabels).thenReturn([]);
        when(
          () => mockEntitiesCacheService.getLabelById(any()),
        ).thenReturn(null);
        getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('AiSummaryCard – Assign Agent CTA paths', () {
    testWidgets(
      'tapping CTA when the entry is not a Task short-circuits',
      (tester) async {
        final templateService = MockAgentTemplateService();
        final taskAgentService = MockTaskAgentService();
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              configFlagProvider.overrideWith(
                (ref, flagName) => Stream.value(true),
              ),
              taskAgentProvider.overrideWith((ref, id) async => null),
              entryControllerProvider(
                'task-001',
              ).overrideWith(_NullEntryController.new),
              journalDbProvider.overrideWithValue(
                _dbReturning('task-001', null),
              ),
              agentTemplateServiceProvider.overrideWith(
                (ref) => templateService,
              ),
              taskAgentServiceProvider.overrideWith(
                (ref) => taskAgentService,
              ),
            ],
            child: const AiSummaryCard(taskId: 'task-001'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Assign Agent'));
        await tester.pumpAndSettle();

        // Neither the templates lookup nor the create path fires when
        // the entry can't be resolved as a Task. Tearoffs break
        // mocktail's invocation recording, so the closure form is
        // intentional even though it has no arguments.
        // ignore: unnecessary_lambdas
        verifyNever(() => templateService.listTemplates());
        verifyNever(() => templateService.listTemplatesForCategory(any()));
        verifyNever(
          () => taskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    testWidgets(
      'no available templates skips the create path',
      (tester) async {
        final templateService = MockAgentTemplateService();
        when(
          // ignore: unnecessary_lambdas
          () => templateService.listTemplates(),
        ).thenAnswer((_) async => []);
        when(
          () => templateService.listTemplatesForCategory(any()),
        ).thenAnswer((_) async => []);
        final taskAgentService = MockTaskAgentService();

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              configFlagProvider.overrideWith(
                (ref, flagName) => Stream.value(true),
              ),
              taskAgentProvider.overrideWith((ref, id) async => null),
              entryControllerProvider(
                testTask.meta.id,
              ).overrideWith(() => _TaskEntryController(testTask)),
              journalDbProvider.overrideWithValue(
                _dbReturning(testTask.meta.id, testTask),
              ),
              agentTemplateServiceProvider.overrideWith(
                (ref) => templateService,
              ),
              taskAgentServiceProvider.overrideWith(
                (ref) => taskAgentService,
              ),
            ],
            child: AiSummaryCard(taskId: testTask.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Assign Agent'));
        await tester.pumpAndSettle();

        // `testTask` has no categoryId, so the CTA skips the
        // category-scoped lookup and falls straight through to the
        // global `listTemplates()` path. The empty result
        // short-circuits before `createTaskAgent` is reached.
        verifyNever(() => templateService.listTemplatesForCategory(any()));
        // ignore: unnecessary_lambdas
        verify(() => templateService.listTemplates()).called(1);
        verifyNever(
          () => taskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    testWidgets(
      'a thrown templateService swallows the error and keeps the CTA',
      (tester) async {
        final templateService = MockAgentTemplateService();
        when(
          // ignore: unnecessary_lambdas
          () => templateService.listTemplates(),
        ).thenAnswer((_) => Future.error(Exception('templates exploded')));
        when(
          () => templateService.listTemplatesForCategory(any()),
        ).thenAnswer((_) => Future.error(Exception('templates exploded')));
        final taskAgentService = MockTaskAgentService();

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              configFlagProvider.overrideWith(
                (ref, flagName) => Stream.value(true),
              ),
              taskAgentProvider.overrideWith((ref, id) async => null),
              entryControllerProvider(
                testTask.meta.id,
              ).overrideWith(() => _TaskEntryController(testTask)),
              journalDbProvider.overrideWithValue(
                _dbReturning(testTask.meta.id, testTask),
              ),
              agentTemplateServiceProvider.overrideWith(
                (ref) => templateService,
              ),
              taskAgentServiceProvider.overrideWith(
                (ref) => taskAgentService,
              ),
            ],
            child: AiSummaryCard(taskId: testTask.meta.id),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Assign Agent'));
        await tester.pumpAndSettle();

        // The thrown error is caught inside `_createTaskAgent`. The
        // CTA stays on screen — no agent was attached.
        verifyNever(
          () => taskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
        expect(find.text('Assign Agent'), findsOneWidget);
      },
    );

    testWidgets(
      'showAssignTaskAgentPicker opens the same flow the card does — the task '
      "page's first-run block calls it directly rather than duplicating it",
      (tester) async {
        const categoryId = 'cat-123';
        final harness = _SuccessPathHarness.create(categoryId: categoryId);

        await tester.pumpWidget(
          harness.build(
            child: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showAssignTaskAgentPicker(
                  context,
                  ref,
                  harness.task.meta.id,
                ),
                child: const Text('open picker'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('open picker'));
        await tester.pumpAndSettle();

        expect(find.text('Solo'), findsOneWidget);
      },
    );

    testWidgets(
      'success path: category lookup, modal, then createTaskAgent + invalidate',
      (tester) async {
        const categoryId = 'cat-123';
        final harness = _SuccessPathHarness.create(categoryId: categoryId);

        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Assign Agent'));
        await tester.pumpAndSettle();

        // A single available template auto-skips the template page; the
        // modal opens straight onto the profile page (line 74 reached, so
        // the modal is on screen).
        expect(find.text('Solo'), findsOneWidget);

        // Selecting the profile pops the modal with a result, driving
        // `service.createTaskAgent(...)` and the subsequent invalidate.
        harness.attachAgent();
        await tester.tap(find.text('Solo'));
        await tester.pumpAndSettle();

        // The category-scoped lookup ran (categoryId != null branch); the
        // global fallback was never needed.
        verify(
          () => harness.templateService.listTemplatesForCategory(categoryId),
        ).called(1);
        // ignore: unnecessary_lambdas
        verifyNever(() => harness.templateService.listTemplates());

        // createTaskAgent is dispatched with the picked template/profile and
        // the task's category folded into allowedCategoryIds. mocktail returns
        // captured args in the order the captureAny matchers appear in the
        // verify call: allowedCategoryIds, then templateId, then profileId.
        final captured = verify(
          () => harness.taskAgentService.createTaskAgent(
            taskId: harness.task.meta.id,
            allowedCategoryIds: captureAny(named: 'allowedCategoryIds'),
            templateId: captureAny(named: 'templateId'),
            profileId: captureAny(named: 'profileId'),
            setupOrigin: AgentInferenceSetupOrigin.user,
          ),
        ).captured;
        expect(captured, [
          {categoryId},
          'tpl-success',
          'prof-success',
        ]);

        // After a successful create the provider was invalidated and now
        // resolves to an attached agent, so the CTA is gone and the summary
        // shell has replaced it.
        expect(find.text('Assign Agent'), findsNothing);
      },
    );
  });

  group('AssignAgentCta.event – assigning an agent to an existing event', () {
    testWidgets(
      'offers an event agent, not a task one: event hint, event templates, '
      'createEventAgent with the category, then the card re-reads the agent',
      (tester) async {
        const categoryId = 'cat-events';
        final harness = _EventHarness.create(categoryId: categoryId);

        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();

        expect(
          find.text(
            "Writes a recap from the event's photos and notes with built-in AI.",
          ),
          findsOneWidget,
        );
        expect(
          find.text('Drafts steps and summaries with built-in AI.'),
          findsNothing,
        );

        await tester.tap(find.text('Assign Agent'));
        await tester.pumpAndSettle();

        // The category offers a task template and an event template; only
        // the event one is assignable here, so the picker skips straight to
        // the profile page.
        expect(find.text('Solo'), findsOneWidget);

        harness.attachAgent();
        await tester.tap(find.text('Solo'));
        await tester.pumpAndSettle();

        // The picked template and profile, the event's category as the
        // agent's scope, and the default content gate (no awaitContent
        // override): the creation wake runs at once if the event already has
        // a photo or note.
        verify(
          () => harness.eventAgentService.createEventAgent(
            eventId: harness.event.meta.id,
            templateId: 'tpl-event',
            profileId: 'prof-success',
            allowedCategoryIds: {categoryId},
          ),
        ).called(1);

        // The invalidated provider re-resolved to the new agent, so the
        // offer is replaced by what the host renders for an attached agent.
        expect(find.text('Assign Agent'), findsNothing);
        expect(find.text('agent attached'), findsOneWidget);
      },
    );

    testWidgets('an entry that is not an event creates nothing', (
      tester,
    ) async {
      final harness = _EventHarness.create(
        categoryId: 'cat-events',
        entity: testTask,
      );

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assign Agent'));
      await tester.pumpAndSettle();

      verifyNever(
        () => harness.templateService.listTemplatesForCategory(any()),
      );
      verifyNever(
        () => harness.eventAgentService.createEventAgent(
          eventId: any(named: 'eventId'),
          templateId: any(named: 'templateId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
          profileId: any(named: 'profileId'),
        ),
      );
    });

    testWidgets(
      'with no event template anywhere it warns instead of opening the picker',
      (tester) async {
        final harness = _EventHarness.create(
          categoryId: 'cat-events',
          categoryTemplates: [makeTestTemplate(id: 'tpl-task')],
          globalTemplates: [makeTestTemplate(id: 'tpl-task')],
        );

        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Assign Agent'));
        await tester.pumpAndSettle();

        expect(
          find.text('No templates available. Create one in Settings first.'),
          findsOneWidget,
        );
        expect(find.text('Solo'), findsNothing);
        verifyNever(
          () => harness.eventAgentService.createEventAgent(
            eventId: any(named: 'eventId'),
            templateId: any(named: 'templateId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            profileId: any(named: 'profileId'),
          ),
        );
      },
    );
  });

  group('assignableAgentTemplates', () {
    final taskTemplate = makeTestTemplate(id: 'tpl-task');
    final eventTemplate = makeTestTemplate(
      id: 'tpl-event',
      kind: AgentTemplateKind.eventAgent,
    );
    final globalEventTemplate = makeTestTemplate(
      id: 'tpl-event-global',
      kind: AgentTemplateKind.eventAgent,
    );

    test('prefers the category-scoped templates of the kind', () async {
      final service = MockAgentTemplateService();
      when(
        () => service.listTemplatesForCategory('cat'),
      ).thenAnswer((_) async => [taskTemplate, eventTemplate]);

      final templates = await assignableAgentTemplates(
        service,
        kind: AgentTemplateKind.eventAgent,
        categoryId: 'cat',
      );

      expect(templates.map((t) => t.id), ['tpl-event']);
      // ignore: unnecessary_lambdas
      verifyNever(() => service.listTemplates());
    });

    test('falls back to every template of the kind when the category scopes '
        'only templates of another kind', () async {
      final service = MockAgentTemplateService();
      when(
        () => service.listTemplatesForCategory('cat'),
      ).thenAnswer((_) async => [taskTemplate]);
      when(
        // ignore: unnecessary_lambdas
        () => service.listTemplates(),
      ).thenAnswer((_) async => [taskTemplate, globalEventTemplate]);

      final templates = await assignableAgentTemplates(
        service,
        kind: AgentTemplateKind.eventAgent,
        categoryId: 'cat',
      );

      expect(templates.map((t) => t.id), ['tpl-event-global']);
    });

    test('without a category it lists every template of the kind', () async {
      final service = MockAgentTemplateService();
      when(
        // ignore: unnecessary_lambdas
        () => service.listTemplates(),
      ).thenAnswer((_) async => [taskTemplate, globalEventTemplate]);

      final templates = await assignableAgentTemplates(
        service,
        kind: AgentTemplateKind.taskAgent,
        categoryId: null,
      );

      expect(templates.map((t) => t.id), ['tpl-task']);
      verifyNever(() => service.listTemplatesForCategory(any()));
    });
  });
}

/// Wiring for the event variant of the CTA. The host is a stand-in for the
/// event's recap card: it watches `eventAgentProvider` and swaps the offer for
/// a marker once an agent is attached, so the post-create invalidate is
/// observable without pulling in the whole recap card.
class _EventHarness {
  _EventHarness._({
    required this.event,
    required this.entity,
    required this.templateService,
    required this.eventAgentService,
    required this.profile,
  });

  factory _EventHarness.create({
    required String categoryId,
    JournalEntity? entity,
    List<AgentTemplateEntity>? categoryTemplates,
    List<AgentTemplateEntity> globalTemplates = const [],
  }) {
    final event = JournalEvent(
      meta: Metadata(
        id: 'event-1',
        createdAt: DateTime(2026, 5, 2, 18),
        updatedAt: DateTime(2026, 5, 2, 18),
        dateFrom: DateTime(2026, 5, 2, 18),
        dateTo: DateTime(2026, 5, 2, 22),
        categoryId: categoryId,
      ),
      data: const EventData(
        title: 'Rooftop birthday',
        stars: 0,
        status: EventStatus.completed,
      ),
    );
    final templateService = MockAgentTemplateService();
    when(
      () => templateService.listTemplatesForCategory(categoryId),
    ).thenAnswer(
      (_) async =>
          categoryTemplates ??
          [
            makeTestTemplate(id: 'tpl-task'),
            makeTestTemplate(
              id: 'tpl-event',
              agentId: 'tpl-event',
              kind: AgentTemplateKind.eventAgent,
            ),
          ],
    );
    when(
      // ignore: unnecessary_lambdas
      () => templateService.listTemplates(),
    ).thenAnswer((_) async => globalTemplates);

    final eventAgentService = MockEventAgentService();
    when(
      () => eventAgentService.createEventAgent(
        eventId: any(named: 'eventId'),
        templateId: any(named: 'templateId'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        profileId: any(named: 'profileId'),
      ),
    ).thenAnswer((_) async => makeTestIdentity(kind: 'event_agent'));

    return _EventHarness._(
      event: event,
      entity: entity ?? event,
      templateService: templateService,
      eventAgentService: eventAgentService,
      profile: testInferenceProfile(id: 'prof-success', name: 'Solo'),
    );
  }

  final JournalEvent event;

  /// What the journal database returns for the event's id.
  final JournalEntity entity;
  final MockAgentTemplateService templateService;
  final MockEventAgentService eventAgentService;
  final AiConfig profile;

  bool _agentAttached = false;

  /// Flip `eventAgentProvider` so the post-create invalidate re-resolves to a
  /// real identity instead of null.
  void attachAgent() => _agentAttached = true;

  Widget build() {
    final eventId = event.meta.id;
    return RiverpodWidgetTestBench(
      mediaQueryData: const MediaQueryData(size: Size(900, 1000)),
      overrides: [
        eventAgentProvider.overrideWith(
          (ref, id) async =>
              _agentAttached ? makeTestIdentity(kind: 'event_agent') : null,
        ),
        journalDbProvider.overrideWithValue(_dbReturning(eventId, entity)),
        agentTemplateServiceProvider.overrideWith((ref) => templateService),
        eventAgentServiceProvider.overrideWithValue(eventAgentService),
        inferenceProfileControllerProvider.overrideWith(
          () => _FakeInferenceProfileController([profile]),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) =>
            ref.watch(eventAgentProvider(eventId)).value == null
            ? AssignAgentCta.event(eventId: eventId)
            : const Text('agent attached'),
      ),
    );
  }
}

/// Bundles the ~50 lines of mock + provider wiring for the CTA success
/// path so the test body reads as action + assertion. Holds the two
/// services (for verification) and the `task`, and exposes
/// [attachAgent] to flip `taskAgentProvider` from null (CTA shown) to a
/// real identity after creation — without it, the post-create
/// `invalidate(taskAgentProvider)` would re-resolve to null and the CTA
/// would never disappear.
class _SuccessPathHarness {
  _SuccessPathHarness._({
    required this.task,
    required this.templateService,
    required this.taskAgentService,
    required this.profile,
  });

  /// Wires a [task] carrying a [categoryId] so `_createTaskAgent` takes
  /// the `categoryId != null` branches: it queries the category-scoped
  /// template list and threads the category into `allowedCategoryIds`.
  factory _SuccessPathHarness.create({required String categoryId}) {
    final task = testTask.copyWith(
      meta: testTask.meta.copyWith(categoryId: categoryId),
    );
    final template = makeTestTemplate(
      id: 'tpl-success',
      agentId: 'tpl-success',
      displayName: 'Single Task Template',
    );
    final templateService = MockAgentTemplateService();
    when(
      () => templateService.listTemplatesForCategory(categoryId),
    ).thenAnswer((_) async => [template]);

    final taskAgentService = MockTaskAgentService();
    when(
      () => taskAgentService.createTaskAgent(
        taskId: any(named: 'taskId'),
        templateId: any(named: 'templateId'),
        profileId: any(named: 'profileId'),
        setupOrigin: any(named: 'setupOrigin'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
      ),
    ).thenAnswer((_) async => makeTestIdentity());

    return _SuccessPathHarness._(
      task: task,
      templateService: templateService,
      taskAgentService: taskAgentService,
      profile: testInferenceProfile(id: 'prof-success', name: 'Solo'),
    );
  }

  final Task task;
  final MockAgentTemplateService templateService;
  final MockTaskAgentService taskAgentService;
  final AiConfig profile;

  bool _agentAttached = false;

  /// Flip `taskAgentProvider` so the post-create invalidate re-resolves
  /// to a real identity instead of null.
  void attachAgent() => _agentAttached = true;

  /// [child] replaces the card, so a test can drive the same flow from a
  /// different entry point — the task page's first-run row calls
  /// `showAssignTaskAgentPicker` directly rather than rendering the card.
  Widget build({Widget? child}) {
    return RiverpodWidgetTestBench(
      mediaQueryData: const MediaQueryData(size: Size(900, 1000)),
      overrides: [
        configFlagProvider.overrideWith((ref, flagName) => Stream.value(true)),
        taskAgentProvider.overrideWith(
          (ref, id) async => _agentAttached ? makeTestIdentity() : null,
        ),
        entryControllerProvider(
          task.meta.id,
        ).overrideWith(() => _TaskEntryController(task)),
        journalDbProvider.overrideWithValue(_dbReturning(task.meta.id, task)),
        agentTemplateServiceProvider.overrideWith((ref) => templateService),
        taskAgentServiceProvider.overrideWith((ref) => taskAgentService),
        inferenceProfileControllerProvider.overrideWith(
          () => _FakeInferenceProfileController([profile]),
        ),
      ],
      child: child ?? AiSummaryCard(taskId: task.meta.id),
    );
  }
}

/// The journal database the assign-agent CTA reads the task from: [entity]
/// for [id].
MockJournalDb _dbReturning(String id, JournalEntity? entity) {
  final db = MockJournalDb();
  when(() => db.journalEntityById(id)).thenAnswer((_) async => entity);
  return db;
}
