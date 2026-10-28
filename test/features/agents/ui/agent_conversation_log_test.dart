import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_conversation_log.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../ai_consumption/test_utils.dart';
import '../test_utils.dart';

const String _testAgentId = kTestAgentId;

void main() {
  Widget buildSubject({
    required AsyncValue<Map<String, List<AgentDomainEntity>>> threadsValue,
    AsyncValue<List<AgentDomainEntity>> reportsValue = const AsyncValue.data(
      [],
    ),
    FutureOr<String?> Function(Ref, String)? payloadOverride,
    String? runningThreadId,
    Map<String, WakeRunStatus> statuses = const {},
    MockAgentService? agentService,
  }) {
    return makeTestableWidgetWithScaffold(
      const AgentConversationLog(agentId: _testAgentId),
      overrides: [
        agentRunningThreadIdProvider.overrideWith(
          (ref, agentId) => Stream.value(runningThreadId),
        ),
        agentIsRunningProvider.overrideWith(
          (ref, agentId) => Stream.value(runningThreadId != null),
        ),
        wakeRunStatusForThreadProvider.overrideWith(
          (ref, key) async => statuses[key.$2],
        ),
        if (agentService != null)
          agentServiceProvider.overrideWithValue(agentService),
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

    testWidgets('shows thread tiles with message count and tool call count', (
      tester,
    ) async {
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

    testWidgets('shows report inline when thread has matching report', (
      tester,
    ) async {
      final envelope = makeAiWorkAttribution(
        attributionId: 'thread-report-attribution',
      );
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
          provenance: {
            aiAttributionProvenanceKey: jsonDecode(
              jsonEncode(envelope.toJson()),
            ),
          },
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
      await tester.tap(find.text('Report produced during this wake'));
      await tester.pump();
      expect(find.byType(AiAttributionSummary), findsOneWidget);
    });

    testWidgets('does not show report when threadId does not match', (
      tester,
    ) async {
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

    testWidgets('does not show report when report has no threadId', (
      tester,
    ) async {
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

    testWidgets('shows model ID in thread subtitle when available', (
      tester,
    ) async {
      final threads = <String, List<AgentDomainEntity>>{
        'thread-model': [
          makeTestMessage(
            id: 'msg-1',
            threadId: 'thread-model',
            createdAt: DateTime(2024, 3, 15, 10),
          ),
          makeTestMessage(
            id: 'msg-2',
            threadId: 'thread-model',
            createdAt: DateTime(2024, 3, 15, 10, 2),
          ),
        ],
      };

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const AgentConversationLog(agentId: _testAgentId),
          overrides: [
            agentMessagesByThreadProvider.overrideWith(
              (ref, agentId) async => threads,
            ),
            agentReportHistoryProvider.overrideWith(
              (ref, agentId) async => <AgentDomainEntity>[],
            ),
            modelIdForThreadProvider.overrideWith(
              (ref, args) async => 'models/gemini-3-flash-preview',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      // The model name should appear stripped of prefix.
      expect(find.textContaining('gemini-3-flash-preview'), findsOneWidget);
    });

    for (final (end, label) in [
      (DateTime(2024, 3, 15, 10, 0, 45), '45s'),
      (DateTime(2024, 3, 15, 10, 2, 30), '2m 30s'),
      (DateTime(2024, 3, 15, 11, 5), '1h 5m'),
    ]) {
      testWidgets('shows a $label duration in the thread title', (
        tester,
      ) async {
        final threads = <String, List<AgentDomainEntity>>{
          'thread-dur': [
            makeTestMessage(
              id: 'msg-start',
              threadId: 'thread-dur',
              createdAt: DateTime(2024, 3, 15, 10),
            ),
            makeTestMessage(
              id: 'msg-end',
              threadId: 'thread-dur',
              createdAt: end,
            ),
          ],
        };

        await tester.pumpWidget(
          buildSubject(threadsValue: AsyncValue.data(threads)),
        );
        await tester.pump();

        expect(find.textContaining(label), findsOneWidget);
      });
    }

    testWidgets('shows token count in thread subtitle when available', (
      tester,
    ) async {
      final threads = <String, List<AgentDomainEntity>>{
        'thread-tokens': [
          makeTestMessage(
            id: 'msg-1',
            threadId: 'thread-tokens',
            createdAt: DateTime(2024, 3, 15, 10),
          ),
          makeTestMessage(
            id: 'msg-2',
            threadId: 'thread-tokens',
            createdAt: DateTime(2024, 3, 15, 10, 2),
          ),
        ],
      };

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const AgentConversationLog(agentId: _testAgentId),
          overrides: [
            agentMessagesByThreadProvider.overrideWith(
              (ref, agentId) async => threads,
            ),
            agentReportHistoryProvider.overrideWith(
              (ref, agentId) async => <AgentDomainEntity>[],
            ),
            tokenUsageForThreadProvider.overrideWith(
              (ref, args) async => const AgentTokenUsageSummary(
                modelId: 'models/gemini-2.5-pro',
                inputTokens: 1000,
                outputTokens: 400,
                thoughtsTokens: 100,
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      // The token count should appear formatted in the subtitle.
      expect(find.textContaining('1,500 tokens'), findsOneWidget);
    });

    group('running and stopped threads', () {
      // The newest thread is the previous wake's; the live wake is the older
      // one, so a marker keyed on recency would land on the wrong row.
      final threads = <String, List<AgentDomainEntity>>{
        'newest-thread': [
          makeTestMessage(
            id: 'msg-newest',
            threadId: 'newest-thread',
            createdAt: DateTime(2024, 3, 15, 11),
          ),
        ],
        'live-thread': [
          makeTestMessage(
            id: 'msg-live',
            threadId: 'live-thread',
            createdAt: DateTime(2024, 3, 15, 10),
          ),
        ],
      };

      // Threads resolve first; each row's stop button then subscribes to
      // the running state on its own.
      Future<void> settle(WidgetTester tester) async {
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
      }

      Finder rowOf(String threadId) => find.ancestor(
        of: find.textContaining(threadId.substring(0, 7)),
        matching: find.byType(ExpansionTile),
      );

      Finder inRow(String threadId, Finder finder) =>
          find.descendant(of: rowOf(threadId), matching: finder);

      testWidgets(
        'marks only the running thread, and stops it from its collapsed row',
        (tester) async {
          final agentService = MockAgentService();
          when(() => agentService.abortRunningWake(any())).thenReturn(true);
          await tester.pumpWidget(
            buildSubject(
              threadsValue: AsyncValue.data(threads),
              runningThreadId: 'live-thread',
              agentService: agentService,
            ),
          );
          await settle(tester);

          expect(inRow('live-thread', find.text('Running')), findsOneWidget);
          expect(inRow('newest-thread', find.text('Running')), findsNothing);
          final stop = find.byType(DsAiDiscButton);
          expect(stop, findsOneWidget);
          expect(inRow('live-thread', stop), findsOneWidget);

          await tester.tap(stop);
          await tester.pump();

          verify(() => agentService.abortRunningWake(_testAgentId)).called(1);
          expect(tester.widget<DsAiDiscButton>(stop).label, 'Stopping…');
        },
      );

      testWidgets(
        'expanding the running thread moves its stop into a banner at the top '
        'of the conversation, never showing two',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              threadsValue: AsyncValue.data(threads),
              runningThreadId: 'live-thread',
              agentService: MockAgentService(),
            ),
          );
          await settle(tester);
          expect(find.byType(DesignSystemInlineCallout), findsNothing);

          await tester.tap(find.textContaining('live-th'));
          await tester.pump(const Duration(milliseconds: 500));

          final banner = find.byType(DesignSystemInlineCallout);
          expect(banner, findsOneWidget);
          expect(
            find.descendant(
              of: banner,
              matching: find.text(
                'The agent is still working on this conversation. Stopping '
                'the agent keeps its saved messages and drops the reply in '
                'progress.',
              ),
            ),
            findsOneWidget,
          );
          expect(find.byType(DsAiDiscButton), findsOneWidget);
          expect(
            find.descendant(of: banner, matching: find.byType(DsAiDiscButton)),
            findsOneWidget,
          );
          // The banner leads the conversation, above its messages.
          expect(
            tester.getTopLeft(banner).dy,
            lessThan(tester.getTopLeft(find.text('Thought').last).dy),
          );
        },
      );

      testWidgets(
        'marks a thread whose wake was aborted as Stopped, and no other',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              threadsValue: AsyncValue.data(threads),
              statuses: {
                'live-thread': WakeRunStatus.aborted,
                'newest-thread': WakeRunStatus.completed,
              },
            ),
          );
          await settle(tester);

          expect(inRow('live-thread', find.text('Stopped')), findsOneWidget);
          expect(inRow('newest-thread', find.text('Stopped')), findsNothing);
          expect(find.text('Running'), findsNothing);
          expect(find.byType(DsAiDiscButton), findsNothing);
        },
      );

      testWidgets(
        'a running thread reads Running, not Stopped, even while its row '
        'still says aborted from a stale read',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              threadsValue: AsyncValue.data(threads),
              runningThreadId: 'live-thread',
              statuses: {'live-thread': WakeRunStatus.aborted},
              agentService: MockAgentService(),
            ),
          );
          await settle(tester);

          expect(inRow('live-thread', find.text('Running')), findsOneWidget);
          expect(find.text('Stopped'), findsNothing);
        },
      );
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
      expect(find.byIcon(LottiIcons.chevronDown), findsOneWidget);
      expect(find.text('{"title": "New"}'), findsOneWidget);
    });
  });
}
