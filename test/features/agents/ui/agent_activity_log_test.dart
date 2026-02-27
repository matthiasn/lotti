import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_activity_log.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

// Re-usable observation messages for AgentObservationLog tests.
List<AgentDomainEntity> _makeObservationMessages() => [
      makeTestMessage(
        id: 'obs-1',
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15, 10),
        contentEntryId: 'payload-obs-1',
      ),
      makeTestMessage(
        id: 'obs-2',
        kind: AgentMessageKind.observation,
        createdAt: DateTime(2024, 3, 15, 11),
        contentEntryId: 'payload-obs-2',
      ),
    ];

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
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Tap to expand and see the payload text.
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      // Extra pump for the async provider to resolve.
      await tester.pump();

      expect(find.text('action payload text'), findsOneWidget);
    });

    testWidgets('observation messages are expandable with payload text',
        (tester) async {
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
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Text should not be visible initially
      expect(find.text('This is the observation text'), findsNothing);

      // Tap to expand
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      // Extra pump for the async provider to resolve
      await tester.pump();

      // Now the observation text should be visible
      expect(find.text('This is the observation text'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
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
      'thought messages are expandable',
      (tester) async {
        final messages = <AgentDomainEntity>[
          makeTestMessage(
            id: 'msg-1',
            createdAt: DateTime(2024, 3, 15, 10),
            contentEntryId: 'payload-thought-001',
          ),
        ];

        await tester.pumpWidget(
          buildSubject(
            messagesValue: AsyncValue.data(messages),
            payloadOverride: (ref, payloadId) async => 'Deep thought content',
          ),
        );
        await tester.pump();

        // Expand icon should be visible (thought is expandable)
        expect(find.byIcon(Icons.expand_more), findsOneWidget);

        // Text should not be visible initially
        expect(find.text('Deep thought content'), findsNothing);

        // Tap to expand
        await tester.tap(find.byType(InkWell));
        await tester.pump();
        await tester.pump();

        expect(find.text('Deep thought content'), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsOneWidget);
      },
    );

    testWidgets(
      'expand then collapse hides payload text',
      (tester) async {
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
            payloadOverride: (ref, payloadId) async => 'Observation payload',
          ),
        );
        await tester.pump();

        // Expand
        await tester.tap(find.byType(InkWell));
        await tester.pump();
        await tester.pump();
        expect(find.text('Observation payload'), findsOneWidget);

        // Collapse
        await tester.tap(find.byType(InkWell));
        await tester.pump();
        expect(find.text('Observation payload'), findsNothing);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      },
    );

    testWidgets(
      'payload shows "(no content)" when text is null',
      (tester) async {
        final messages = <AgentDomainEntity>[
          makeTestMessage(
            id: 'msg-1',
            kind: AgentMessageKind.observation,
            createdAt: DateTime(2024, 3, 15, 10),
            contentEntryId: 'payload-null',
          ),
        ];

        await tester.pumpWidget(
          buildSubject(
            messagesValue: AsyncValue.data(messages),
            payloadOverride: (ref, payloadId) async => null,
          ),
        );
        await tester.pump();

        // Expand
        await tester.tap(find.byType(InkWell));
        await tester.pump();
        await tester.pump();

        expect(find.text('(no content)'), findsOneWidget);
      },
    );

    testWidgets(
      'payload shows loading indicator while fetching',
      (tester) async {
        final messages = <AgentDomainEntity>[
          makeTestMessage(
            id: 'msg-1',
            kind: AgentMessageKind.observation,
            createdAt: DateTime(2024, 3, 15, 10),
            contentEntryId: 'payload-slow',
          ),
        ];

        await tester.pumpWidget(
          buildSubject(
            messagesValue: AsyncValue.data(messages),
            payloadOverride: (ref, payloadId) => Completer<String?>().future,
          ),
        );
        await tester.pump();

        // Expand
        await tester.tap(find.byType(InkWell));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'payload shows error text when fetch fails',
      (tester) async {
        final messages = <AgentDomainEntity>[
          makeTestMessage(
            id: 'msg-1',
            kind: AgentMessageKind.observation,
            createdAt: DateTime(2024, 3, 15, 10),
            contentEntryId: 'payload-fail',
          ),
        ];

        await tester.pumpWidget(
          buildSubject(
            messagesValue: AsyncValue.data(messages),
            payloadOverride: (ref, payloadId) =>
                Future<String?>.error(Exception('fetch failed')),
          ),
        );
        await tester.pump();

        // Expand
        await tester.tap(find.byType(InkWell));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.textContaining('fetch failed'), findsOneWidget);
      },
    );

    testWidgets(
      'toolResult kind with contentId is expandable',
      (tester) async {
        final messages = <AgentDomainEntity>[
          makeTestMessage(
            id: 'msg-1',
            kind: AgentMessageKind.toolResult,
            createdAt: DateTime(2024, 3, 15, 10),
            contentEntryId: 'entry-123',
          ),
        ];

        await tester.pumpWidget(
          buildSubject(
            messagesValue: AsyncValue.data(messages),
            payloadOverride: (ref, id) async => 'tool result payload',
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.expand_more), findsOneWidget);

        await tester.tap(find.byType(InkWell));
        await tester.pump();
        // Extra pump for the async provider to resolve.
        await tester.pump();

        expect(find.text('tool result payload'), findsOneWidget);
      },
    );

    testWidgets(
      'message without contentEntryId has no expand icon or content preview',
      (tester) async {
        final messages = <AgentDomainEntity>[
          makeTestMessage(
            id: 'msg-1',
            kind: AgentMessageKind.observation,
            createdAt: DateTime(2024, 3, 15, 10),
            // no contentEntryId
          ),
        ];

        await tester.pumpWidget(
          buildSubject(messagesValue: AsyncValue.data(messages)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.expand_more), findsNothing);
        expect(find.textContaining('Content:'), findsNothing);
      },
    );

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

  group('AgentObservationLog', () {
    Widget buildObservationSubject({
      required AsyncValue<List<AgentDomainEntity>> observationsValue,
      FutureOr<String?> Function(Ref, String)? payloadOverride,
    }) {
      return makeTestableWidgetWithScaffold(
        const AgentObservationLog(agentId: testAgentId),
        overrides: [
          agentObservationMessagesProvider.overrideWith(
            (ref, agentId) => observationsValue.when(
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

    testWidgets('shows loading indicator while observations load',
        (tester) async {
      await tester.pumpWidget(
        buildObservationSubject(
          observationsValue:
              const AsyncValue<List<AgentDomainEntity>>.loading(),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when loading fails', (tester) async {
      await tester.pumpWidget(
        buildObservationSubject(
          observationsValue: AsyncValue<List<AgentDomainEntity>>.error(
            Exception('DB error'),
            StackTrace.current,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('DB error'), findsOneWidget);
    });

    testWidgets('shows empty state when no observations exist', (tester) async {
      await tester.pumpWidget(
        buildObservationSubject(
          observationsValue: const AsyncValue.data([]),
        ),
      );
      await tester.pump();

      expect(find.text('No observations recorded yet.'), findsOneWidget);
    });

    testWidgets('shows observation cards expanded by default', (tester) async {
      await tester.pumpWidget(
        buildObservationSubject(
          observationsValue: AsyncValue.data(_makeObservationMessages()),
          payloadOverride: (ref, payloadId) async =>
              'Observation insight $payloadId',
        ),
      );
      await tester.pump();
      // Extra pump for async payload resolution.
      await tester.pump();

      // Both observation payloads should be visible without tapping.
      expect(
        find.text('Observation insight payload-obs-1'),
        findsOneWidget,
      );
      expect(
        find.text('Observation insight payload-obs-2'),
        findsOneWidget,
      );
      // Collapse icons should be shown (not expand).
      expect(find.byIcon(Icons.expand_less), findsNWidgets(2));
    });

    testWidgets('can collapse an initially expanded observation',
        (tester) async {
      await tester.pumpWidget(
        buildObservationSubject(
          observationsValue: AsyncValue.data([
            makeTestMessage(
              id: 'obs-1',
              kind: AgentMessageKind.observation,
              createdAt: DateTime(2024, 3, 15, 10),
              contentEntryId: 'payload-obs-1',
            ),
          ]),
          payloadOverride: (ref, payloadId) async => 'Insight text',
        ),
      );
      await tester.pump();
      await tester.pump();

      // Initially expanded — text visible.
      expect(find.text('Insight text'), findsOneWidget);

      // Tap to collapse.
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(find.text('Insight text'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('shows only observation kind badges', (tester) async {
      await tester.pumpWidget(
        buildObservationSubject(
          observationsValue: AsyncValue.data(_makeObservationMessages()),
        ),
      );
      await tester.pump();

      // All cards should show Observation badges.
      expect(find.text('Observation'), findsNWidgets(2));
      // No other kind badges should appear.
      expect(find.text('Thought'), findsNothing);
      expect(find.text('Action'), findsNothing);
      expect(find.text('Tool Result'), findsNothing);
    });
  });

  group('AgentActivityLog.fromMessages with expandToolCalls', () {
    Widget buildFromMessages({
      required List<AgentMessageEntity> messages,
      bool expandToolCalls = false,
      FutureOr<String?> Function(Ref, String)? payloadOverride,
    }) {
      return makeTestableWidgetWithScaffold(
        AgentActivityLog.fromMessages(
          agentId: testAgentId,
          messages: messages,
          expandToolCalls: expandToolCalls,
        ),
        overrides: [
          if (payloadOverride != null)
            agentMessagePayloadTextProvider.overrideWith(payloadOverride),
        ],
      );
    }

    testWidgets('action messages are collapsed by default', (tester) async {
      final messages = [
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.action,
          createdAt: DateTime(2024, 3, 15, 10),
          contentEntryId: 'payload-1',
          toolName: 'set_task_title',
        ),
      ];

      await tester.pumpWidget(
        buildFromMessages(
          messages: messages,
          payloadOverride: (ref, id) async => '{"title": "New Title"}',
        ),
      );
      await tester.pump();

      // Should show expand icon (collapsed).
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('{"title": "New Title"}'), findsNothing);
    });

    testWidgets('action messages start expanded when expandToolCalls is true',
        (tester) async {
      final messages = [
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.action,
          createdAt: DateTime(2024, 3, 15, 10),
          contentEntryId: 'payload-1',
          toolName: 'set_task_title',
        ),
      ];

      await tester.pumpWidget(
        buildFromMessages(
          messages: messages,
          expandToolCalls: true,
          payloadOverride: (ref, id) async => '{"title": "New Title"}',
        ),
      );
      await tester.pump();
      await tester.pump();

      // Should show collapse icon (expanded).
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('{"title": "New Title"}'), findsOneWidget);
    });

    testWidgets(
        'toolResult messages start expanded when expandToolCalls is true',
        (tester) async {
      final messages = [
        makeTestMessage(
          id: 'msg-1',
          kind: AgentMessageKind.toolResult,
          createdAt: DateTime(2024, 3, 15, 10),
          contentEntryId: 'payload-1',
        ),
      ];

      await tester.pumpWidget(
        buildFromMessages(
          messages: messages,
          expandToolCalls: true,
          payloadOverride: (ref, id) async => 'Success: title updated',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('Success: title updated'), findsOneWidget);
    });

    testWidgets('non-tool messages remain collapsed with expandToolCalls',
        (tester) async {
      final messages = [
        makeTestMessage(
          id: 'msg-1',
          createdAt: DateTime(2024, 3, 15, 10),
          contentEntryId: 'payload-1',
        ),
      ];

      await tester.pumpWidget(
        buildFromMessages(
          messages: messages,
          expandToolCalls: true,
          payloadOverride: (ref, id) async => 'thinking...',
        ),
      );
      await tester.pump();

      // Thought is not a tool call, so it should remain collapsed.
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('thinking...'), findsNothing);
    });
  });

  group('AgentReportHistoryLog', () {
    Widget buildReportHistory({
      required AsyncValue<List<AgentDomainEntity>> reportsValue,
    }) {
      return makeTestableWidgetWithScaffold(
        const AgentReportHistoryLog(agentId: testAgentId),
        overrides: [
          agentReportHistoryProvider.overrideWith(
            (ref, agentId) => reportsValue.when(
              data: (data) async => data,
              loading: () => Completer<List<AgentDomainEntity>>().future,
              error: Future<List<AgentDomainEntity>>.error,
            ),
          ),
        ],
      );
    }

    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(
        buildReportHistory(
          reportsValue: const AsyncValue<List<AgentDomainEntity>>.loading(),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message', (tester) async {
      await tester.pumpWidget(
        buildReportHistory(
          reportsValue: AsyncValue<List<AgentDomainEntity>>.error(
            Exception('DB error'),
            StackTrace.current,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('error occurred'),
        findsOneWidget,
      );
    });

    testWidgets('shows empty state when no reports', (tester) async {
      await tester.pumpWidget(
        buildReportHistory(
          reportsValue: const AsyncValue.data([]),
        ),
      );
      await tester.pump();

      expect(find.text('No report snapshots yet.'), findsOneWidget);
    });

    testWidgets('shows report cards with timestamps', (tester) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-1',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          content: '# First Report',
        ),
        makeTestReport(
          id: 'report-2',
          createdAt: DateTime(2024, 3, 15, 14),
          content: '# Second Report',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pump();

      // Both cards should have the "Report" badge.
      expect(find.text('Report'), findsNWidgets(2));
      // Timestamps should be shown (formatAgentDateTime uses HH:mm, no seconds).
      expect(find.text('2024-03-15 10:30'), findsOneWidget);
      expect(find.text('2024-03-15 14:00'), findsOneWidget);
    });

    testWidgets('first report is expanded by default', (tester) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-1',
          createdAt: DateTime(2024, 3, 15, 10),
          content: 'Report content here',
        ),
        makeTestReport(
          id: 'report-2',
          createdAt: DateTime(2024, 3, 15, 14),
          content: 'Second report content',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pumpAndSettle();

      // First report expanded — GptMarkdown renders content.
      // The second report should be collapsed.
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('tapping a collapsed report expands it', (tester) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-1',
          createdAt: DateTime(2024, 3, 15, 10),
          content: 'Only report',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pumpAndSettle();

      // Initially expanded (index 0).
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Tap to collapse.
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Tap to expand again.
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('collapsed report shows only TLDR section', (tester) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-first',
          createdAt: DateTime(2024, 3, 15, 10),
          content: '## 📋 TLDR\n'
              'Summary of the work.\n\n'
              '## ✅ Achieved\n'
              '- Built a spaceship\n',
        ),
        makeTestReport(
          id: 'report-second',
          createdAt: DateTime(2024, 3, 15, 9),
          content: '## 📋 TLDR\n'
              'Earlier summary.\n\n'
              '## ✅ Achieved\n'
              '- Prepared launch pad\n',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pumpAndSettle();

      // Second report is collapsed — its GptMarkdown should render
      // only the TLDR section, not the Achieved section.
      final markdowns =
          tester.widgetList<GptMarkdown>(find.byType(GptMarkdown)).toList();
      // First report expanded (full content), second collapsed (TLDR only)
      expect(markdowns.length, 2);
      // The collapsed one should NOT contain "Achieved" content
      expect(markdowns.last.data, contains('TLDR'));
      expect(markdowns.last.data, isNot(contains('Achieved')));
    });

    testWidgets('collapsed report uses first paragraph as TLDR fallback',
        (tester) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-fallback',
          createdAt: DateTime(2024, 3, 15, 10),
          content: 'This has no TLDR heading.\n\n'
              'Second paragraph with details.',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pumpAndSettle();

      // Collapse the first (auto-expanded) report
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // The collapsed content should be just the first paragraph
      final markdowns =
          tester.widgetList<GptMarkdown>(find.byType(GptMarkdown)).toList();
      expect(markdowns.length, 1);
      expect(markdowns.first.data, contains('no TLDR heading'));
      expect(markdowns.first.data, isNot(contains('Second paragraph')));
    });

    testWidgets(
        'collapsed report shows TLDR-only section when it is the last section',
        (tester) async {
      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-tldr-only',
          createdAt: DateTime(2024, 3, 15, 10),
          content: '## 📋 TLDR\n'
              'This is the entire report.',
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(reports)),
      );
      await tester.pumpAndSettle();

      // Collapse the report
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      final markdowns =
          tester.widgetList<GptMarkdown>(find.byType(GptMarkdown)).toList();
      expect(markdowns.length, 1);
      expect(markdowns.first.data, contains('TLDR'));
      expect(markdowns.first.data, contains('entire report'));
    });

    testWidgets('ignores non-report entities in the list', (tester) async {
      final mixed = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-1',
          createdAt: DateTime(2024, 3, 15, 10),
          content: 'A report',
        ),
        // Include a non-report entity.
        makeTestMessage(
          id: 'msg-1',
          createdAt: DateTime(2024, 3, 15, 11),
        ),
      ];

      await tester.pumpWidget(
        buildReportHistory(reportsValue: AsyncValue.data(mixed)),
      );
      await tester.pump();

      // Only the report card should render.
      expect(find.text('Report'), findsOneWidget);
    });
  });
}
