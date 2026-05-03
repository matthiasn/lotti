import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
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

/// Tests for the AI summary card's "Assign Agent" CTA path. The CTA
/// drives `_createTaskAgent` in `assign_agent_cta_part.dart`, which
/// handles three branches:
///
/// * the entry resolves to a non-`Task` (or null) — short-circuit
/// * templates are unavailable — warning toast, no agent created
/// * the template service throws — error toast, no agent created
class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) async => null;
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
  });
}
