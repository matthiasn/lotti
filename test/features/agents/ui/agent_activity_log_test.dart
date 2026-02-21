import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_activity_log.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  const testAgentId = kTestAgentId;

  group('AgentActivityLog', () {
    Widget buildSubject({
      required AsyncValue<List<AgentDomainEntity>> messagesValue,
    }) {
      return makeTestableWidgetWithScaffold(
        const AgentActivityLog(agentId: testAgentId),
        overrides: [
          agentRecentMessagesProvider.overrideWith(
            (ref, agentId) => messagesValue.when(
              data: (data) async => data,
              loading: () => Completer<List<AgentDomainEntity>>().future,
              error: Future<List<AgentDomainEntity>>.error,
            ),
          ),
        ],
      );
    }

    testWidgets('shows loading indicator while messages load', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          messagesValue: const AsyncValue<List<AgentDomainEntity>>.loading(),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no messages exist', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          messagesValue: const AsyncValue.data([]),
        ),
      );
      await tester.pump();

      expect(find.text('No messages yet.'), findsOneWidget);
    });

    testWidgets('shows message cards with kind badges', (tester) async {
      final messages = <AgentDomainEntity>[
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 3, 15, 10, 30, 45),
        ),
        makeTestMessage(
          id: 'msg-2',
          kind: AgentMessageKind.action,
          createdAt: DateTime(2024, 3, 15, 10, 31),
          toolName: 'analyzeTask',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(messagesValue: AsyncValue.data(messages)),
      );
      await tester.pump();

      expect(find.text('Observation'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
    });

    testWidgets('shows correct kind badge labels for all kinds',
        (tester) async {
      final messages = <AgentDomainEntity>[
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 3, 15, 10),
        ),
        makeTestMessage(
          id: 'msg-2',
          kind: AgentMessageKind.user,
          createdAt: DateTime(2024, 3, 15, 11),
        ),
        makeTestMessage(
          id: 'msg-3',
          createdAt: DateTime(2024, 3, 15, 12),
        ),
        makeTestMessage(
          id: 'msg-4',
          kind: AgentMessageKind.action,
          createdAt: DateTime(2024, 3, 15, 13),
        ),
        makeTestMessage(
          id: 'msg-5',
          kind: AgentMessageKind.toolResult,
          createdAt: DateTime(2024, 3, 15, 14),
        ),
        makeTestMessage(
          id: 'msg-6',
          kind: AgentMessageKind.summary,
          createdAt: DateTime(2024, 3, 15, 15),
        ),
        makeTestMessage(
          id: 'msg-7',
          kind: AgentMessageKind.system,
          createdAt: DateTime(2024, 3, 15, 16),
        ),
      ];

      await tester.pumpWidget(
        buildSubject(messagesValue: AsyncValue.data(messages)),
      );
      await tester.pump();

      expect(find.text('Observation'), findsOneWidget);
      expect(find.text('User'), findsOneWidget);
      expect(find.text('Thought'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Tool Result'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('shows tool name chip for action messages', (tester) async {
      final messages = <AgentDomainEntity>[
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.action,
          createdAt: DateTime(2024, 3, 15, 10),
          toolName: 'analyzeTask',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(messagesValue: AsyncValue.data(messages)),
      );
      await tester.pump();

      expect(find.text('analyzeTask'), findsOneWidget);
    });

    testWidgets('shows content entry ID when present', (tester) async {
      final messages = <AgentDomainEntity>[
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 3, 15, 10),
          contentEntryId: 'entry-abc-123',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(messagesValue: AsyncValue.data(messages)),
      );
      await tester.pump();

      expect(find.text('Content: entry-abc-123'), findsOneWidget);
    });

    testWidgets('shows error message in red when present', (tester) async {
      final messages = <AgentDomainEntity>[
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.toolResult,
          createdAt: DateTime(2024, 3, 15, 10),
          errorMessage: 'Tool execution failed: timeout',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(messagesValue: AsyncValue.data(messages)),
      );
      await tester.pump();

      expect(
        find.text('Tool execution failed: timeout'),
        findsOneWidget,
      );
    });

    testWidgets('shows formatted timestamp for messages', (tester) async {
      final messages = <AgentDomainEntity>[
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 3, 15, 9, 5, 3),
        ),
      ];

      await tester.pumpWidget(
        buildSubject(messagesValue: AsyncValue.data(messages)),
      );
      await tester.pump();

      expect(find.text('2024-03-15 09:05:03'), findsOneWidget);
    });

    testWidgets('renders multiple messages as a list', (tester) async {
      final messages = <AgentDomainEntity>[
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 3, 15, 10),
        ),
        makeTestMessage(
          id: 'msg-2',
          kind: AgentMessageKind.action,
          createdAt: DateTime(2024, 3, 15, 11),
        ),
        makeTestMessage(
          id: 'msg-3',
          kind: AgentMessageKind.toolResult,
          createdAt: DateTime(2024, 3, 15, 12),
        ),
      ];

      await tester.pumpWidget(
        buildSubject(messagesValue: AsyncValue.data(messages)),
      );
      await tester.pump();

      expect(find.byType(Card), findsNWidgets(3));
    });

    testWidgets(
      'ignores non-message entities in the list',
      (tester) async {
        // Include a non-message entity (e.g., an agent identity) in the list.
        // The widget uses `mapOrNull(agentMessage:)` which returns null for
        // non-message types, falling back to SizedBox.shrink.
        final entities = <AgentDomainEntity>[
          makeTestMessage(
            id: 'msg-1',
            kind: AgentMessageKind.observation,
            createdAt: DateTime(2024, 3, 15, 10),
          ),
          AgentDomainEntity.agent(
            id: 'identity-1',
            agentId: 'agent-001',
            kind: 'task_agent',
            displayName: 'Test Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
        ];

        await tester.pumpWidget(
          buildSubject(messagesValue: AsyncValue.data(entities)),
        );
        await tester.pump();

        // Only the message entity renders a Card
        expect(find.byType(Card), findsOneWidget);
        expect(find.text('Observation'), findsOneWidget);
      },
    );
  });
}
