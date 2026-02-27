import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
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
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../test_helper.dart';
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

  late MockEntitiesCacheService mockEntitiesCacheService;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(FakeTaskData());

    final mockPersistenceLogic = MockPersistenceLogic();
    final mockEditorStateService = MockEditorStateService();
    final mockJournalDb = MockJournalDb();
    final mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());
    when(() => mockUpdateNotifications.localUpdateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());
    when(() => mockJournalDb.journalEntityById(any()))
        .thenAnswer((_) async => null);
    when(() => mockJournalDb.getLinkedEntities(any()))
        .thenAnswer((_) async => <JournalEntity>[]);
    when(mockJournalDb.watchConfigFlags)
        .thenAnswer((_) => const Stream<Set<ConfigFlag>>.empty());

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
    when(() => mockEntitiesCacheService.sortedLabels).thenReturn([]);
    when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);
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
        taskAgentProvider.overrideWith(
          (ref, id) async => agent,
        ),
        agentReportProvider.overrideWith(
          (ref, agentId) async => report,
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
