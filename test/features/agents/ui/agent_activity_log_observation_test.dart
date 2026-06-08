import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_activity_log.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

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

    testWidgets('shows loading indicator while observations load', (
      tester,
    ) async {
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
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNWidgets(2));
    });

    testWidgets('can collapse an initially expanded observation', (
      tester,
    ) async {
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
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
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
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.text('{"title": "New Title"}'), findsNothing);
    });

    testWidgets('action messages start expanded when expandToolCalls is true', (
      tester,
    ) async {
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
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
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

        expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
        expect(find.text('Success: title updated'), findsOneWidget);
      },
    );

    testWidgets('non-tool messages remain collapsed with expandToolCalls', (
      tester,
    ) async {
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
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.text('thinking...'), findsNothing);
    });
  });
}
