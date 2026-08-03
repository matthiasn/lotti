import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/assign_agent_cta_part.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_connector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_widget.dart';
import 'package:lotti/features/tasks/ui/task_form.dart';
import 'package:lotti/features/tasks/ui/widgets/task_first_run_actions.dart';
import 'package:lotti/features/tasks/ui/widgets/viewport_stable_animated_size.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
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

class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build() async => null;
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
        when(
          () => mockEntitiesCacheService.getLabelById(any()),
        ).thenReturn(null);
        getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
      },
    );

    when(
      () => mocks.journalDb.getLinkedEntities(any()),
    ).thenAnswer((_) async => <JournalEntity>[]);
    when(
      mocks.journalDb.watchConfigFlags,
    ).thenAnswer((_) => const Stream<Set<ConfigFlag>>.empty());
  });

  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    required Task task,
    AgentDomainEntity? agent,
    AgentDomainEntity? report,
    GlobalKey? cardRegionKey,
  }) {
    return RiverpodWidgetTestBench(
      overrides: [
        entryControllerProvider(task.meta.id).overrideWith(
          () => _TestEntryController(task),
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
        child: TaskForm(taskId: task.meta.id, cardRegionKey: cardRegionKey),
      ),
    );
  }

  /// The reporter wrapping [of], or fails the lookup if the band is unreported.
  ViewportStableSizeReporter reporterFor(
    WidgetTester tester,
    Finder of,
  ) {
    return tester.widget<ViewportStableSizeReporter>(
      find
          .ancestor(of: of, matching: find.byType(ViewportStableSizeReporter))
          .first,
    );
  }

  group('TaskForm — first-run block', () {
    testWidgets(
      'a task with nothing on it gets the first-run block, and the AI card '
      'stands its assign CTA down so the offer is not made twice',
      (tester) async {
        final blank = testTask.copyWith(
          data: testTask.data.copyWith(title: '', checklistIds: const []),
          entryText: null,
        );

        await tester.pumpWidget(buildSubject(task: blank));
        await tester.pumpAndSettle();

        expect(find.byType(TaskFirstRunActions), findsOneWidget);
        expect(find.byType(AssignAgentCta), findsNothing);
      },
    );

    testWidgets(
      'the block retires as soon as the task holds a checklist',
      (tester) async {
        final withContent = testTask.copyWith(
          data: testTask.data.copyWith(checklistIds: const ['c1']),
          entryText: null,
        );

        await tester.pumpWidget(buildSubject(task: withContent));
        await tester.pumpAndSettle();

        expect(find.byType(TaskFirstRunActions), findsNothing);
      },
    );

    testWidgets(
      'an attached agent retires it too — the task is already doing something',
      (tester) async {
        final blank = testTask.copyWith(
          data: testTask.data.copyWith(title: '', checklistIds: const []),
          entryText: null,
        );

        await tester.pumpWidget(
          buildSubject(task: blank, agent: makeTestIdentity()),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TaskFirstRunActions), findsNothing);
      },
    );
  });

  group('TaskForm', () {
    testWidgets('renders nothing when entry is null', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            entryControllerProvider('no-entry').overrideWith(
              _NullEntryController.new,
            ),
          ],
          child: const TaskForm(taskId: 'no-entry'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopTaskHeaderConnector), findsNothing);
    });

    testWidgets('renders core child widgets for a task', (tester) async {
      await tester.pumpWidget(buildSubject(task: testTask));
      await tester.pumpAndSettle();

      expect(find.byType(DesktopTaskHeaderConnector), findsOneWidget);
      // The new unified AI surface replaces the prior AgentSuggestionsPanel
      // + TaskAgentReportSection split, so the form embeds a single card.
      expect(find.byType(AiSummaryCard), findsOneWidget);
      expect(find.byType(LinkedTasksWidget), findsOneWidget);
      expect(find.byType(ChecklistsWidget), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(ChecklistsWidget),
          matching: find.byType(ViewportStableSizeReporter),
        ),
        findsOneWidget,
      );
      // The header is reported too: confirmed proposals (labels, due date,
      // priority, status, title) grow it above the AI card, and unreported
      // growth there would displace the proposals mid-confirm.
      expect(
        find.ancestor(
          of: find.byType(DesktopTaskHeaderConnector),
          matching: find.byType(ViewportStableSizeReporter),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'reports the linked-tasks band, which a confirmed follow-up task '
      'resizes above the AI card',
      (tester) async {
        await tester.pumpWidget(buildSubject(task: testTask));
        await tester.pumpAndSettle();

        expect(
          find.ancestor(
            of: find.byType(LinkedTasksWidget),
            matching: find.byType(ViewportStableSizeReporter),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'reports the AI card band only while it is off-screen, and the bands '
      'above it always',
      (tester) async {
        await tester.pumpWidget(buildSubject(task: testTask));
        await tester.pumpAndSettle();

        // The card's own collapse must move the page only when the user
        // cannot see it; a visible collapse is the reflow they are watching.
        expect(
          reporterFor(tester, find.byType(AiSummaryCard)).offscreenOnly,
          isTrue,
        );
        // Everything above the card is compensated unconditionally: it moves
        // the card itself, which is what the hold exists to keep still.
        for (final band in [
          find.byType(DesktopTaskHeaderConnector),
          find.byType(ChecklistsWidget),
          find.byType(LinkedTasksWidget),
        ]) {
          expect(reporterFor(tester, band).offscreenOnly, isFalse);
        }
      },
    );

    testWidgets(
      'gives every reported band a distinct task-scoped key, with and without '
      'the legacy body band',
      (tester) async {
        // StaggeredEntrance maps children through flutter_animate, which drops
        // their keys, so the Column matches children positionally. Toggling the
        // body band shifts every band below it by one slot; without distinct
        // keys a reporter's measured height baseline would be reused for a
        // different band and emit a bogus delta on the next layout.
        for (final task in [
          testTask,
          testTask.copyWith(
            entryText: const EntryText(plainText: 'legacy body text'),
          ),
        ]) {
          await tester.pumpWidget(buildSubject(task: task));
          await tester.pumpAndSettle();

          final keys = tester
              .widgetList<ViewportStableSizeReporter>(
                find.byType(ViewportStableSizeReporter),
              )
              .map((reporter) => reporter.key)
              .toList();

          // Header, checklist, linked tasks, AI card.
          expect(keys, hasLength(4));
          expect(keys.toSet(), hasLength(keys.length));
          for (final key in keys) {
            expect(key, isA<ValueKey<String>>());
            expect((key! as ValueKey<String>).value, contains(task.meta.id));
          }
        }
      },
    );

    testWidgets('exposes the AI card band through cardRegionKey', (
      tester,
    ) async {
      // The page measures this box, not the seam below the card: the seam sits
      // a further step5 + step5 lower, and in that gap the card is already out
      // of sight while the seam is not — so a predicate measured there would
      // disagree with the band that reports under it.
      final cardRegionKey = GlobalKey(debugLabel: 'card-region');
      await tester.pumpWidget(
        buildSubject(task: testTask, cardRegionKey: cardRegionKey),
      );
      await tester.pumpAndSettle();

      expect(cardRegionKey.currentContext, isNotNull);
      final band =
          cardRegionKey.currentContext!.findRenderObject()! as RenderBox;
      final reporter = find
          .ancestor(
            of: find.byType(AiSummaryCard),
            matching: find.byType(ViewportStableSizeReporter),
          )
          .first;
      expect(
        band.localToGlobal(Offset(0, band.size.height)).dy,
        closeTo(tester.getRect(reporter).bottom, 0.1),
      );
    });

    testWidgets('agent report shows content when agent has report', (
      tester,
    ) async {
      final agent = makeTestIdentity(
        id: 'agent-for-task',
        agentId: 'agent-for-task',
      );
      final report = makeTestReport(
        agentId: 'agent-for-task',
        content:
            '## 📋 TLDR\nTask is going well.\n\n'
            '## ✅ Achieved\n- Done things\n',
      );

      await tester.pumpWidget(
        buildSubject(task: testTask, agent: agent, report: report),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('TLDR'), findsOneWidget);
      expect(find.textContaining('Task is going well'), findsOneWidget);
    });

    testWidgets('agent report section hidden when no agent exists', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(task: testTask));
      await tester.pumpAndSettle();

      // AiSummaryCard is in the tree; with no agent attached it surfaces
      // the "Assign Agent" CTA and no TLDR copy.
      expect(find.byType(AiSummaryCard), findsOneWidget);
      expect(find.textContaining('TLDR'), findsNothing);
    });
  });
}
