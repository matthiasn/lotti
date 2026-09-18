import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/notifications/model/notification_episode_id.dart';
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

  /// The rows the mocked repository was asked to write, built the way the
  /// real one builds them.
  late List<NotificationEntity> armedRows;

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

  String episodeId({
    String person = 'person-1',
    String dueDayKey = '2026-08-21',
  }) => notificationEpisodeId(
    kind: NotificationKinds.relationshipCheckIn,
    subjectId: person,
    episodeKey: dueDayKey,
  );

  /// Stubs both write paths with success. `armEpisode` runs the builder the
  /// way the real repository does, so the row the service would have written
  /// is observable in [armedRows] — and a builder that throws surfaces.
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
          createdAt: testDate,
          updatedAt: testDate,
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
  /// [now].
  void clockedTest(
    String description,
    Future<void> Function() body, {
    DateTime? now,
  }) => test(
    description,
    () => withClock(Clock.fixed(now ?? DateTime(2026, 8, 19, 12)), body),
  );

  void verifyNeverArmed() => verifyNever(
    () => notifications.armEpisode(
      id: any(named: 'id'),
      scheduledFor: any(named: 'scheduledFor'),
      build: any(named: 'build'),
      category: any(named: 'category'),
    ),
  );

  setUp(() {
    notifications = MockNotificationRepository();
    logger = MockDomainLogger();
    armedRows = [];
    stubSuccess();
    service = build();
  });

  group('RelationshipReminderService.arm', () {
    clockedTest(
      'arms the due day as the episode, under its own kind',
      () async {
        await service.arm(subject: relationship(), derivation: derivation());

        verify(
          () => notifications.armEpisode(
            id: episodeId(),
            scheduledFor: any(named: 'scheduledFor'),
            build: any(named: 'build'),
            category: 'cat-1',
          ),
        ).called(1);
        // The kind it names is the kind of the row it writes — which is what
        // lets the base retract by it.
        expect(service.kind, armedRows.single.type);
        expect(armedRows.single.meta.id, episodeId());
      },
    );

    clockedTest(
      'writes the episode with content-minimal localized copy',
      () async {
        await service.arm(subject: relationship(), derivation: derivation());

        final row = armedRows.single as RelationshipCheckInNotification;
        expect(row.linkedRelationshipId, 'person-1');
        expect(row.title, 'Check in with Anna?');
        expect(row.body, 'A good moment to reach out.');
        expect(row.meta.category, 'cat-1');

        // ADR 0039 Decision 6: this copy lands on a lock screen, so it carries
        // the person's name and nothing else about them.
        expect(row.body, isNot(contains('7')));
        expect(row.body, isNot(contains('Anna')));
      },
    );

    clockedTest('renders copy in the device locale', () async {
      await build(messages: AppLocalizationsDe.new).arm(
        subject: relationship(),
        derivation: derivation(),
      );

      expect(armedRows.single.title, 'Bei Anna melden?');
    });

    clockedTest('fires at the local reminder hour on the due day', () async {
      await service.arm(
        subject: relationship(),
        derivation: derivation(dueDayUtc: DateTime.utc(2026, 8, 21)),
      );

      final scheduledFor =
          verify(
                () => notifications.armEpisode(
                  id: any(named: 'id'),
                  scheduledFor: captureAny(named: 'scheduledFor'),
                  build: any(named: 'build'),
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
        await service.arm(subject: relationship(), derivation: derivation());

        verify(
          () => notifications.retractOpenRows(
            linkedEntityId: 'person-1',
            kind: NotificationKinds.relationshipCheckIn,
            exceptId: episodeId(),
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
          subject: relationship(),
          derivation: derivation(status: RelationshipCadenceStatus.due),
        );

        expect(armedRows, hasLength(1));
      },
    );

    // `NotificationScheduler.schedule` routes a past instant to
    // `showNotificationNow`, so arming a due day already behind us fired an
    // OS banner on the spot — one per person on the tick that first
    // evaluates a set of overdue people, duplicating their in-app nudges.
    clockedTest(
      'a due day already behind us arms no alarm',
      () async {
        await service.arm(
          subject: relationship(),
          derivation: derivation(dueDayUtc: DateTime.utc(2026, 8, 21)),
        );

        verifyNeverArmed();
      },
      now: DateTime(2026, 8, 25, 12),
    );

    // Skipping the alarm must not skip the housekeeping: an episode this one
    // superseded has to stop being armed either way.
    clockedTest(
      'a skipped alarm still retracts superseded episodes',
      () async {
        await service.arm(
          subject: relationship(),
          derivation: derivation(dueDayUtc: DateTime.utc(2026, 8, 21)),
        );

        verify(
          () => notifications.retractOpenRows(
            linkedEntityId: 'person-1',
            kind: NotificationKinds.relationshipCheckIn,
            exceptId: episodeId(),
          ),
        ).called(1);
      },
      now: DateTime(2026, 8, 25, 12),
    );

    clockedTest('a due day still ahead arms normally', () async {
      await service.arm(
        subject: relationship(),
        derivation: derivation(dueDayUtc: DateTime.utc(2026, 8, 21)),
      );

      expect(armedRows, hasLength(1));
    });

    clockedTest('passes a null category straight through', () async {
      await service.arm(
        subject: relationship(categoryId: null),
        derivation: derivation(),
      );

      verify(
        () => notifications.armEpisode(
          id: any(named: 'id'),
          scheduledFor: any(named: 'scheduledFor'),
          build: any(named: 'build'),
          // Asserted explicitly: omitting it would not match the recorded
          // call's named-argument map.
          // ignore: avoid_redundant_argument_values
          category: null,
        ),
      ).called(1);
      expect(armedRows.single.meta.category, isNull);
    });
  });

  group('RelationshipReminderService.clearFor', () {
    clockedTest('retracts every open reminder for the person', () async {
      await service.clearFor('person-1');

      verify(
        () => notifications.retractOpenRows(
          linkedEntityId: 'person-1',
          kind: NotificationKinds.relationshipCheckIn,
        ),
      ).called(1);
      verifyNeverArmed();
    });
  });

  // The sink's contract is that no call throws. The caller is an agent wake
  // whose real work — the cadence register — has already committed by the
  // time this runs, so letting a notification-store failure escape would fail
  // a wake that succeeded and schedule a retry of it.
  group('RelationshipReminderService best-effort contract', () {
    clockedTest('a failing create is logged, not thrown', () async {
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
        service.arm(subject: relationship(), derivation: derivation()),
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
        () => notifications.retractOpenRows(
          linkedEntityId: any(named: 'linkedEntityId'),
          kind: any(named: 'kind'),
          exceptId: any(named: 'exceptId'),
        ),
      ).thenThrow(Exception('boom'));

      await expectLater(
        service.arm(subject: relationship(), derivation: derivation()),
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
          () => notifications.retractOpenRows(
            linkedEntityId: any(named: 'linkedEntityId'),
            kind: any(named: 'kind'),
            exceptId: any(named: 'exceptId'),
          ),
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
        // the binding exists must degrade rather than take the wake down. The
        // lookup happens inside the row builder, which the repository runs
        // only when a row is actually written — so it surfaces there.
        await expectLater(
          build(messages: () => throw StateError('no binding')).arm(
            subject: relationship(),
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
        expect(armedRows, isEmpty);
      },
    );
  });
}
