import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_controls.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  const testAgentId = 'agent-001';

  late MockAgentService mockAgentService;
  late MockTaskAgentService mockTaskAgentService;
  late MockAgentRepository mockAgentRepository;

  setUp(() {
    mockAgentService = MockAgentService();
    mockTaskAgentService = MockTaskAgentService();
    mockAgentRepository = MockAgentRepository();
  });

  Widget buildSubject({
    required AgentLifecycle lifecycle,
    AgentService? agentService,
    TaskAgentService? taskAgentService,
    AgentRepository? agentRepository,
  }) {
    return makeTestableWidgetWithScaffold(
      AgentControls(
        agentId: testAgentId,
        lifecycle: lifecycle,
      ),
      overrides: [
        agentServiceProvider.overrideWithValue(
          agentService ?? mockAgentService,
        ),
        taskAgentServiceProvider.overrideWithValue(
          taskAgentService ?? mockTaskAgentService,
        ),
        agentRepositoryProvider.overrideWithValue(
          agentRepository ?? mockAgentRepository,
        ),
        // Override identity provider to prevent real DB access on invalidation
        agentIdentityProvider.overrideWith((ref, agentId) async => null),
        taskAgentProvider.overrideWith((ref, taskId) async => null),
      ],
    );
  }

  group('AgentControls', () {
    testWidgets(
      'Delete looks up agent_task links for provider invalidation',
      (tester) async {
        const linkedTaskId = 'task-42';
        final link = model.AgentLink.agentTask(
          id: 'link-1',
          fromId: testAgentId,
          toId: linkedTaskId,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(
          () => mockAgentRepository.getLinksFrom(
            testAgentId,
            type: 'agent_task',
          ),
        ).thenAnswer((_) async => [link]);
        when(
          () => mockAgentService.deleteAgent(testAgentId),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.destroyed),
        );
        await tester.pump();

        await tester.tap(find.text('Delete permanently'));
        await tester.pump();

        final deleteButtons = find.text('Delete permanently');
        await tester.tap(deleteButtons.last);
        await tester.pump();

        verify(
          () => mockAgentRepository.getLinksFrom(
            testAgentId,
            type: 'agent_task',
          ),
        ).called(1);
        verify(() => mockAgentService.deleteAgent(testAgentId)).called(1);
      },
    );

    testWidgets(
      'shows no action buttons when lifecycle is created',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.created),
        );
        await tester.pump();

        // 'created' is not active, dormant, or destroyed — no buttons shown
        expect(find.text('Pause'), findsNothing);
        expect(find.text('Resume'), findsNothing);
        expect(find.text('Re-analyze'), findsNothing);
        expect(find.text('Destroy'), findsNothing);
        expect(find.text('This agent has been destroyed.'), findsNothing);
      },
    );

    testWidgets(
      'shows snackbar when pauseAgent throws',
      (tester) async {
        when(
          () => mockAgentService.pauseAgent(testAgentId),
        ).thenThrow(Exception('network error'));

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.active),
        );
        await tester.pump();

        await tester.tap(find.text('Pause'));
        await tester.pump();

        expect(
          find.textContaining('Action failed'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'buttons are disabled while an action is in progress',
      (tester) async {
        // Use a completer to control when the future resolves
        final completer = Completer<bool>();
        when(
          () => mockAgentService.pauseAgent(testAgentId),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.active),
        );
        await tester.pump();

        // Tap Pause — it starts but doesn't complete
        await tester.tap(find.text('Pause'));
        await tester.pump();

        // While busy, the Re-analyze button should be disabled
        final reanalyzeButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Re-analyze'),
        );
        expect(reanalyzeButton.onPressed, isNull);

        // Complete the action
        completer.complete(true);
        await tester.pump();

        // Now buttons should be re-enabled
        final reanalyzeButtonAfter = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Re-analyze'),
        );
        expect(reanalyzeButtonAfter.onPressed, isNotNull);
      },
    );

    testWidgets(
      'shows snackbar when resumeAgent throws',
      (tester) async {
        when(
          () => mockAgentService.resumeAgent(testAgentId),
        ).thenThrow(Exception('resume failed'));

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.dormant),
        );
        await tester.pump();

        await tester.tap(find.text('Resume'));
        await tester.pump();

        expect(find.textContaining('resume failed'), findsOneWidget);
      },
    );

    testWidgets(
      'shows snackbar when destroyAgent throws',
      (tester) async {
        when(
          () => mockAgentService.destroyAgent(testAgentId),
        ).thenThrow(Exception('destroy failed'));

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.active),
        );
        await tester.pump();

        // Open destroy dialog
        await tester.tap(find.text('Destroy'));
        await tester.pump();

        // Confirm in dialog
        final destroyButtons = find.text('Destroy');
        await tester.tap(destroyButtons.last);
        await tester.pump();

        expect(find.textContaining('destroy failed'), findsOneWidget);
      },
    );

    testWidgets(
      'Destroy dialog dismissed via barrier does not call destroyAgent',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.active),
        );
        await tester.pump();

        await tester.tap(find.text('Destroy'));
        await tester.pump();

        // Dismiss dialog by tapping the barrier (outside the dialog)
        await tester.tapAt(Offset.zero);
        await tester.pump();

        verifyNever(() => mockAgentService.destroyAgent(any()));
      },
    );

    testWidgets(
      'active lifecycle shows exactly Pause, Re-analyze, Destroy buttons',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.active),
        );
        await tester.pump();

        // Verify button types: Pause is FilledButton.tonal
        expect(
          find.widgetWithText(FilledButton, 'Pause'),
          findsOneWidget,
        );
        // Re-analyze and Destroy are OutlinedButtons
        expect(
          find.widgetWithText(OutlinedButton, 'Re-analyze'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Destroy'),
          findsOneWidget,
        );
        // No Resume
        expect(find.text('Resume'), findsNothing);
        // No Delete permanently
        expect(find.text('Delete permanently'), findsNothing);
      },
    );

    testWidgets(
      'dormant lifecycle shows exactly Resume, Re-analyze, Destroy buttons',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.dormant),
        );
        await tester.pump();

        expect(
          find.widgetWithText(FilledButton, 'Resume'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Re-analyze'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Destroy'),
          findsOneWidget,
        );
        expect(find.text('Pause'), findsNothing);
      },
    );

    testWidgets(
      'Re-analyze in dormant calls triggerReanalysis',
      (tester) async {
        when(
          () => mockTaskAgentService.triggerReanalysis(testAgentId),
        ).thenReturn(null);

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.dormant),
        );
        await tester.pump();

        await tester.tap(find.text('Re-analyze'));
        await tester.pump();

        verify(
          () => mockTaskAgentService.triggerReanalysis(testAgentId),
        ).called(1);
      },
    );

    testWidgets(
      'shows snackbar when triggerReanalysis throws',
      (tester) async {
        when(
          () => mockTaskAgentService.triggerReanalysis(testAgentId),
        ).thenThrow(Exception('reanalysis failed'));

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.active),
        );
        await tester.pump();

        await tester.tap(find.text('Re-analyze'));
        await tester.pump();

        expect(find.textContaining('reanalysis failed'), findsOneWidget);
      },
    );

    testWidgets(
      'Delete permanently button is disabled while busy',
      (tester) async {
        final completer = Completer<void>();
        when(
          () => mockAgentRepository.getLinksFrom(
            testAgentId,
            type: 'agent_task',
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentService.deleteAgent(testAgentId),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.destroyed),
        );
        await tester.pump();

        // Open delete dialog
        await tester.tap(find.text('Delete permanently'));
        await tester.pump();

        // Confirm in dialog
        final deleteButtons = find.text('Delete permanently');
        await tester.tap(deleteButtons.last);
        await tester.pump();

        // The Delete permanently button should now be disabled (busy)
        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Delete permanently'),
        );
        expect(button.onPressed, isNull);

        // Complete the action
        completer.complete();
        await tester.pump();
      },
    );
  });
}
