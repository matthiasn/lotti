import 'package:clock/clock.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/classes/notification_producer.dart';
import 'package:lotti/features/notifications/model/notification_episode_id.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';

/// Projects one agent kind's deterministic verdict into episode rows.
///
/// The choreography every kind shares — the one the relationship reminder
/// established (ADR 0039, plan v2 phase 8) — lives here exactly once: derive
/// the episode's id from `(kind, subject, episode key)`, arm it idempotently
/// while its instant is still ahead, retract the episodes it superseded,
/// clear the lot when consent is withdrawn, and never let a
/// notification-store failure escape into the wake that called. A kind
/// supplies only what differs: how to read the subject and the episode out of
/// its own types, when the alert fires, and the row itself.
///
/// **A lapsed episode earns no alarm.** `NotificationScheduler.schedule`
/// routes a past instant to `showNotificationNow`, so arming an episode
/// already behind the clock would fire an OS banner on the spot — one per
/// subject on the tick that first evaluates a set of overdue subjects,
/// duplicating the in-app nudges that same tick raises. The banner channel
/// already covers a device the user is holding; this channel exists for the
/// device they are not. The retraction still runs on that path: whether or
/// not an episode earns an alarm, the ones it superseded must stop being
/// armed.
///
/// **One row per episode means an ignored subject is alerted once.** The
/// episode key only moves when the subject's own state does, so a subject the
/// user never acts on is never re-alerted — the anti-nag ceiling of the
/// banner escalation, applied to the OS channel. Making a kind recur would
/// mean rolling its episode key forward on elapsed time rather than on the
/// subject's state.
abstract class NotificationEpisodeProducer<TSubject, TDerivation>
    implements NotificationEpisodeSink<TSubject, TDerivation> {
  NotificationEpisodeProducer({
    required NotificationRepository notificationRepository,
    required DomainLogger domainLogger,
  }) : _notifications = notificationRepository,
       _logger = domainLogger;

  final NotificationRepository _notifications;
  final DomainLogger _logger;

  /// The wire discriminator of the rows this producer writes —
  /// `NotificationEntity.type` of every row [buildRow] returns, and the
  /// namespace of every episode id. Compare [NotificationKinds].
  String get kind;

  /// The log sub-domain the producer's failures are filed under, e.g.
  /// `relationshipReminder`; `arm` and `clearFor` append their own name.
  String get logSubDomain;

  /// The id of the entity [subject] is — the `linkedEntityId` of every row
  /// this producer writes, and what [clearFor] retracts by.
  @protected
  String subjectIdOf(TSubject subject);

  /// What makes [derivation] one episode rather than another — a due day, a
  /// goal period. Two derivations with the same key are the same episode.
  @protected
  String episodeKeyOf(TDerivation derivation);

  /// The local instant the alert should fire. An instant already behind the
  /// clock arms nothing (see the class doc).
  @protected
  DateTime scheduledInstantOf(TDerivation derivation);

  /// The category the row is filed under, if any.
  @protected
  String? categoryOf(TSubject subject) => null;

  /// The row itself — the kind's own union variant, carrying [meta] as
  /// handed in and the subject's id as its linked entity. Invoked only when
  /// no row for the episode exists yet.
  @protected
  NotificationEntity buildRow({
    required TSubject subject,
    required TDerivation derivation,
    required NotificationMeta meta,
  });

  @override
  @nonVirtual
  Future<void> arm({
    required TSubject subject,
    required TDerivation derivation,
  }) => _bestEffort('arm', () async {
    final subjectId = subjectIdOf(subject);
    final episodeId = notificationEpisodeId(
      kind: kind,
      subjectId: subjectId,
      episodeKey: episodeKeyOf(derivation),
    );
    final scheduledFor = scheduledInstantOf(derivation);
    if (scheduledFor.isAfter(clock.now())) {
      await _notifications.armEpisode(
        id: episodeId,
        scheduledFor: scheduledFor,
        category: categoryOf(subject),
        build: (meta) => _checkedRow(
          subject: subject,
          derivation: derivation,
          meta: meta,
          subjectId: subjectId,
        ),
      );
    }
    await _notifications.retractOpenRows(
      linkedEntityId: subjectId,
      kind: kind,
      exceptId: episodeId,
    );
  });

  @override
  @nonVirtual
  Future<void> clearFor(String subjectId) => _bestEffort(
    'clearFor',
    () => _notifications.retractOpenRows(linkedEntityId: subjectId, kind: kind),
  );

  /// [buildRow], checked against the two facts the choreography relies on:
  /// the row must be of [kind] (or `retractOpenRows` would never find it) and
  /// linked to the subject (or `clearFor` would never reach it). A mismatch is
  /// a programming error in the subclass, surfaced through the log rather
  /// than written as a row nothing can retract.
  NotificationEntity _checkedRow({
    required TSubject subject,
    required TDerivation derivation,
    required NotificationMeta meta,
    required String subjectId,
  }) {
    final row = buildRow(subject: subject, derivation: derivation, meta: meta);
    if (row.type != kind || row.linkedEntityId != subjectId) {
      throw StateError(
        'buildRow of $runtimeType returned a ${row.type} row linked to '
        '${row.linkedEntityId}; expected a $kind row linked to $subjectId',
      );
    }
    return row;
  }

  /// Honours [NotificationEpisodeSink]'s non-throwing contract.
  ///
  /// The caller is an agent wake whose actual job has already committed by
  /// the time this runs. Letting a notification-store failure escape would
  /// fail that wake and schedule a retry of work that already succeeded, to
  /// fix an alarm the next tick re-derives from scratch anyway.
  Future<void> _bestEffort(String step, Future<void> Function() body) async {
    try {
      await body();
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.notifications,
        error,
        stackTrace: stackTrace,
        subDomain: '$logSubDomain.$step',
      );
    }
  }
}
