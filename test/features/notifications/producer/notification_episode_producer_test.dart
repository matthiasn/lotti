import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/notifications/model/notification_episode_id.dart';
import 'package:lotti/features/notifications/producer/notification_episode_producer.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

typedef _Subject = ({String id, String name, String? category});
typedef _Derivation = ({String episodeKey, DateTime fireAt});

/// The smallest producer the base class can host: every hook reads straight
/// off a record. [rowKind] and [linkTo] let a test break the two facts the
/// base checks before writing; [categorised] false leaves the base's own
/// default category in place.
class _Producer extends NotificationEpisodeProducer<_Subject, _Derivation> {
  _Producer({
    required super.notificationRepository,
    required super.domainLogger,
    this.rowKind = NotificationKinds.relationshipCheckIn,
    this.linkTo,
    this.categorised = true,
  });

  final String rowKind;
  final String? linkTo;
  final bool categorised;

  @override
  String get kind => NotificationKinds.relationshipCheckIn;

  @override
  String get logSubDomain => 'testProducer';

  @override
  String subjectIdOf(_Subject subject) => subject.id;

  @override
  String? categoryOf(_Subject subject) =>
      categorised ? subject.category : super.categoryOf(subject);

  @override
  String episodeKeyOf(_Derivation derivation) => derivation.episodeKey;

  @override
  DateTime scheduledInstantOf(_Derivation derivation) => derivation.fireAt;

  @override
  NotificationEntity buildRow({
    required _Subject subject,
    required _Derivation derivation,
    required NotificationMeta meta,
  }) => rowKind == NotificationKinds.relationshipCheckIn
      ? NotificationEntity.relationshipCheckIn(
          meta: meta,
          linkedRelationshipId: linkTo ?? subject.id,
          title: 'Hi ${subject.name}',
          body: 'body',
        )
      : NotificationEntity.taskOverdue(
          meta: meta,
          linkedTaskId: linkTo ?? subject.id,
          title: 'wrong kind',
          body: 'body',
        );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockNotificationRepository notifications;
  late MockDomainLogger logger;
  late List<NotificationEntity> armedRows;

  final now = DateTime(2026, 8, 19, 12);
  final ahead = DateTime(2026, 8, 21, 9);
  final behind = DateTime(2026, 8, 17, 9);

  const subject = (id: 'subject-1', name: 'Anna', category: 'cat-1');
  _Derivation derivation({
    DateTime? fireAt,
    String episodeKey = '2026-08-21',
  }) => (episodeKey: episodeKey, fireAt: fireAt ?? ahead);

  String episodeIdFor(String episodeKey) => notificationEpisodeId(
    kind: NotificationKinds.relationshipCheckIn,
    subjectId: subject.id,
    episodeKey: episodeKey,
  );

  /// Runs the builder the way the real repository does, so what the
  /// producer would have written is observable — and so a builder that
  /// throws surfaces through the mocked call.
  void stubArmToBuild() {
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
          createdAt: now,
          updatedAt: now,
          scheduledFor: invocation.namedArguments[#scheduledFor] as DateTime,
          vectorClock: const VectorClock({}),
          originatingHostId: '',
          category: invocation.namedArguments[#category] as String?,
        ),
      );
      armedRows.add(row);
      return row;
    });
  }

  setUp(() {
    notifications = MockNotificationRepository();
    logger = MockDomainLogger();
    armedRows = [];
    stubArmToBuild();
    when(
      () => notifications.retractOpenRows(
        linkedEntityId: any(named: 'linkedEntityId'),
        kind: any(named: 'kind'),
        exceptId: any(named: 'exceptId'),
      ),
    ).thenAnswer((_) async => const []);
  });

  _Producer producer({
    String? rowKind,
    String? linkTo,
    bool categorised = true,
  }) => _Producer(
    notificationRepository: notifications,
    domainLogger: logger,
    rowKind: rowKind ?? NotificationKinds.relationshipCheckIn,
    linkTo: linkTo,
    categorised: categorised,
  );

  Future<void> clocked(Future<void> Function() body) =>
      withClock(Clock.fixed(now), body);

  void verifyNothingLogged() => verifyNever(
    () => logger.error(
      any<LogDomain>(),
      any<Object>(),
      stackTrace: any(named: 'stackTrace'),
      subDomain: any(named: 'subDomain'),
    ),
  );

  group('NotificationEpisodeProducer.arm', () {
    test(
      'arms the episode under its derived id, instant and category',
      () async {
        await clocked(
          () => producer().arm(subject: subject, derivation: derivation()),
        );

        verify(
          () => notifications.armEpisode(
            id: episodeIdFor('2026-08-21'),
            scheduledFor: ahead,
            build: any(named: 'build'),
            category: 'cat-1',
          ),
        ).called(1);
        verifyNothingLogged();
      },
    );

    test(
      'writes the row the kind builds, around the meta it was handed',
      () async {
        await clocked(
          () => producer().arm(subject: subject, derivation: derivation()),
        );

        final row = armedRows.single as RelationshipCheckInNotification;
        expect(row.meta.id, episodeIdFor('2026-08-21'));
        expect(row.meta.scheduledFor, ahead);
        expect(row.meta.category, 'cat-1');
        expect(row.linkedRelationshipId, 'subject-1');
        expect(row.title, 'Hi Anna');
      },
    );

    test('retracts the episodes the new one supersedes, sparing it', () async {
      await clocked(
        () => producer().arm(subject: subject, derivation: derivation()),
      );

      verify(
        () => notifications.retractOpenRows(
          linkedEntityId: 'subject-1',
          kind: NotificationKinds.relationshipCheckIn,
          exceptId: episodeIdFor('2026-08-21'),
        ),
      ).called(1);
    });

    test('a kind without categories files the row under none', () async {
      await clocked(
        () => producer(categorised: false).arm(
          subject: subject,
          derivation: derivation(),
        ),
      );

      expect(armedRows.single.meta.category, isNull);
    });

    // NotificationScheduler.schedule routes a past instant to
    // showNotificationNow, so arming a lapsed episode would fire an OS banner
    // on the spot — one per subject on the tick that first evaluates a set
    // of overdue subjects, duplicating their in-app nudges.
    test('an episode already behind the clock arms nothing', () async {
      await clocked(
        () => producer().arm(
          subject: subject,
          derivation: derivation(fireAt: behind),
        ),
      );

      verifyNever(
        () => notifications.armEpisode(
          id: any(named: 'id'),
          scheduledFor: any(named: 'scheduledFor'),
          build: any(named: 'build'),
          category: any(named: 'category'),
        ),
      );
      expect(armedRows, isEmpty);
    });

    test('an episode due this very instant arms nothing either', () async {
      await clocked(
        () => producer().arm(
          subject: subject,
          derivation: derivation(fireAt: now),
        ),
      );

      expect(armedRows, isEmpty);
    });

    // Skipping the alarm must not skip the housekeeping: an episode this one
    // superseded has to stop being armed either way.
    test('a skipped alarm still retracts the superseded episodes', () async {
      await clocked(
        () => producer().arm(
          subject: subject,
          derivation: derivation(fireAt: behind),
        ),
      );

      verify(
        () => notifications.retractOpenRows(
          linkedEntityId: 'subject-1',
          kind: NotificationKinds.relationshipCheckIn,
          exceptId: episodeIdFor('2026-08-21'),
        ),
      ).called(1);
    });
  });

  group('NotificationEpisodeProducer.clearFor', () {
    test('retracts every open row of the kind for the subject', () async {
      await producer().clearFor('subject-1');

      verify(
        () => notifications.retractOpenRows(
          linkedEntityId: 'subject-1',
          kind: NotificationKinds.relationshipCheckIn,
        ),
      ).called(1);
      verifyNever(
        () => notifications.armEpisode(
          id: any(named: 'id'),
          scheduledFor: any(named: 'scheduledFor'),
          build: any(named: 'build'),
          category: any(named: 'category'),
        ),
      );
    });
  });

  // A row the base cannot retract is worse than no row: retractOpenRows
  // finds rows by kind and linked id, so a subclass that builds something
  // else would arm alarms nothing can ever cancel.
  group('NotificationEpisodeProducer row guard', () {
    test('a row of another kind is refused and logged', () async {
      await clocked(
        () => producer(rowKind: NotificationKinds.taskOverdue).arm(
          subject: subject,
          derivation: derivation(),
        ),
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(
            that: isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('taskOverdue'), contains('relationshipCheckIn')),
            ),
          ),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'testProducer.arm',
        ),
      ).called(1);
    });

    test('a row linked to another entity is refused and logged', () async {
      await clocked(
        () => producer(linkTo: 'someone-else').arm(
          subject: subject,
          derivation: derivation(),
        ),
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(
            that: isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('someone-else'), contains('subject-1')),
            ),
          ),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'testProducer.arm',
        ),
      ).called(1);
    });
  });

  // The sink's contract is that no call throws: by the time a producer runs,
  // the wake's real work has committed, and a notification-store failure must
  // not fail a wake that succeeded into a retry.
  group('NotificationEpisodeProducer best-effort contract', () {
    test('a failing arm is logged, not thrown', () async {
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
        clocked(
          () => producer().arm(subject: subject, derivation: derivation()),
        ),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          failure,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'testProducer.arm',
        ),
      ).called(1);
    });

    test('an arm that rejects its future is caught too', () async {
      when(
        () => notifications.armEpisode(
          id: any(named: 'id'),
          scheduledFor: any(named: 'scheduledFor'),
          build: any(named: 'build'),
          category: any(named: 'category'),
        ),
      ).thenAnswer((_) async => throw StateError('late boom'));

      await expectLater(
        clocked(
          () => producer().arm(subject: subject, derivation: derivation()),
        ),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'testProducer.arm',
        ),
      ).called(1);
    });

    test('a failing retract inside arm is contained too', () async {
      when(
        () => notifications.retractOpenRows(
          linkedEntityId: any(named: 'linkedEntityId'),
          kind: any(named: 'kind'),
          exceptId: any(named: 'exceptId'),
        ),
      ).thenThrow(Exception('boom'));

      await expectLater(
        clocked(
          () => producer().arm(subject: subject, derivation: derivation()),
        ),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'testProducer.arm',
        ),
      ).called(1);
    });

    test('a failing clearFor is logged under its own step', () async {
      when(
        () => notifications.retractOpenRows(
          linkedEntityId: any(named: 'linkedEntityId'),
          kind: any(named: 'kind'),
          exceptId: any(named: 'exceptId'),
        ),
      ).thenThrow(Exception('boom'));

      await expectLater(producer().clearFor('subject-1'), completes);

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'testProducer.clearFor',
        ),
      ).called(1);
    });
  });
}
