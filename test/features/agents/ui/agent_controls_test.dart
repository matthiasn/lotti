import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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

  setUp(() {
    mockAgentService = MockAgentService();
    mockTaskAgentService = MockTaskAgentService();
  });

  Widget buildSubject({
    required AgentLifecycle lifecycle,
    AgentService? agentService,
    TaskAgentService? taskAgentService,
  }) {
    return makeTestableWidgetWithScaffold(
      AgentControls(
        agentId: testAgentId,
        lifecycle: lifecycle,
      ),
      overrides: [
        agentServiceProvider
            .overrideWithValue(agentService ?? mockAgentService),
        taskAgentServiceProvider
            .overrideWithValue(taskAgentService ?? mockTaskAgentService),
        // Override identity provider to prevent real DB access on invalidation
        agentIdentityProvider.overrideWith((ref, agentId) async => null),
      ],
    );
  }

  group('AgentControls', () {
    testWidgets('shows Pause button when lifecycle is active', (tester) async {
      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.active),
      );
      await tester.pump();

      expect(find.text('Pause'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('shows Resume button when lifecycle is dormant',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.dormant),
      );
      await tester.pump();

      expect(find.text('Resume'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('does not show Pause when dormant', (tester) async {
      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.dormant),
      );
      await tester.pump();

      expect(find.text('Pause'), findsNothing);
    });

    testWidgets('does not show Resume when active', (tester) async {
      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.active),
      );
      await tester.pump();

      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('shows Re-analyze button when active', (tester) async {
      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.active),
      );
      await tester.pump();

      expect(find.text('Re-analyze'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('shows Re-analyze button when dormant', (tester) async {
      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.dormant),
      );
      await tester.pump();

      expect(find.text('Re-analyze'), findsOneWidget);
    });

    testWidgets('shows Destroy button when active', (tester) async {
      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.active),
      );
      await tester.pump();

      expect(find.text('Destroy'), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);
    });

    testWidgets(
      'shows destroyed message when lifecycle is destroyed',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.destroyed),
        );
        await tester.pump();

        expect(
          find.text('This agent has been destroyed.'),
          findsOneWidget,
        );
        expect(find.text('Pause'), findsNothing);
        expect(find.text('Resume'), findsNothing);
        expect(find.text('Re-analyze'), findsNothing);
        expect(find.text('Destroy'), findsNothing);
      },
    );

    testWidgets('Pause button calls pauseAgent on service', (tester) async {
      when(() => mockAgentService.pauseAgent(testAgentId))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.active),
      );
      await tester.pump();

      await tester.tap(find.text('Pause'));
      await tester.pump();

      verify(() => mockAgentService.pauseAgent(testAgentId)).called(1);
    });

    testWidgets('Resume button calls resumeAgent and restores subscriptions',
        (tester) async {
      when(() => mockAgentService.resumeAgent(testAgentId))
          .thenAnswer((_) async => true);
      when(() => mockTaskAgentService.restoreSubscriptionsForAgent(testAgentId))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.dormant),
      );
      await tester.pump();

      await tester.tap(find.text('Resume'));
      await tester.pump();

      verify(() => mockAgentService.resumeAgent(testAgentId)).called(1);
      verify(
        () => mockTaskAgentService.restoreSubscriptionsForAgent(testAgentId),
      ).called(1);
    });

    testWidgets('Re-analyze button calls triggerReanalysis', (tester) async {
      when(() => mockTaskAgentService.triggerReanalysis(testAgentId))
          .thenReturn(null);

      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.active),
      );
      await tester.pump();

      await tester.tap(find.text('Re-analyze'));
      await tester.pump();

      verify(() => mockTaskAgentService.triggerReanalysis(testAgentId))
          .called(1);
    });

    testWidgets('Destroy button shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.active),
      );
      await tester.pump();

      await tester.tap(find.text('Destroy'));
      await tester.pump();

      expect(find.text('Destroy Agent?'), findsOneWidget);
      expect(
        find.text(
          'This will permanently deactivate the agent. '
          'Its history will be preserved for audit.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets(
      'Destroy dialog Cancel does not call destroyAgent',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.active),
        );
        await tester.pump();

        await tester.tap(find.text('Destroy'));
        await tester.pump();

        await tester.tap(find.text('Cancel'));
        await tester.pump();

        verifyNever(() => mockAgentService.destroyAgent(any()));
      },
    );

    testWidgets(
      'Destroy dialog Confirm calls destroyAgent',
      (tester) async {
        when(() => mockAgentService.destroyAgent(testAgentId))
            .thenAnswer((_) async => true);

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.active),
        );
        await tester.pump();

        await tester.tap(find.text('Destroy'));
        await tester.pump();

        // Tap the "Destroy" button inside the dialog.
        // There are now two "Destroy" texts: the button behind the dialog
        // and the dialog confirm button. Tap the last one (dialog).
        final destroyButtons = find.text('Destroy');
        await tester.tap(destroyButtons.last);
        await tester.pump();

        verify(() => mockAgentService.destroyAgent(testAgentId)).called(1);
      },
    );

    testWidgets(
      'Destroyed state shows Delete permanently button',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.destroyed),
        );
        await tester.pump();

        expect(find.text('Delete permanently'), findsOneWidget);
        expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'Delete permanently button shows confirmation dialog',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.destroyed),
        );
        await tester.pump();

        await tester.tap(find.text('Delete permanently'));
        await tester.pump();

        expect(find.text('Delete Agent?'), findsOneWidget);
        expect(
          find.text(
            'This will permanently delete all data for this agent, '
            'including its history, reports, and observations. '
            'This cannot be undone.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Delete dialog Cancel does not call deleteAgent',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.destroyed),
        );
        await tester.pump();

        await tester.tap(find.text('Delete permanently'));
        await tester.pump();

        await tester.tap(find.text('Cancel'));
        await tester.pump();

        verifyNever(() => mockAgentService.deleteAgent(any()));
      },
    );

    testWidgets(
      'Delete dialog Confirm calls deleteAgent',
      (tester) async {
        when(() => mockAgentService.deleteAgent(testAgentId))
            .thenAnswer((_) async {});

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.destroyed),
        );
        await tester.pump();

        await tester.tap(find.text('Delete permanently'));
        await tester.pump();

        // Tap the "Delete permanently" button in the dialog.
        final deleteButtons = find.text('Delete permanently');
        await tester.tap(deleteButtons.last);
        await tester.pump();

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
        when(() => mockAgentService.pauseAgent(testAgentId))
            .thenThrow(Exception('network error'));

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
        when(() => mockAgentService.pauseAgent(testAgentId))
            .thenAnswer((_) => completer.future);

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
        when(() => mockAgentService.resumeAgent(testAgentId))
            .thenThrow(Exception('resume failed'));

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
        when(() => mockAgentService.destroyAgent(testAgentId))
            .thenThrow(Exception('destroy failed'));

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
        when(() => mockTaskAgentService.triggerReanalysis(testAgentId))
            .thenReturn(null);

        await tester.pumpWidget(
          buildSubject(lifecycle: AgentLifecycle.dormant),
        );
        await tester.pump();

        await tester.tap(find.text('Re-analyze'));
        await tester.pump();

        verify(() => mockTaskAgentService.triggerReanalysis(testAgentId))
            .called(1);
      },
    );

    testWidgets(
      'shows snackbar when triggerReanalysis throws',
      (tester) async {
        when(() => mockTaskAgentService.triggerReanalysis(testAgentId))
            .thenThrow(Exception('reanalysis failed'));

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
        when(() => mockAgentService.deleteAgent(testAgentId))
            .thenAnswer((_) => completer.future);

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
