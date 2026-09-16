import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/notifications/model/notification_episode_id.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/device_messages.dart';
import 'package:lotti/services/domain_logging.dart';

/// Records a device-local inbox row when a *new* sync conflict is detected,
/// so the user learns about divergence proactively instead of having to dig
/// through settings — and finds it again in the bell after the OS banner,
/// the scheduler's projection of the row, is gone. A tap opens the conflicts
/// list.
///
/// Conflicts already present when the observer starts are primed silently —
/// we only alert for conflicts that appear during the session, and coalesce a
/// burst (e.g. a device coming back online after a long offline stretch) into
/// a single "N entries were edited on two devices" row. A later burst retracts
/// the earlier row, the way the single OS notification id used to replace it.
///
/// The row never syncs: a conflict is this device's disagreement with a peer,
/// and the list the row opens is this device's.
class ConflictNotificationObserver {
  ConflictNotificationObserver({
    JournalDb? db,
    NotificationRepository? notificationRepository,
    AppLocalizations Function()? messages,
  }) : _db = db ?? getIt<JournalDb>(),
       // Stored as-is (resolved lazily via `_notifications`); a private named
       // initializing formal isn't valid Dart.
       // ignore: prefer_initializing_formals
       _notificationRepository = notificationRepository,
       _messages = messages ?? deviceMessages;

  final JournalDb _db;
  final NotificationRepository? _notificationRepository;
  final AppLocalizations Function() _messages;

  /// Resolved lazily: the observer is registered — and started — before the
  /// repository is, so it can watch from the first moment of a session
  /// without forcing a registration order on the composition root.
  NotificationRepository get _notifications =>
      _notificationRepository ?? getIt<NotificationRepository>();

  final Set<String> _known = {};
  bool _primed = false;
  StreamSubscription<List<Conflict>>? _subscription;

  /// The snapshot being applied, so the next one waits for it.
  Future<void> _applying = Future<void>.value();

  /// Subscribes to the unresolved-conflict stream. Idempotent.
  ///
  /// Snapshots are applied one at a time. Conflicts arriving during a sync
  /// land one by one, each emitting its own snapshot, and two of those
  /// running side by side would each arm a row and then retract the other's
  /// — leaving no row at all. [handleSnapshot] never throws, so the chain
  /// never breaks.
  void start() {
    _subscription ??= _db.watchConflicts(ConflictStatus.unresolved).listen((
      snapshot,
    ) {
      _applying = _applying.then((_) => handleSnapshot(snapshot));
    });
  }

  /// Processes one snapshot of unresolved conflicts. Visible for testing so the
  /// priming/coalescing logic can be exercised without a live stream.
  ///
  /// Never throws: it runs as a stream listener, where an escaping error is an
  /// unhandled async error with nobody to catch it.
  Future<void> handleSnapshot(List<Conflict> conflicts) async {
    final byId = {for (final conflict in conflicts) conflict.id: conflict};
    final ids = byId.keys.toSet();
    final fresh = ids.difference(_known);

    if (!_primed) {
      _primed = true;
      _remember(ids);
      return;
    }
    if (fresh.isEmpty) {
      _remember(ids);
      return;
    }

    try {
      final messages = _messages();
      // The burst is the episode: the same new ids arriving again — a
      // re-emitted snapshot — write nothing, a different set is a new row.
      // Each id is stamped with its conflict's own time, so an entry that
      // conflicts again after being resolved is a new episode rather than
      // the id of a row already seen or retracted, which `armEpisode` would
      // leave alone.
      final id = notificationEpisodeId(
        kind: NotificationKinds.syncConflict,
        subjectId: syncConflictsSubjectId,
        episodeKey: (fresh.map((id) => _occurrence(byId[id]!)).toList()..sort())
            .join('+'),
      );
      final notifications = _notifications;
      await notifications.armEpisode(
        id: id,
        scheduledFor: clock.now(),
        build: (meta) => NotificationEntity.syncConflict(
          meta: meta,
          conflictCount: ids.length,
          title: messages.conflictNotificationTitle,
          body: messages.conflictNotificationBody(ids.length),
        ),
      );
      await notifications.retractOpenRows(
        linkedEntityId: syncConflictsSubjectId,
        kind: NotificationKinds.syncConflict,
        exceptId: id,
      );
      // Remembered only once both writes landed: a burst the database
      // refused stays fresh, so the next snapshot — usually the same one,
      // re-emitted — tries again instead of the alert vanishing or the
      // superseded row staying open. A re-arm of a row that did land is
      // `armEpisode`'s no-op.
      _remember(ids);
    } catch (e, s) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.sync,
          e,
          message: 'failed to record sync-conflict notification',
          stackTrace: s,
        );
      }
    }
  }

  void _remember(Set<String> ids) => _known
    ..clear()
    ..addAll(ids);

  /// One conflict occurrence: the entry plus the moment this conflict row
  /// was last written, UTC so two devices name it the same.
  static String _occurrence(Conflict conflict) =>
      '${conflict.id}@${conflict.updatedAt.toUtc().toIso8601String()}';

  /// Cancels the subscription and waits for the snapshot being applied, so
  /// nothing is written after the observer — and the services it writes
  /// through — is gone.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _applying;
  }
}
