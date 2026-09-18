import 'package:lotti/database/database.dart';
import 'package:lotti/features/notifications/model/notification_kind_flags.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/notifications/scheduler/notification_startup_reconcile.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/consts.dart';

/// What a notification preference flip does to this device's OS state.
///
/// The same whether the flag was written here or arrived from a peer
/// (`SyncMessage.configFlag`): the alarms a preference governs are held by
/// the operating system of *this* device, so a switch flipped on the phone
/// has to reach the laptop's alarms too, not just its settings page.
///
/// Every step is best-effort: the flag is already stored by the time this
/// runs, so a platform call that fails is logged and never turns into a
/// setting reported as unsaved or a sync event left pending. A flag that is
/// not a notification preference does nothing here.
class NotificationPreferenceEffects {
  NotificationPreferenceEffects({
    required this._journalDb,
    required this._notificationService,
    required this._scheduler,
    required this._logger,
  });

  final JournalDb _journalDb;

  /// Resolved lazily: the service is registered lazily so a sandboxed build
  /// never materialises the platform plugin just to store a flag.
  final NotificationService Function() _notificationService;
  final NotificationScheduler Function() _scheduler;
  final DomainLogger _logger;

  /// Applies the consequence of [flag] having changed to `flag.status`.
  Future<void> apply(ConfigFlag flag) async {
    switch (flag.name) {
      case enableNotificationsFlag:
        if (flag.status) {
          // Turning on is where the permission prompt surfaces — the moment
          // the user asked for it — so the badge goes first. Rows written
          // while the flag was off carry no OS alarm (the scheduler's
          // platform calls are gated on the flag, and the repository's
          // idempotent creates never re-schedule an existing row), so
          // without the reconcile only the next app start would arm them.
          // Habit reminders have no row, so they are re-armed by hand.
          await _refreshBadge();
          await _reconcileRows();
          await _rearmHabitReminders();
        } else {
          // Alarms armed weeks ahead would still fire; drop them all, then
          // take the count off the icon. The zero-badge post has to come
          // after the sweep, or it would be swept too.
          await _cancelAllAlarms();
          await _refreshBadge();
        }
      case notifyHabitRemindersFlag:
        if (flag.status) {
          await _rearmHabitReminders();
        } else {
          await _cancelHabitReminders();
        }
      case showTaskBadgeFlag:
        await _refreshBadge();
      default:
        if (notificationRowKindFlags.contains(flag.name)) {
          // Re-arms the rows of a kind switched on and cancels the alarms of
          // one switched off — `schedule` decides per row.
          await _reconcileRows();
        }
    }
  }

  Future<void> _reconcileRows() =>
      reconcileScheduledNotifications(scheduler: _scheduler(), logger: _logger);

  /// `updateBadge` is the only thing that reconciles the icon with the flags,
  /// and nothing else calls it outside entry creation — so without this,
  /// switching the badge or notifications off left the task count sitting on
  /// the icon until the user happened to write something.
  Future<void> _refreshBadge() =>
      _bestEffort('badge', () => _notificationService().updateBadge());

  Future<void> _cancelAllAlarms() => _bestEffort(
    'cancelAll',
    () => _notificationService().cancelAllNotifications(),
  );

  /// Arms the next reminder of every active habit that has one — private
  /// habits included, whatever the `private` flag shows: the reminder is the
  /// user's own. A habit already completed today gets today's reminder once
  /// more — the completion path is what skips to tomorrow, and it will again
  /// at the next completion.
  Future<void> _rearmHabitReminders() => _bestEffort(
    'habitReminders',
    () async {
      final service = _notificationService();
      for (final habit in await _journalDb.getAllHabitDefinitionsAllPrivate()) {
        if (habit.active) {
          await service.scheduleHabitNotification(habit);
        }
      }
    },
  );

  Future<void> _cancelHabitReminders() => _bestEffort(
    'habitReminders',
    () async {
      final service = _notificationService();
      for (final habit in await _journalDb.getAllHabitDefinitionsAllPrivate()) {
        await service.cancelNotification(habit.id.hashCode);
      }
    },
  );

  Future<void> _bestEffort(String step, Future<void> Function() body) async {
    try {
      await body();
    } catch (exception, stackTrace) {
      _logger.error(
        LogDomain.notifications,
        exception,
        stackTrace: stackTrace,
        subDomain: 'notificationPreference.$step',
      );
    }
  }
}
