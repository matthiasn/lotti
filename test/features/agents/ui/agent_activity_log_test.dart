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
      FutureOr<String?> Function(Ref, String)? payloadOverride,
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
          if (payloadOverride != null)
            agentMessagePayloadTextProvider.overrideWith(payloadOverride),
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

    testWidgets('shows error message when loading fails', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          messagesValue: AsyncValue<List<AgentDomainEntity>>.error(
            Exception('DB connection lost'),
            StackTrace.current,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('DB connection lost'),
        findsOneWidget,
      );
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

    testWidgets('shows correct kind badge labels for all kinds', (
      tester,
    ) async {
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

    testWidgets('disambiguates the system-kind row flavors', (tester) async {
      // `system` is the log's bookkeeping kind: a milestone marker, an input
      // retraction, and the persisted system PROMPT all share it. The badge
      // must name what each row actually is — a bare "System" badge made the
      // wake-completed marker look like a late-arriving system prompt.
      final messages = <AgentDomainEntity>[
        makeTestMessage(
          id: 'msg-prompt',
          kind: AgentMessageKind.system,
          createdAt: DateTime(2024, 3, 15, 10),
          contentEntryId: 'sha256-v1:prompt-digest',
        ),
        makeTestMessage(
          id: 'msg-milestone',
          kind: AgentMessageKind.system,
          createdAt: DateTime(2024, 3, 15, 10),
          metadata: const AgentMessageMetadata(
            milestone: AgentMilestone.wakeCompleted,
          ),
        ),
        makeTestMessage(
          id: 'msg-retraction',
          kind: AgentMessageKind.system,
          createdAt: DateTime(2024, 3, 15, 10),
          metadata: const AgentMessageMetadata(
            retractsContentEntryId: 'entry-gone',
          ),
        ),
      ];

      await tester.pumpWidget(
        buildSubject(
          messagesValue: AsyncValue.data(messages),
          payloadOverride: (ref, id) async => 'You are a Task Agent…',
        ),
      );
      await tester.pump();

      expect(find.text('System Prompt'), findsOneWidget);
      expect(find.text('Milestone'), findsOneWidget);
      expect(find.text('Retraction'), findsOneWidget);
      expect(find.text('System'), findsNothing);
      // The milestone row names its marker inline.
      expect(find.text('wakeCompleted'), findsOneWidget);
      // Only the prompt row carries a payload, so exactly one row is
      // expandable.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Expanding the prompt row reveals the persisted prompt text.
      await tester.tap(find.text('System Prompt'));
      await tester.pump();
      // Extra pump for the async payload provider to resolve.
      await tester.pump();
      expect(find.text('You are a Task Agent…'), findsOneWidget);
    });

    testWidgets('shows tool name as text (not Chip) for action messages', (
      tester,
    ) async {
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
      // Tool name is rendered as plain Text, not a Chip widget.
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('action kind with contentId is expandable', (tester) async {
      final messages = <AgentDomainEntity>[
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.action,
          createdAt: DateTime(2024, 3, 15, 10),
          contentEntryId: 'entry-abc-123',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(
          messagesValue: AsyncValue.data(messages),
          payloadOverride: (ref, id) async => 'action payload text',
        ),
      );
      await tester.pump();

      // Expand icon should be shown for any kind with a contentId.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tap to expand and see the payload text.
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      // Extra pump for the async provider to resolve.
      await tester.pump();

      expect(find.text('action payload text'), findsOneWidget);
    });

    testWidgets('observation messages are expandable with payload text', (
      tester,
    ) async {
      final messages = <AgentDomainEntity>[
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 3, 15, 10),
          contentEntryId: 'payload-001',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(
          messagesValue: AsyncValue.data(messages),
          payloadOverride: (ref, payloadId) async =>
              'This is the observation text',
        ),
      );
      await tester.pump();

      // Expand icon should be visible
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Text should not be visible initially
      expect(find.text('This is the observation text'), findsNothing);

      // Tap to expand
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      // Extra pump for the async provider to resolve
      await tester.pump();

      // Now the observation text should be visible
      expect(find.text('This is the observation text'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
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
  });
}
