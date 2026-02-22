import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_conversation_log.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

const String _testAgentId = kTestAgentId;

void main() {
  Widget buildSubject({
    required AsyncValue<Map<String, List<AgentDomainEntity>>> threadsValue,
    AsyncValue<List<AgentDomainEntity>> reportsValue =
        const AsyncValue.data([]),
    FutureOr<String?> Function(Ref, String)? payloadOverride,
  }) {
    return makeTestableWidgetWithScaffold(
      const AgentConversationLog(agentId: _testAgentId),
      overrides: [
        agentMessagesByThreadProvider.overrideWith(
          (ref, agentId) => threadsValue.when(
            data: (data) async => data,
            loading: () =>
                Completer<Map<String, List<AgentDomainEntity>>>().future,
            error: Future<Map<String, List<AgentDomainEntity>>>.error,
          ),
        ),
        agentReportHistoryProvider.overrideWith(
          (ref, agentId) => reportsValue.when(
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

  group('AgentConversationLog', () {
    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          threadsValue:
              const AsyncValue<Map<String, List<AgentDomainEntity>>>.loading(),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when loading fails', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          threadsValue: AsyncValue<Map<String, List<AgentDomainEntity>>>.error(
            Exception('Thread error'),
            StackTrace.current,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Thread error'), findsOneWidget);
    });

    testWidgets('shows empty state when no threads', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          threadsValue: const AsyncValue.data({}),
        ),
      );
      await tester.pump();

      expect(find.text('No conversations yet.'), findsOneWidget);
    });

    testWidgets('shows thread tiles with message count and tool call count',
        (tester) async {
      final threads = <String, List<AgentDomainEntity>>{
        'thread-1': [
          makeTestMessage(
            id: 'msg-1',
            threadId: 'thread-1',
            kind: AgentMessageKind.user,
            createdAt: DateTime(2024, 3, 15, 10),
          ),
          makeTestMessage(
            id: 'msg-2',
            threadId: 'thread-1',
            kind: AgentMessageKind.action,
            createdAt: DateTime(2024, 3, 15, 10, 1),
            toolName: 'set_task_title',
          ),
          makeTestMessage(
            id: 'msg-3',
            threadId: 'thread-1',
            kind: AgentMessageKind.toolResult,
            createdAt: DateTime(2024, 3, 15, 10, 2),
          ),
        ],
      };

      await tester.pumpWidget(
        buildSubject(threadsValue: AsyncValue.data(threads)),
      );
      await tester.pump();

      // Thread tile shows message count and tool call count.
      expect(find.textContaining('3 messages'), findsOneWidget);
      expect(find.textContaining('1 tool calls'), findsOneWidget);
    });

    testWidgets('shows report inline when thread has matching report',
        (tester) async {
      final threads = <String, List<AgentDomainEntity>>{
        'thread-abc': [
          makeTestMessage(
            id: 'msg-1',
            threadId: 'thread-abc',
            kind: AgentMessageKind.user,
            createdAt: DateTime(2024, 3, 15, 10),
          ),
        ],
      };

      final reports = <AgentDomainEntity>[
        AgentDomainEntity.agentReport(
          id: 'report-1',
          agentId: _testAgentId,
          scope: 'current',
          createdAt: DateTime(2024, 3, 15, 10, 5),
          vectorClock: null,
          content: '# Wake Report\n\nTask looks good.',
          threadId: 'thread-abc',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(
          threadsValue: AsyncValue.data(threads),
          reportsValue: AsyncValue.data(reports),
        ),
      );
      await tester.pumpAndSettle();

      // The report badge and label should be visible.
      expect(find.text('Report'), findsOneWidget);
      expect(
        find.text('Report produced during this wake'),
        findsOneWidget,
      );
    });

    testWidgets('does not show report when threadId does not match',
        (tester) async {
      final threads = <String, List<AgentDomainEntity>>{
        'thread-abc': [
          makeTestMessage(
            id: 'msg-1',
            threadId: 'thread-abc',
            kind: AgentMessageKind.user,
            createdAt: DateTime(2024, 3, 15, 10),
          ),
        ],
      };

      final reports = <AgentDomainEntity>[
        AgentDomainEntity.agentReport(
          id: 'report-1',
          agentId: _testAgentId,
          scope: 'current',
          createdAt: DateTime(2024, 3, 15, 10, 5),
          vectorClock: null,
          content: '# Different thread report',
          threadId: 'thread-xyz',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(
          threadsValue: AsyncValue.data(threads),
          reportsValue: AsyncValue.data(reports),
        ),
      );
      await tester.pumpAndSettle();

      // No report card should appear since threadIds don't match.
      expect(find.text('Report'), findsNothing);
    });

    testWidgets('does not show report when report has no threadId',
        (tester) async {
      final threads = <String, List<AgentDomainEntity>>{
        'thread-abc': [
          makeTestMessage(
            id: 'msg-1',
            threadId: 'thread-abc',
            kind: AgentMessageKind.user,
            createdAt: DateTime(2024, 3, 15, 10),
          ),
        ],
      };

      final reports = <AgentDomainEntity>[
        makeTestReport(
          id: 'report-1',
          createdAt: DateTime(2024, 3, 15, 10, 5),
          content: '# Legacy report without threadId',
        ),
      ];

      await tester.pumpWidget(
        buildSubject(
          threadsValue: AsyncValue.data(threads),
          reportsValue: AsyncValue.data(reports),
        ),
      );
      await tester.pumpAndSettle();

      // No report card for reports without threadId.
      expect(find.text('Report'), findsNothing);
    });

    testWidgets('sorts threads most-recent-first', (tester) async {
      final threads = <String, List<AgentDomainEntity>>{
        'thread-old': [
          makeTestMessage(
            id: 'msg-old',
            threadId: 'thread-old',
            createdAt: DateTime(2024, 3, 15, 8),
          ),
        ],
        'thread-new': [
          makeTestMessage(
            id: 'msg-new',
            threadId: 'thread-new',
            createdAt: DateTime(2024, 3, 15, 14),
          ),
        ],
      };

      await tester.pumpWidget(
        buildSubject(threadsValue: AsyncValue.data(threads)),
      );
      await tester.pump();

      // The newer thread should appear first.
      final tiles = tester.widgetList<ExpansionTile>(
        find.byType(ExpansionTile),
      );
      expect(tiles.length, 2);
      // First tile should be the newer thread (initially expanded).
      expect(tiles.first.initiallyExpanded, isTrue);
    });

    testWidgets('first thread is expanded by default', (tester) async {
      final threads = <String, List<AgentDomainEntity>>{
        'thread-1': [
          makeTestMessage(
            id: 'msg-1',
            threadId: 'thread-1',
            createdAt: DateTime(2024, 3, 15, 10),
          ),
        ],
      };

      await tester.pumpWidget(
        buildSubject(threadsValue: AsyncValue.data(threads)),
      );
      await tester.pump();

      final tile = tester.widget<ExpansionTile>(
        find.byType(ExpansionTile),
      );
      expect(tile.initiallyExpanded, isTrue);
    });

    testWidgets('tool call messages start expanded in threads', (tester) async {
      final threads = <String, List<AgentDomainEntity>>{
        'thread-1': [
          makeTestMessage(
            id: 'msg-1',
            threadId: 'thread-1',
            kind: AgentMessageKind.action,
            createdAt: DateTime(2024, 3, 15, 10),
            contentEntryId: 'payload-1',
            toolName: 'set_task_title',
          ),
        ],
      };

      await tester.pumpWidget(
        buildSubject(
          threadsValue: AsyncValue.data(threads),
          payloadOverride: (ref, id) async => '{"title": "New"}',
        ),
      );
      await tester.pump();
      await tester.pump();

      // Tool call should be expanded (collapse icon visible).
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('{"title": "New"}'), findsOneWidget);
    });
  });
}
