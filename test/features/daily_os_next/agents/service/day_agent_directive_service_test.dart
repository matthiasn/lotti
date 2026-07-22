import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentDirectToolResult;
import 'package:lotti/features/daily_os_next/agents/service/day_agent_directive_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const dayId = 'dayplan-2026-07-23';
  final now = DateTime(2026, 7, 23, 6);

  late MockAgentRepository agentRepository;
  late MockAgentSyncService syncService;
  late MockDomainLogger domainLogger;
  late List<AgentDomainEntity> upserted;
  late List<String> notifications;
  late DayAgentDirectiveService service;

  setUp(() {
    agentRepository = MockAgentRepository();
    syncService = MockAgentSyncService();
    domainLogger = MockDomainLogger();
    upserted = [];
    notifications = [];
    // MockAgentSyncService.runInTransaction already passes the action through.
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserted.add(invocation.positionalArguments.single as AgentDomainEntity);
    });
    when(() => agentRepository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => domainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    service = DayAgentDirectiveService(
      agentRepository: agentRepository,
      syncService: syncService,
      domainLogger: domainLogger,
      onPersistedStateChanged: notifications.add,
    );
  });

  Future<DayAgentDirectToolResult> executeIssue(
    Map<String, dynamic> args, {
    String agentId = dailyOsPlannerAgentId,
  }) {
    return withClock(
      Clock.fixed(now),
      () => service.executeTool(
        agentId: agentId,
        toolName: DayAgentToolNames.issueDayDirective,
        args: args,
      ),
    );
  }

  group('executeTool issue_day_directive', () {
    test('rejects a non-coordinator caller without writing anything', () async {
      final result = await executeIssue(
        {'dayId': dayId},
        agentId: 'day_agent:$dayId',
      );

      expect(result.success, isFalse);
      expect(result.output, contains('only the coordinator'));
      expect(upserted, isEmpty);
    });

    test('rejects a malformed dayId', () async {
      final result = await executeIssue({'dayId': '2026-07-23'});

      expect(result.success, isFalse);
      expect(result.output, contains('dayplan-YYYY-MM-DD'));
      expect(upserted, isEmpty);
    });

    test(
      'persists a full directive under the deterministic id and notifies',
      () async {
        final result = await executeIssue({
          'dayId': dayId,
          'commitments': [
            {
              'id': 'award-1',
              'source': 'attentionAward',
              'title': 'Ship release notes',
              'windowStart': '2026-07-23T09:00:00.000',
              'windowEnd': '2026-07-23T11:00:00.000',
              'minutes': 90,
              'evidenceRefs': ['attention-award-1'],
            },
          ],
          'capacityBudget': {
            'availableMinutes': 420,
            'alreadyScheduledMinutes': 60,
            'energyBands': [
              {
                'start': '2026-07-23T09:00:00.000',
                'end': '2026-07-23T12:00:00.000',
                'level': 'high',
                'label': 'HIGH ENERGY',
              },
            ],
          },
          'carryOver': [
            {
              'title': 'Expense report',
              'reason': 'Dropped yesterday.',
              'taskId': 'task-42',
            },
          ],
          'constraints': ['Protect 12:00-13:00 for lunch.'],
          'attentionNotes': ['Third heavy commitment this week.'],
        });

        expect(result.success, isTrue, reason: result.output);
        final directive = upserted.single as DayDirectiveEntity;
        expect(directive.id, 'day_directive:$dayId');
        expect(directive.agentId, dailyOsPlannerAgentId);
        expect(directive.planDate, DateTime(2026, 7, 23));
        expect(directive.issuedAt, now);
        expect(directive.directiveRevisionId, isNotEmpty);
        expect(
          directive.commitments.single.source,
          DayCommitmentSource.attentionAward,
        );
        expect(directive.capacityBudget!.availableMinutes, 420);
        expect(directive.capacityBudget!.energyBands, hasLength(1));
        expect(directive.carryOver.single.taskId, 'task-42');
        expect(notifications, containsAll([dayId, directive.id]));
      },
    );

    test(
      'a revision preserves createdAt and mints a fresh revision id',
      () async {
        final existing = makeTestDayDirective(
          dayId: dayId,
          id: 'day_directive:$dayId',
          directiveRevisionId: 'rev-old',
          createdAt: DateTime(2026, 7, 22, 6),
          updatedAt: DateTime(2026, 7, 22, 6),
        );
        when(
          () => agentRepository.getEntity('day_directive:$dayId'),
        ).thenAnswer((_) async => existing);

        final result = await executeIssue({'dayId': dayId});

        expect(result.success, isTrue, reason: result.output);
        final revised = upserted.single as DayDirectiveEntity;
        expect(revised.createdAt, DateTime(2026, 7, 22, 6));
        expect(revised.updatedAt, now);
        expect(revised.directiveRevisionId, isNot('rev-old'));
      },
    );

    group('commitment validation', () {
      Future<DayAgentDirectToolResult> issueWithCommitment(
        Map<String, dynamic> commitment,
      ) {
        return executeIssue({
          'dayId': dayId,
          'commitments': [commitment],
        });
      }

      test('rejects an unknown source', () async {
        final result = await issueWithCommitment({
          'id': 'c1',
          'source': 'vibes',
          'title': 'X',
        });
        expect(result.success, isFalse);
        expect(result.output, contains('commitment source'));
      });

      test('rejects a half-open window', () async {
        final result = await issueWithCommitment({
          'id': 'c1',
          'source': 'userCommitment',
          'title': 'X',
          'windowStart': '2026-07-23T09:00:00.000',
        });
        expect(result.success, isFalse);
        expect(result.output, contains('set together'));
      });

      test('rejects an inverted window', () async {
        final result = await issueWithCommitment({
          'id': 'c1',
          'source': 'userCommitment',
          'title': 'X',
          'windowStart': '2026-07-23T11:00:00.000',
          'windowEnd': '2026-07-23T09:00:00.000',
        });
        expect(result.success, isFalse);
        expect(result.output, contains('after windowStart'));
      });

      test('rejects a window outside the directive day', () async {
        final result = await issueWithCommitment({
          'id': 'c1',
          'source': 'userCommitment',
          'title': 'X',
          'windowStart': '2026-07-22T23:00:00.000',
          'windowEnd': '2026-07-23T01:00:00.000',
        });
        expect(result.success, isFalse);
        expect(result.output, contains('within the directive day'));
      });

      test('rejects out-of-range minutes', () async {
        for (final minutes in [0, -30, 1441]) {
          final result = await issueWithCommitment({
            'id': 'c1',
            'source': 'userCommitment',
            'title': 'X',
            'minutes': minutes,
          });
          expect(result.success, isFalse, reason: 'minutes=$minutes');
          expect(result.output, contains('between 1 and 1440'));
        }
      });

      test('rejects more than the commitment cap', () async {
        final result = await executeIssue({
          'dayId': dayId,
          'commitments': [
            for (var i = 0; i <= DayAgentDirectiveService.maxCommitments; i++)
              {'id': 'c$i', 'source': 'userCommitment', 'title': 'C$i'},
          ],
        });
        expect(result.success, isFalse);
        expect(result.output, contains('at most'));
      });
    });

    group('capacity budget validation', () {
      test('rejects missing or out-of-range availableMinutes', () async {
        for (final budget in [
          <String, dynamic>{},
          {'availableMinutes': 0},
          {'availableMinutes': 2000},
        ]) {
          final result = await executeIssue({
            'dayId': dayId,
            'capacityBudget': budget,
          });
          expect(result.success, isFalse, reason: 'budget=$budget');
          expect(result.output, contains('availableMinutes'));
        }
      });

      test('rejects negative alreadyScheduledMinutes', () async {
        final result = await executeIssue({
          'dayId': dayId,
          'capacityBudget': {
            'availableMinutes': 400,
            'alreadyScheduledMinutes': -5,
          },
        });
        expect(result.success, isFalse);
        expect(result.output, contains('not be negative'));
      });

      test('rejects an energy band outside the day', () async {
        final result = await executeIssue({
          'dayId': dayId,
          'capacityBudget': {
            'availableMinutes': 400,
            'energyBands': [
              {
                'start': '2026-07-22T22:00:00.000',
                'end': '2026-07-23T01:00:00.000',
                'level': 'high',
                'label': 'X',
              },
            ],
          },
        });
        expect(result.success, isFalse);
        expect(result.output, contains('within the planDate day'));
      });
    });

    group('carry-over and note bounds', () {
      test('rejects an over-long carryOver reason', () async {
        final result = await executeIssue({
          'dayId': dayId,
          'carryOver': [
            {'title': 'X', 'reason': 'r' * 281},
          ],
        });
        expect(result.success, isFalse);
        expect(result.output, contains('280'));
      });

      test('rejects too many notes and over-long notes', () async {
        final tooMany = await executeIssue({
          'dayId': dayId,
          'attentionNotes': [
            for (var i = 0; i <= DayAgentDirectiveService.maxNotes; i++)
              'note $i',
          ],
        });
        expect(tooMany.success, isFalse);
        expect(tooMany.output, contains('at most'));

        final tooLong = await executeIssue({
          'dayId': dayId,
          'constraints': ['c' * 281],
        });
        expect(tooLong.success, isFalse);
        expect(tooLong.output, contains('280'));
      });
    });

    test('unknown tool name fails without throwing', () async {
      final result = await service.executeTool(
        agentId: dailyOsPlannerAgentId,
        toolName: 'not_a_tool',
        args: const {},
      );
      expect(result.success, isFalse);
      expect(result.output, contains('unknown tool'));
    });

    test('an unexpected error is logged and surfaced as a failure', () async {
      when(
        () => agentRepository.getEntity('day_directive:$dayId'),
      ).thenThrow(StateError('store exploded'));

      final result = await executeIssue({'dayId': dayId});

      expect(result.success, isFalse);
      expect(result.output, contains('store exploded'));
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: 'day-directive tool failed',
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });

    test('the exception toString is its tool-facing message', () {
      expect(
        const DayAgentDirectiveException('boom').toString(),
        'boom',
      );
    });
  });

  group('executeTool raise_day_status', () {
    const perDayAgent = 'day_agent:$dayId';

    Future<DayAgentDirectToolResult> executeRaise(
      Map<String, dynamic> args, {
      String agentId = perDayAgent,
      String? wakeDayId = dayId,
      String? runKey,
    }) {
      return withClock(
        Clock.fixed(now),
        () => service.executeTool(
          agentId: agentId,
          toolName: DayAgentToolNames.raiseDayStatus,
          args: args,
          wakeDayId: wakeDayId,
          runKey: runKey,
        ),
      );
    }

    test(
      'persists an append-only event under the raising agent and notifies',
      () async {
        final result = await executeRaise({
          'dayId': dayId,
          'status': 'attentionNeeded',
          'reasons': ['overCommitted', 'directiveUnsatisfiable'],
          'note': 'Two commitments no longer fit after the 14:00 meeting.',
        });

        expect(result.success, isTrue, reason: result.output);
        final event = upserted.single as DayStatusEventEntity;
        expect(event.id, startsWith('day_status:$dayId:'));
        expect(event.agentId, perDayAgent);
        expect(event.status, DayStatusKind.attentionNeeded);
        expect(event.reasons, [
          DayStatusReason.overCommitted,
          DayStatusReason.directiveUnsatisfiable,
        ]);
        expect(event.raisedAt, now);
        expect(notifications, containsAll([dayId, event.id]));
      },
    );

    test('the coordinator may raise for a pre-cutover day it owns', () async {
      final result = await executeRaise(
        {'dayId': dayId, 'status': 'dayClosed'},
        agentId: dailyOsPlannerAgentId,
      );

      expect(result.success, isTrue, reason: result.output);
      final event = upserted.single as DayStatusEventEntity;
      expect(event.agentId, dailyOsPlannerAgentId);
      expect(event.status, DayStatusKind.dayClosed);
      expect(event.reasons, isEmpty);
    });

    test("rejects raising for another agent's day", () async {
      final result = await executeRaise(
        {'dayId': 'dayplan-2026-07-24', 'status': 'onTrack'},
      );

      expect(result.success, isFalse);
      expect(result.output, contains("wake's own day"));
      expect(upserted, isEmpty);
    });

    test('rejects an unknown status and malformed dayId', () async {
      final badStatus = await executeRaise({
        'dayId': dayId,
        'status': 'panicking',
      });
      expect(badStatus.success, isFalse);
      expect(badStatus.output, contains('status must be'));

      final badDay = await executeRaise(
        {'dayId': 'not-a-day', 'status': 'onTrack'},
        wakeDayId: null,
      );
      expect(badDay.success, isFalse);
      expect(badDay.output, contains('dayplan-YYYY-MM-DD'));
    });

    test('enforces the reasons/status pairing rules', () async {
      final missingReasons = await executeRaise({
        'dayId': dayId,
        'status': 'attentionNeeded',
      });
      expect(missingReasons.success, isFalse);
      expect(missingReasons.output, contains('at least one typed reason'));

      final strayReasons = await executeRaise({
        'dayId': dayId,
        'status': 'onTrack',
        'reasons': ['overCommitted'],
      });
      expect(strayReasons.success, isFalse);
      expect(strayReasons.output, contains('only valid with attentionNeeded'));

      final unknownReason = await executeRaise({
        'dayId': dayId,
        'status': 'attentionNeeded',
        'reasons': ['vibes'],
      });
      expect(unknownReason.success, isFalse);
      expect(unknownReason.output, contains('reasons must be'));
    });

    test('bounds the note length', () async {
      final result = await executeRaise({
        'dayId': dayId,
        'status': 'onTrack',
        'note': 'n' * 501,
      });

      expect(result.success, isFalse);
      expect(result.output, contains('500'));
    });

    test('caps status events at one per wake run key', () async {
      final first = await executeRaise(
        {'dayId': dayId, 'status': 'dayClosed'},
        runKey: 'run-1',
      );
      final second = await executeRaise(
        {'dayId': dayId, 'status': 'dayClosed'},
        runKey: 'run-1',
      );
      final freshWake = await executeRaise(
        {'dayId': dayId, 'status': 'dayClosed'},
        runKey: 'run-2',
      );

      expect(first.success, isTrue);
      expect(second.success, isFalse);
      expect(second.output, contains('one per wake'));
      expect(freshWake.success, isTrue);
      expect(upserted, hasLength(2));
    });
  });

  group('directiveForDay', () {
    test('returns the live directive and hides deleted/missing ones', () async {
      final live = makeTestDayDirective(dayId: dayId);
      when(
        () => agentRepository.getEntity('day_directive:$dayId'),
      ).thenAnswer((_) async => live);
      expect(await service.directiveForDay(dayId), same(live));

      when(
        () => agentRepository.getEntity('day_directive:$dayId'),
      ).thenAnswer(
        (_) async => makeTestDayDirective(
          dayId: dayId,
          deletedAt: DateTime(2026, 7, 23, 7),
        ),
      );
      expect(await service.directiveForDay(dayId), isNull);

      when(
        () => agentRepository.getEntity('day_directive:$dayId'),
      ).thenAnswer((_) async => null);
      expect(await service.directiveForDay(dayId), isNull);
    });
  });
}
