import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/goals/service/goal_off_track_alert_service.dart';
import 'package:lotti/features/notifications/model/notification_episode_id.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_de.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockNotificationRepository notifications;
  late MockDomainLogger logger;
  late GoalOffTrackAlertService service;

  /// The rows the mocked repository was asked to write, built the way the
  /// real one builds them.
  late List<NotificationEntity> armedRows;

  const agentId = 'goal-agent-1';
  const subject = (agentId: agentId, goalTitle: 'Daily steps');

  final specVersion =
      AgentDomainEntity.goalSpecVersion(
            id: '$agentId:spec-v1',
            agentId: agentId,
            version: 1,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: 'Daily steps',
            statement: 'Average 10,000 steps a day.',
            criteria: const GoalCriterion.metric(
              criterionId: 'steps',
              dataType: 'cumulative_step_count',
              window: GoalWindow.rollingDays(count: 7),
              aggregation: GoalAggregation.dailySumThenAverage,
              target: 10000,
            ),
            createdAt: DateTime(2026),
            vectorClock: null,
          )
          as GoalSpecVersionEntity;

  GoalWakeDerivation derivation({
    String periodKey = '2026-08-08',
    GoalTrackStatus status = GoalTrackStatus.offTrack,
  }) => GoalWakeDerivation(
    version: specVersion,
    facts: GoalWakeFacts(
      trackStatus: status,
      previousStatus: GoalTrackStatus.onTrack,
      evaluation: const GoalEvaluation(
        attainment: 0.6,
        satisfied: false,
        dataCoverage: 1,
        results: {},
      ),
    ),
    periodKey: periodKey,
    priors: const [],
  );

  String episodeId({String periodKey = '2026-08-08'}) => notificationEpisodeId(
    kind: NotificationKinds.goalOffTrack,
    subjectId: agentId,
    episodeKey: periodKey,
  );

  /// `armEpisode` runs the builder the way the real repository does, so the
  /// row the service would have written is observable in [armedRows].
  void stubSuccess() {
    when(
      () => notifications.armEpisode(
        id: any(named: 'id'),
        scheduledFor: any(named: 'scheduledFor'),
        build: any(named: 'build'),
        category: any(named: 'category'),
      ),
    ).thenAnswer((invocation) async {
      final build =
          invocation.namedArguments[#build]
              as NotificationEntity Function(NotificationMeta);
      final row = build(
        NotificationMeta(
          id: invocation.namedArguments[#id] as String,
          createdAt: DateTime(2026, 8, 8, 6),
          updatedAt: DateTime(2026, 8, 8, 6),
          scheduledFor: invocation.namedArguments[#scheduledFor] as DateTime,
          vectorClock: const VectorClock({}),
          originatingHostId: '',
          category: invocation.namedArguments[#category] as String?,
        ),
      );
      armedRows.add(row);
      return row;
    });
    when(
      () => notifications.retractOpenRows(
        linkedEntityId: any(named: 'linkedEntityId'),
        kind: any(named: 'kind'),
        exceptId: any(named: 'exceptId'),
      ),
    ).thenAnswer((_) async => const []);
  }

  GoalOffTrackAlertService build({AppLocalizations Function()? messages}) =>
      GoalOffTrackAlertService(
        notificationRepository: notifications,
        domainLogger: logger,
        messages: messages ?? AppLocalizationsEn.new,
      );

  /// A `test` that states its own "now" — the 06:00 cadence tick of the
  /// evaluation day unless a case says otherwise.
  void clockedTest(
    String description,
    Future<void> Function() body, {
    DateTime? now,
  }) => test(
    description,
    () => withClock(Clock.fixed(now ?? DateTime(2026, 8, 8, 6)), body),
  );

  Future<DateTime> armedInstant() async {
    await service.arm(subject: subject, derivation: derivation());
    return verify(
          () => notifications.armEpisode(
            id: any(named: 'id'),
            scheduledFor: captureAny(named: 'scheduledFor'),
            build: any(named: 'build'),
            category: any(named: 'category'),
          ),
        ).captured.single
        as DateTime;
  }

  setUp(() {
    notifications = MockNotificationRepository();
    logger = MockDomainLogger();
    armedRows = [];
    stubSuccess();
    service = build();
  });

  group('GoalOffTrackAlertService.arm', () {
    clockedTest(
      'arms the transition day as the episode, under its kind',
      () async {
        await service.arm(subject: subject, derivation: derivation());

        verify(
          () => notifications.armEpisode(
            id: episodeId(),
            scheduledFor: any(named: 'scheduledFor'),
            build: any(named: 'build'),
            // Goals carry no category.
            // ignore: avoid_redundant_argument_values
            category: null,
          ),
        ).called(1);
        // The kind it names is the kind of the row it writes — which is what
        // lets the base retract by it.
        expect(service.kind, armedRows.single.type);
        expect(armedRows.single.meta.id, episodeId());
      },
    );

    clockedTest('a later slip on another day is its own episode', () async {
      await service.arm(subject: subject, derivation: derivation());
      await service.arm(
        subject: subject,
        derivation: derivation(periodKey: '2026-09-01'),
      );

      expect(
        armedRows.map((row) => row.meta.id),
        [episodeId(), episodeId(periodKey: '2026-09-01')],
      );
    });

    clockedTest('links the row to the goal agent with minimal copy', () async {
      await service.arm(subject: subject, derivation: derivation());

      final row = armedRows.single as GoalOffTrackNotification;
      expect(row.linkedGoalAgentId, agentId);
      expect(row.title, 'Daily steps is off track');
      expect(row.body, 'A good moment to get back on it.');
      // Lock-screen copy: the goal's title and nothing about the shortfall.
      expect(row.title, isNot(contains('0.6')));
      expect(row.body, isNot(contains('Daily steps')));
    });

    clockedTest('renders copy in the device locale', () async {
      await build(messages: AppLocalizationsDe.new).arm(
        subject: subject,
        derivation: derivation(),
      );

      expect(armedRows.single.title, 'Daily steps läuft nicht nach Plan');
    });

    clockedTest('fires at the alert hour later the same day', () async {
      // The 06:00 cadence tick saw the slip; 09:00 is still ahead.
      final scheduledFor = await armedInstant();

      expect(scheduledFor, DateTime(2026, 8, 8, goalOffTrackAlertHour));
      expect(scheduledFor.isUtc, isFalse);
    });

    clockedTest(
      "fires at the alert hour tomorrow once today's has passed",
      () async {
        // A signal-driven tick at 14:30 must not alert at 14:30.
        final scheduledFor = await armedInstant();

        expect(scheduledFor, DateTime(2026, 8, 9, goalOffTrackAlertHour));
      },
      now: DateTime(2026, 8, 8, 14, 30),
    );

    clockedTest(
      'at the alert hour itself it waits for tomorrow',
      () async {
        final scheduledFor = await armedInstant();

        expect(scheduledFor, DateTime(2026, 8, 9, goalOffTrackAlertHour));
      },
      now: DateTime(2026, 8, 8, goalOffTrackAlertHour),
    );

    clockedTest(
      'keeps the wall-clock hour across a DST change',
      () async {
        // Calendar components, not a Duration: 24 elapsed hours across the
        // 2026-10-25 switch would land at 08:00.
        final scheduledFor = await armedInstant();

        expect(scheduledFor.day, 25);
        expect(scheduledFor.hour, goalOffTrackAlertHour);
      },
      now: DateTime(2026, 10, 24, 23),
    );

    clockedTest('retracts superseded episodes but spares this one', () async {
      await service.arm(subject: subject, derivation: derivation());

      verify(
        () => notifications.retractOpenRows(
          linkedEntityId: agentId,
          kind: NotificationKinds.goalOffTrack,
          exceptId: episodeId(),
        ),
      ).called(1);
    });
  });

  group('GoalOffTrackAlertService.clearFor', () {
    clockedTest('retracts every open alert for the goal', () async {
      await service.clearFor(agentId);

      verify(
        () => notifications.retractOpenRows(
          linkedEntityId: agentId,
          kind: NotificationKinds.goalOffTrack,
        ),
      ).called(1);
      expect(armedRows, isEmpty);
    });
  });

  group('GoalOffTrackAlertService best-effort contract', () {
    clockedTest('a failing arm is logged under its own subdomain', () async {
      final failure = Exception('notifications.sqlite is locked');
      when(
        () => notifications.armEpisode(
          id: any(named: 'id'),
          scheduledFor: any(named: 'scheduledFor'),
          build: any(named: 'build'),
          category: any(named: 'category'),
        ),
      ).thenThrow(failure);

      await expectLater(
        service.arm(subject: subject, derivation: derivation()),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          failure,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'goalOffTrackAlert.arm',
        ),
      ).called(1);
    });

    clockedTest('a failing locale lookup cannot break the wake', () async {
      await expectLater(
        build(messages: () => throw StateError('no binding')).arm(
          subject: subject,
          derivation: derivation(),
        ),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'goalOffTrackAlert.arm',
        ),
      ).called(1);
      expect(armedRows, isEmpty);
    });
  });
}
