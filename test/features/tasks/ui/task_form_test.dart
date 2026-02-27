import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:lotti/features/agents/ui/task_agent_report_section.dart';
import 'package:lotti/features/ai/ui/latest_ai_response_summary.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_header_meta_card.dart';
import 'package:lotti/features/tasks/ui/labels/task_labels_wrapper.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_widget.dart';
import 'package:lotti/features/tasks/ui/task_form.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../test_helper.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_utils.dart';

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

  late TestGetItMocks mocks;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(FakeTaskData());
  });

  setUp(() async {
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<TimeService>(TimeService());

        final mockEntitiesCacheService = MockEntitiesCacheService();
        when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
        when(() => mockEntitiesCacheService.sortedLabels).thenReturn([]);
        when(() => mockEntitiesCacheService.getLabelById(any()))
            .thenReturn(null);
        getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
      },
    );

    when(() => mocks.journalDb.getLinkedEntities(any()))
        .thenAnswer((_) async => <JournalEntity>[]);
    when(mocks.journalDb.watchConfigFlags)
        .thenAnswer((_) => const Stream<Set<ConfigFlag>>.empty());
  });

  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    required Task task,
    AgentDomainEntity? agent,
    AgentDomainEntity? report,
  }) {
    return RiverpodWidgetTestBench(
      overrides: [
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
        configFlagProvider.overrideWith(
          (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
        ),
        taskAgentProvider.overrideWith(
          (ref, id) async => agent,
        ),
        agentReportProvider.overrideWith(
          (ref, agentId) async => report,
        ),
        templateForAgentProvider.overrideWith(
          (ref, agentId) async => null,
        ),
        agentIsRunningProvider.overrideWith(
          (ref, agentId) => Stream.value(false),
        ),
        agentStateProvider.overrideWith(
          (ref, agentId) async => null,
        ),
      ],
      child: SingleChildScrollView(
        child: TaskForm(taskId: task.meta.id),
      ),
    );
  }

  group('TaskForm', () {
    testWidgets('renders nothing when entry is null', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            entryControllerProvider(id: 'no-entry').overrideWith(
              _NullEntryController.new,
            ),
          ],
          child: const TaskForm(taskId: 'no-entry'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskHeaderMetaCard), findsNothing);
    });

    testWidgets('renders core child widgets for a task', (tester) async {
      await tester.pumpWidget(buildSubject(task: testTask));
      await tester.pumpAndSettle();

      expect(find.byType(TaskHeaderMetaCard), findsOneWidget);
      expect(find.byType(TaskLabelsWrapper), findsOneWidget);
      expect(find.byType(LatestAiResponseSummary), findsOneWidget);
      expect(find.byType(TaskAgentReportSection), findsOneWidget);
      expect(find.byType(ChangeSetSummaryCard), findsOneWidget);
      expect(find.byType(LinkedTasksWidget), findsOneWidget);
      expect(find.byType(ChecklistsWidget), findsOneWidget);
    });

    testWidgets('agent report shows content when agent has report',
        (tester) async {
      final agent = makeTestIdentity(
        id: 'agent-for-task',
        agentId: 'agent-for-task',
      );
      final report = makeTestReport(
        agentId: 'agent-for-task',
        content: '## 📋 TLDR\nTask is going well.\n\n'
            '## ✅ Achieved\n- Done things\n',
      );

      await tester.pumpWidget(
        buildSubject(task: testTask, agent: agent, report: report),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('TLDR'), findsOneWidget);
      expect(find.textContaining('Task is going well'), findsOneWidget);
    });

    testWidgets('agent report section hidden when no agent exists',
        (tester) async {
      await tester.pumpWidget(buildSubject(task: testTask));
      await tester.pumpAndSettle();

      // TaskAgentReportSection is in the tree but renders nothing
      expect(find.byType(TaskAgentReportSection), findsOneWidget);
      expect(find.textContaining('TLDR'), findsNothing);
    });
  });
}
