import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
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
  Future<EntryState?> build({required String id}) async => null;
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
                id: 'task-001',
              ).overrideWith(_NullEntryController.new),
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
                id: testTask.meta.id,
              ).overrideWith(() => _TaskEntryController(testTask)),
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
                id: testTask.meta.id,
              ).overrideWith(() => _TaskEntryController(testTask)),
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

  Widget build() {
    return RiverpodWidgetTestBench(
      mediaQueryData: const MediaQueryData(size: Size(900, 1000)),
      overrides: [
        configFlagProvider.overrideWith((ref, flagName) => Stream.value(true)),
        taskAgentProvider.overrideWith(
          (ref, id) async => _agentAttached ? makeTestIdentity() : null,
        ),
        entryControllerProvider(
          id: task.meta.id,
        ).overrideWith(() => _TaskEntryController(task)),
        agentTemplateServiceProvider.overrideWith((ref) => templateService),
        taskAgentServiceProvider.overrideWith((ref) => taskAgentService),
        inferenceProfileControllerProvider.overrideWith(
          () => _FakeInferenceProfileController([profile]),
        ),
      ],
      child: AiSummaryCard(taskId: task.meta.id),
    );
  }
}
