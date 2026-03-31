import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_pending_wakes_list.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(() async {
    await tearDownTestGetIt();
  });

  Widget buildSubject({
    required List<PendingWakeRecord> records,
    AgentService? agentService,
    Map<String, String?> subjectTitles = const {},
  }) {
    return makeTestableWidgetWithScaffold(
      const AgentPendingWakesList(),
      theme: DesignSystemTheme.light(),
      overrides: [
        pendingWakeRecordsProvider.overrideWith((ref) async => records),
        pendingWakeTargetTitleProvider.overrideWith(
          (ref, String? entryId) async => subjectTitles[entryId],
        ),
        if (agentService != null)
          agentServiceProvider.overrideWith((ref) => agentService),
      ],
    );
  }

  group('AgentPendingWakesList', () {
    testWidgets('shows empty state when no pending wakes exist', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(records: const []));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentPendingWakesList));
      expect(
        find.text(context.messages.agentPendingWakesEmptyList),
        findsOneWidget,
      );
    });

    testWidgets('renders wake cards with local countdown updates', (
      tester,
    ) async {
      final now = DateTime(2026, 3, 31, 9);
      var currentNow = now;
      final record = PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: 'agent-1',
          kind: AgentKinds.projectAgent,
          displayName: 'Project Watcher',
        ),
        state: makeTestState(
          agentId: 'agent-1',
          slots: const AgentSlots(activeProjectId: 'project-1'),
          nextWakeAt: now.add(const Duration(minutes: 2, seconds: 5)),
        ),
        type: PendingWakeType.pending,
        dueAt: now.add(const Duration(minutes: 2, seconds: 5)),
      );

      await withClock(Clock(() => currentNow), () async {
        await tester.pumpWidget(
          buildSubject(
            records: [record],
            subjectTitles: const {'project-1': 'Platform Refresh'},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Platform Refresh'), findsOneWidget);
        expect(find.text('2m 5s'), findsOneWidget);

        currentNow = currentNow.add(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('2m 3s'), findsOneWidget);
      });
    });

    testWidgets('delete action clears a pending wake', (tester) async {
      final mockAgentService = MockAgentService();
      final record = PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: 'agent-1',
          displayName: 'Loop Guard',
        ),
        state: makeTestState(
          agentId: 'agent-1',
          slots: const AgentSlots(activeTaskId: 'task-1'),
          nextWakeAt: kAgentTestDate.add(const Duration(minutes: 5)),
        ),
        type: PendingWakeType.pending,
        dueAt: kAgentTestDate.add(const Duration(minutes: 5)),
      );

      when(() => mockAgentService.cancelPendingWake('agent-1')).thenReturn(
        null,
      );

      await tester.pumpWidget(
        buildSubject(
          records: [record],
          agentService: mockAgentService,
          subjectTitles: const {'task-1': 'Guard the notification loop'},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();

      verify(() => mockAgentService.cancelPendingWake('agent-1')).called(1);
    });

    testWidgets('uses linked subject title as the main heading', (
      tester,
    ) async {
      final record = PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: 'agent-1',
          displayName: 'Task Agent',
        ),
        state: makeTestState(
          agentId: 'agent-1',
          slots: const AgentSlots(activeTaskId: 'task-1'),
          nextWakeAt: kAgentTestDate.add(const Duration(minutes: 5)),
        ),
        type: PendingWakeType.pending,
        dueAt: kAgentTestDate.add(const Duration(minutes: 5)),
      );

      await tester.pumpWidget(
        buildSubject(
          records: [record],
          subjectTitles: const {'task-1': 'Daily Wednesday March 11th'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Wednesday March 11th'), findsOneWidget);
      expect(find.text('Task Agent'), findsOneWidget);
    });

    testWidgets('falls back to the agent display name when no title resolves', (
      tester,
    ) async {
      final record = PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: 'agent-1',
          displayName: 'Task Agent',
        ),
        state: makeTestState(
          agentId: 'agent-1',
          slots: const AgentSlots(activeTaskId: 'task-1'),
          nextWakeAt: kAgentTestDate.add(const Duration(minutes: 5)),
        ),
        type: PendingWakeType.pending,
        dueAt: kAgentTestDate.add(const Duration(minutes: 5)),
      );

      await tester.pumpWidget(
        buildSubject(
          records: [record],
          subjectTitles: const {'task-1': ''},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task Agent'), findsNWidgets(2));
    });

    testWidgets('shows zero countdown when the wake is already overdue', (
      tester,
    ) async {
      final now = DateTime(2026, 3, 31, 9);
      final record = PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: 'agent-1',
          displayName: 'Overdue',
        ),
        state: makeTestState(
          agentId: 'agent-1',
          nextWakeAt: now.subtract(const Duration(seconds: 5)),
        ),
        type: PendingWakeType.pending,
        dueAt: now.subtract(const Duration(seconds: 5)),
      );

      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(buildSubject(records: [record]));
        await tester.pumpAndSettle();
      });

      expect(find.text('0s'), findsOneWidget);
    });

    testWidgets('formats long countdowns with hours, minutes, and seconds', (
      tester,
    ) async {
      final now = DateTime(2026, 3, 31, 9);
      final record = PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: 'agent-1',
          kind: AgentKinds.projectAgent,
          displayName: 'Project Watcher',
        ),
        state: makeTestState(
          agentId: 'agent-1',
          scheduledWakeAt: now.add(
            const Duration(hours: 1, minutes: 1, seconds: 1),
          ),
        ),
        type: PendingWakeType.scheduled,
        dueAt: now.add(const Duration(hours: 1, minutes: 1, seconds: 1)),
      );

      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(buildSubject(records: [record]));
        await tester.pumpAndSettle();
      });

      expect(find.text('1h 1m 1s'), findsOneWidget);
    });

    testWidgets('delete action clears a scheduled wake', (tester) async {
      final mockAgentService = MockAgentService();
      final record = PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: 'agent-2',
          kind: AgentKinds.templateImprover,
          displayName: 'Improver',
        ),
        state: makeTestState(
          agentId: 'agent-2',
          scheduledWakeAt: kAgentTestDate.add(const Duration(days: 1)),
        ),
        type: PendingWakeType.scheduled,
        dueAt: kAgentTestDate.add(const Duration(days: 1)),
      );

      when(
        () => mockAgentService.clearScheduledWake('agent-2'),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildSubject(
          records: [record],
          agentService: mockAgentService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();

      verify(() => mockAgentService.clearScheduledWake('agent-2')).called(1);
    });

    testWidgets('delete failure shows snackbar feedback', (tester) async {
      final mockAgentService = MockAgentService();
      final record = PendingWakeRecord(
        agent: makeTestIdentity(
          agentId: 'agent-2',
          displayName: 'Loop Guard',
        ),
        state: makeTestState(
          agentId: 'agent-2',
          nextWakeAt: kAgentTestDate.add(const Duration(minutes: 5)),
        ),
        type: PendingWakeType.pending,
        dueAt: kAgentTestDate.add(const Duration(minutes: 5)),
      );

      when(
        () => mockAgentService.cancelPendingWake('agent-2'),
      ).thenThrow(Exception('boom'));

      await tester.pumpWidget(
        buildSubject(
          records: [record],
          agentService: mockAgentService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentPendingWakesList));
      expect(find.text(context.messages.commonError), findsOneWidget);
    });
  });
}
