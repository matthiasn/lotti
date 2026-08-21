import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/service/relationship_reminder_service.dart';
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
  late RelationshipReminderService service;

  final testDate = DateTime(2026, 8, 1, 9);

  Metadata meta(String id, {String? categoryId}) => Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
    categoryId: categoryId,
  );

  RelationshipEntry relationship({
    String id = 'person-1',
    String title = 'Anna',
    String? categoryId = 'cat-1',
  }) => RelationshipEntry(
    meta: meta(id, categoryId: categoryId),
    data: RelationshipData(
      title: title,
      important: true,
      checkInCadenceDays: 7,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  );

  RelationshipCadenceDerivation derivation({
    RelationshipCadenceStatus status = RelationshipCadenceStatus.ok,
    DateTime? dueDayUtc,
    String dueDayKey = '2026-08-21',
  }) => (
    status: status,
    previousStatus: null,
    cadenceDays: 7,
    referenceAt: testDate,
    lastCheckInAt: null,
    dueDayUtc: dueDayUtc ?? DateTime.utc(2026, 8, 21),
    dueDayKey: dueDayKey,
  );

  NotificationEntity row(String id) => NotificationEntity.relationshipCheckIn(
    meta: NotificationMeta(
      id: id,
      createdAt: testDate,
      updatedAt: testDate,
      scheduledFor: testDate,
      vectorClock: const VectorClock({'host': 1}),
      originatingHostId: 'host',
    ),
    linkedRelationshipId: 'person-1',
    title: 'Check in with Anna?',
    body: 'A good moment to reach out.',
  );

  /// Stubs both write paths with success. Individual tests override.
  void stubSuccess() {
    when(
      () => notifications.createRelationshipCheckIn(
        linkedRelationshipId: any(named: 'linkedRelationshipId'),
        dueDayKey: any(named: 'dueDayKey'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledFor: any(named: 'scheduledFor'),
        category: any(named: 'category'),
      ),
    ).thenAnswer((_) async => row('armed'));
    when(
      () => notifications.retractRelationshipCheckIns(
        any(),
        exceptId: any(named: 'exceptId'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      () => notifications.notificationIdForRelationshipCheckIn(
        linkedRelationshipId: any(named: 'linkedRelationshipId'),
        dueDayKey: any(named: 'dueDayKey'),
      ),
    ).thenReturn('episode-id');
  }

  RelationshipReminderService build({
    AppLocalizations Function()? messages,
  }) => RelationshipReminderService(
    notificationRepository: notifications,
    domainLogger: logger,
    messages: messages ?? AppLocalizationsEn.new,
  );

  /// A `test` that states its own "now".
  ///
  /// Every case here reasons about a due day of 2026-08-21, and `arm` only
  /// schedules a day still ahead of the clock — so a suite that borrows the
  /// wall clock passes until the wall clock reaches that day, then fails as a
  /// block. It did, on 2026-08-21. Cases that need a different instant pass
  /// [now]; the three that pin an inner clock of their own still override
  /// this one.
  void clockedTest(
    String description,
    Future<void> Function() body, {
    DateTime? now,
  }) => test(
    description,
    () => withClock(Clock.fixed(now ?? DateTime(2026, 8, 19, 12)), body),
  );

  setUp(() {
    notifications = MockNotificationRepository();
    logger = MockDomainLogger();
    stubSuccess();
    service = build();
  });

  group('RelationshipReminderService.arm', () {
    clockedTest(
      'writes the episode with content-minimal localized copy',
      () async {
        await service.arm(
          relationship: relationship(),
          derivation: derivation(),
        );

        final captured = verify(
          () => notifications.createRelationshipCheckIn(
            linkedRelationshipId: captureAny(named: 'linkedRelationshipId'),
            dueDayKey: captureAny(named: 'dueDayKey'),
            title: captureAny(named: 'title'),
            body: captureAny(named: 'body'),
            scheduledFor: captureAny(named: 'scheduledFor'),
            category: captureAny(named: 'category'),
          ),
        ).captured;

        expect(captured[0], 'person-1');
        expect(captured[1], '2026-08-21');
        expect(captured[2], 'Check in with Anna?');
        expect(captured[3], 'A good moment to reach out.');
        expect(captured[5], 'cat-1');

        // ADR 0039 Decision 6: this copy lands on a lock screen, so it carries
        // the person's name and nothing else about them.
        final body = captured[3] as String;
        expect(body, isNot(contains('7')));
        expect(body, isNot(contains('Anna')));
      },
    );

    clockedTest('renders copy in the device locale', () async {
      await build(messages: AppLocalizationsDe.new).arm(
        relationship: relationship(),
        derivation: derivation(),
      );

      final captured = verify(
        () => notifications.createRelationshipCheckIn(
          linkedRelationshipId: any(named: 'linkedRelationshipId'),
          dueDayKey: any(named: 'dueDayKey'),
          title: captureAny(named: 'title'),
          body: any(named: 'body'),
          scheduledFor: any(named: 'scheduledFor'),
          category: any(named: 'category'),
        ),
      ).captured;

      expect(captured.single, 'Bei Anna melden?');
    });

    clockedTest('fires at the local reminder hour on the due day', () async {
      await service.arm(
        relationship: relationship(),
        derivation: derivation(dueDayUtc: DateTime.utc(2026, 8, 21)),
      );

      final scheduledFor =
          verify(
                () => notifications.createRelationshipCheckIn(
                  linkedRelationshipId: any(named: 'linkedRelationshipId'),
                  dueDayKey: any(named: 'dueDayKey'),
                  title: any(named: 'title'),
                  body: any(named: 'body'),
                  scheduledFor: captureAny(named: 'scheduledFor'),
                  category: any(named: 'category'),
                ),
              ).captured.single
              as DateTime;

      // dueDayUtc is a DST-safe *day key* (UTC midnight standing for a local
      // calendar day), not an instant. Reading it as one would fire the
      // reminder at the user's UTC offset instead of in their morning.
      expect(scheduledFor.isUtc, isFalse);
      expect(scheduledFor.year, 2026);
      expect(scheduledFor.month, 8);
      expect(scheduledFor.day, 21);
      expect(scheduledFor.hour, relationshipReminderHour);
      expect(scheduledFor.minute, 0);
    });

    clockedTest(
      'retracts superseded episodes but spares the one armed',
      () async {
        when(
          () => notifications.notificationIdForRelationshipCheckIn(
            linkedRelationshipId: 'person-1',
            dueDayKey: '2026-08-21',
          ),
        ).thenReturn('current-episode');

        await service.arm(
          relationship: relationship(),
          derivation: derivation(),
        );

        verify(
          () => notifications.retractRelationshipCheckIns(
            'person-1',
            exceptId: 'current-episode',
          ),
        ).called(1);
      },
    );

    clockedTest(
      'arms for a lapsed cadence too, not only a healthy one',
      () async {
        // A `due` verdict still arms, as long as the due day itself is ahead:
        // the verdict describes the cadence, the due day decides whether an
        // alarm is worth setting. See the past-due-day cases below.
        await service.arm(
          relationship: relationship(),
          derivation: derivation(status: RelationshipCadenceStatus.due),
        );

        verify(
          () => notifications.createRelationshipCheckIn(
            linkedRelationshipId: any(named: 'linkedRelationshipId'),
            dueDayKey: any(named: 'dueDayKey'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledFor: any(named: 'scheduledFor'),
            category: any(named: 'category'),
          ),
        ).called(1);
      },
    );

    // `NotificationScheduler.schedule` routes a past instant to
    // `showNotificationNow`, so arming a due day already behind us fired an
    // OS banner on the spot — one per person on the tick that first
    // evaluates a set of overdue people, duplicating their in-app nudges.
    clockedTest('a due day already behind us arms no alarm', () async {
      await withClock(Clock.fixed(DateTime(2026, 8, 25, 12)), () async {
        await service.arm(
          relationship: relationship(),
          derivation: derivation(dueDayUtc: DateTime.utc(2026, 8, 21)),
        );
      });

      verifyNever(
        () => notifications.createRelationshipCheckIn(
          linkedRelationshipId: any(named: 'linkedRelationshipId'),
          dueDayKey: any(named: 'dueDayKey'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledFor: any(named: 'scheduledFor'),
          category: any(named: 'category'),
        ),
      );
    });

    // Skipping the alarm must not skip the housekeeping: an episode this one
    // superseded has to stop being armed either way.
    clockedTest('a skipped alarm still retracts superseded episodes', () async {
      await withClock(Clock.fixed(DateTime(2026, 8, 25, 12)), () async {
        await service.arm(
          relationship: relationship(),
          derivation: derivation(dueDayUtc: DateTime.utc(2026, 8, 21)),
        );
      });

      verify(
        () => notifications.retractRelationshipCheckIns(
          any(),
          exceptId: any(named: 'exceptId'),
        ),
      ).called(1);
    });

    clockedTest('a due day still ahead arms normally', () async {
      await withClock(Clock.fixed(DateTime(2026, 8, 19, 12)), () async {
        await service.arm(
          relationship: relationship(),
          derivation: derivation(dueDayUtc: DateTime.utc(2026, 8, 21)),
        );
      });

      verify(
        () => notifications.createRelationshipCheckIn(
          linkedRelationshipId: any(named: 'linkedRelationshipId'),
          dueDayKey: any(named: 'dueDayKey'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledFor: any(named: 'scheduledFor'),
          category: any(named: 'category'),
        ),
      ).called(1);
    });

    clockedTest('passes a null category straight through', () async {
      await service.arm(
        relationship: relationship(categoryId: null),
        derivation: derivation(),
      );

      verify(
        () => notifications.createRelationshipCheckIn(
          linkedRelationshipId: any(named: 'linkedRelationshipId'),
          dueDayKey: any(named: 'dueDayKey'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledFor: any(named: 'scheduledFor'),
          // Asserted explicitly: omitting it would not match the recorded
          // call's named-argument map.
          // ignore: avoid_redundant_argument_values
          category: null,
        ),
      ).called(1);
    });
  });

  group('RelationshipReminderService.clearFor', () {
    clockedTest('retracts every open reminder for the person', () async {
      await service.clearFor('person-1');

      verify(
        () => notifications.retractRelationshipCheckIns('person-1'),
      ).called(1);
      verifyNever(
        () => notifications.createRelationshipCheckIn(
          linkedRelationshipId: any(named: 'linkedRelationshipId'),
          dueDayKey: any(named: 'dueDayKey'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledFor: any(named: 'scheduledFor'),
          category: any(named: 'category'),
        ),
      );
    });
  });

  // RelationshipReminderSink's contract is that no call throws. The caller is
  // an agent wake whose real work — the cadence register — has already
  // committed by the time this runs, so letting a notification-store failure
  // escape would fail a wake that succeeded and schedule a retry of it.
  group('RelationshipReminderService best-effort contract', () {
    clockedTest('a failing create is logged, not thrown', () async {
      final failure = Exception('notifications.sqlite is locked');
      when(
        () => notifications.createRelationshipCheckIn(
          linkedRelationshipId: any(named: 'linkedRelationshipId'),
          dueDayKey: any(named: 'dueDayKey'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          scheduledFor: any(named: 'scheduledFor'),
          category: any(named: 'category'),
        ),
      ).thenThrow(failure);

      await expectLater(
        service.arm(
          relationship: relationship(),
          derivation: derivation(),
        ),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          failure,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'relationshipReminder.arm',
        ),
      ).called(1);
    });

    clockedTest('a failing retract inside arm is contained too', () async {
      when(
        () => notifications.retractRelationshipCheckIns(
          any(),
          exceptId: any(named: 'exceptId'),
        ),
      ).thenThrow(Exception('boom'));

      await expectLater(
        service.arm(
          relationship: relationship(),
          derivation: derivation(),
        ),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'relationshipReminder.arm',
        ),
      ).called(1);
    });

    clockedTest(
      'a failing clearFor is logged under its own subdomain',
      () async {
        when(
          () => notifications.retractRelationshipCheckIns(any()),
        ).thenThrow(Exception('boom'));

        await expectLater(service.clearFor('person-1'), completes);

        verify(
          () => logger.error(
            LogDomain.notifications,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'relationshipReminder.clearFor',
          ),
        ).called(1);
      },
    );

    clockedTest(
      'a failing locale lookup cannot break the wake either',
      () async {
        // deviceMessages() reads the widgets binding; a producer running before
        // the binding exists must degrade rather than take the wake down.
        await expectLater(
          build(messages: () => throw StateError('no binding')).arm(
            relationship: relationship(),
            derivation: derivation(),
          ),
          completes,
        );

        verify(
          () => logger.error(
            LogDomain.notifications,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'relationshipReminder.arm',
          ),
        ).called(1);
      },
    );
  });
}
