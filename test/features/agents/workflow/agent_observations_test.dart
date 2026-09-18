import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('parseRecordObservations', () {
    test('takes structured and bare notes, skipping blanks', () {
      final (:records, :error) = parseRecordObservations({
        'observations': [
          {
            'text': ' The user corrected "Vanja" to Wanja. ',
            'priority': 'notable',
            'category': 'grievance',
          },
          'Pip sounds tired lately.',
          '   ',
          {'text': ''},
          {'priority': 'critical'},
        ],
      });

      expect(error, isNull);
      expect(
        [for (final r in records) (r.text, r.priority, r.category)],
        [
          (
            'The user corrected "Vanja" to Wanja.',
            ObservationPriority.notable,
            ObservationCategory.grievance,
          ),
          (
            'Pip sounds tired lately.',
            ObservationPriority.routine,
            ObservationCategory.operational,
          ),
        ],
      );
    });

    for (final (label, args) in [
      ('a missing list', <String, dynamic>{}),
      ('an empty list', <String, dynamic>{'observations': <Object>[]}),
      (
        'nothing usable',
        <String, dynamic>{
          'observations': [' ', 3],
        },
      ),
    ]) {
      test('explains $label to the model', () {
        final (:records, :error) = parseRecordObservations(args);

        expect(records, isEmpty);
        expect(error, startsWith('Error:'));
      });
    }
  });

  group('recallAgentObservations', () {
    final at = DateTime(2026, 9, 18, 21);

    AgentMessageEntity message(String id, String? payloadId) =>
        AgentDomainEntity.agentMessage(
              id: id,
              agentId: 'agent',
              threadId: 'thread',
              kind: AgentMessageKind.observation,
              createdAt: at,
              vectorClock: null,
              contentEntryId: payloadId,
              metadata: const AgentMessageMetadata(),
            )
            as AgentMessageEntity;

    AgentDomainEntity payload(String id, Object? text) =>
        AgentDomainEntity.agentMessagePayload(
          id: id,
          agentId: 'agent',
          createdAt: at,
          vectorClock: null,
          content: {'text': text},
        );

    test(
      'returns readable notes in the order read, dropping the rest',
      () async {
        final repository = MockAgentRepository();
        when(
          () => repository.getMessagesByKind(
            'agent',
            AgentMessageKind.observation,
            limit: 5,
          ),
        ).thenAnswer(
          (_) async => [
            message('m1', 'p1'),
            message('m2', null),
            message('m3', 'p3'),
            message('m4', 'missing'),
            message('m5', 'p5'),
          ],
        );
        when(() => repository.getEntitiesByIds(any())).thenAnswer(
          (_) async => {
            'p1': payload('p1', ' Newest note. '),
            'p3': payload('p3', ''),
            'p5': payload('p5', 'Oldest note.'),
          },
        );

        final recalled = await recallAgentObservations(
          repository,
          'agent',
          limit: 5,
        );

        expect(recalled, [
          (at: at, text: 'Newest note.'),
          (at: at, text: 'Oldest note.'),
        ]);
        expect(
          verify(
            () => repository.getEntitiesByIds(captureAny()),
          ).captured.single,
          {'p1', 'p3', 'missing', 'p5'},
        );
      },
    );

    test('reads no payloads when nothing was observed', () async {
      final repository = MockAgentRepository();
      when(
        () => repository.getMessagesByKind(
          'agent',
          AgentMessageKind.observation,
          limit: 3,
        ),
      ).thenAnswer((_) async => []);

      expect(
        await recallAgentObservations(repository, 'agent', limit: 3),
        isEmpty,
      );
      verifyNever(() => repository.getEntitiesByIds(any()));
    });
  });

  group('persistAgentObservations', () {
    Future<List<AgentDomainEntity>> persist(String runKey) async {
      final sync = MockAgentSyncService();
      when(() => sync.upsertEntity(any())).thenAnswer((_) async {});
      await persistAgentObservations(
        sync,
        agentId: 'agent',
        threadId: 'thread',
        runKey: runKey,
        now: DateTime(2026, 9, 19),
        observations: const [
          ObservationRecord(
            text: 'Wanja is her sister.',
            priority: ObservationPriority.notable,
            category: ObservationCategory.grievance,
          ),
        ],
      );
      return verify(
        () => sync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
    }

    test(
      'writes a payload and an observation message pointing at it',
      () async {
        final [payload, message] = await persist('run-1');

        expect(payload, isA<AgentMessagePayloadEntity>());
        expect((payload as AgentMessagePayloadEntity).content, {
          'text': 'Wanja is her sister.',
          'priority': 'notable',
          'category': 'grievance',
        });
        final observation = message as AgentMessageEntity;
        expect(observation.kind, AgentMessageKind.observation);
        expect(observation.contentEntryId, payload.id);
        expect(observation.metadata.runKey, 'run-1');
      },
    );

    // A retried output transaction must rewrite, not duplicate.
    test(
      'derives the same ids for the same run, new ones for a new run',
      () async {
        final first = [for (final e in await persist('run-1')) e.id];

        expect([for (final e in await persist('run-1')) e.id], first);
        expect(
          [for (final e in await persist('run-2')) e.id],
          everyElement(isNot(isIn(first))),
        );
      },
    );
  });
}
