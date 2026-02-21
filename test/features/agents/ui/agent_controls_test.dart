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
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.active),
      );
      await tester.pump();

      await tester.tap(find.text('Pause'));
      await tester.pump();

      verify(() => mockAgentService.pauseAgent(testAgentId)).called(1);
    });

    testWidgets('Resume button calls resumeAgent on service', (tester) async {
      when(() => mockAgentService.resumeAgent(testAgentId))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        buildSubject(lifecycle: AgentLifecycle.dormant),
      );
      await tester.pump();

      await tester.tap(find.text('Resume'));
      await tester.pump();

      verify(() => mockAgentService.resumeAgent(testAgentId)).called(1);
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
            .thenAnswer((_) async {});

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
  });
}
