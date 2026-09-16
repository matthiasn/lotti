import 'package:flutter/widgets.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/notifications/model/notification_episode_id.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/device_messages.dart';
import 'package:lotti/services/domain_logging.dart';

/// Records the ADR 0032 §5 "your plan is ready" outcome as a device-local
/// inbox row when a durable draft/refine job completes while the app is not
/// in the foreground.
///
/// Wired as `DayProcessingOutboxProcessor.onJobOutcome`: the processor fires
/// it once per attempt outcome and this filters, so the path is event-driven
/// — no polling, and a job that completes after the user backgrounded the app
/// (or closed the drafting modal) still surfaces its result. The row is the
/// durable record — it sits in the bell until dealt with — and the OS banner
/// is the scheduler's projection of it; a tap opens the Daily OS day.
///
/// The row never syncs: the job ledger is this device's, and "open Lotti to
/// try again" is only true here. One row per outcome, keyed by the job and
/// its status, so a job that failed and then succeeded on retry writes both
/// — and a later outcome for the same day retracts the earlier one, the way
/// the single OS notification id used to replace it.
class DayPlanReadyNotifier {
  DayPlanReadyNotifier({
    NotificationRepository? notificationRepository,
    AppLocalizations Function()? messages,
    bool Function()? isAppInForeground,
  }) : // Stored as-is (resolved lazily via `_notifications`); a private named
       // initializing formal isn't valid Dart.
       // ignore: prefer_initializing_formals
       _notificationRepository = notificationRepository,
       _messages = messages ?? deviceMessages,
       _isAppInForeground = isAppInForeground ?? _lifecycleForeground;

  /// Foreground check via the widgets binding: `resumed` means the UI is
  /// visible and the in-app Activity timeline is the completion surface, so
  /// no row and no banner. A `null` lifecycle (before the first frame) is
  /// treated as foreground so startup drains never produce surprise banners.
  static bool _lifecycleForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  final NotificationRepository? _notificationRepository;
  final AppLocalizations Function() _messages;
  final bool Function() _isAppInForeground;

  /// Resolved lazily: the notifier is built with the processing runtime,
  /// which can be earlier than the repository's registration.
  NotificationRepository get _notifications =>
      _notificationRepository ?? getIt<NotificationRepository>();

  /// The outcome being recorded, so the next one waits for it.
  Future<void> _applying = Future<void>.value();

  /// Handles one attempt outcome from the outbox processor.
  ///
  /// Not only terminal ones: `failed` is not terminal, and this is the
  /// listener that decides a failed plan job is worth reporting.
  ///
  /// Outcomes are recorded one at a time. Two for the same day running side
  /// by side would each arm a row and then retract the other's, leaving
  /// none; serialised, the later outcome's row is the one that survives.
  ///
  /// Never throws: the hook is invoked fire-and-forget from the processor's
  /// completion path, so a write failure (repository resolution, locale
  /// lookup, the notification store) must stay a contained best-effort miss
  /// instead of surfacing as an unhandled async error on job completion.
  Future<void> onJobOutcome(DayProcessingJob job) {
    final run = _applying.then((_) => _record(job));
    _applying = run;
    return run;
  }

  Future<void> _record(DayProcessingJob job) async {
    final succeeded = job.status == DayProcessingJobStatus.succeeded;
    // A job that exhausted its retries is exactly as worth saying out loud as
    // one that worked: the user asked for a plan and is otherwise left with a
    // day that silently never got planned. The retry cap added in #3558 made
    // this a reachable state rather than a theoretical one.
    final failed = job.status == DayProcessingJobStatus.failed;
    if (!succeeded && !failed) return;
    final isPlanJob =
        job.kind == DayProcessingJobKind.draftPlan ||
        job.kind == DayProcessingJobKind.refinePlan;
    if (!isPlanJob) return;
    if (_isAppInForeground()) return;

    try {
      final messages = _messages();
      final isDraft = job.kind == DayProcessingJobKind.draftPlan;
      final id = notificationEpisodeId(
        kind: NotificationKinds.dayPlanOutcome,
        subjectId: job.dayId,
        episodeKey: '${job.id}:${job.status.name}',
      );
      final notifications = _notifications;
      await notifications.armEpisode(
        id: id,
        scheduledFor: job.updatedAt,
        build: (meta) => NotificationEntity.dayPlanOutcome(
          meta: meta,
          dayId: job.dayId,
          succeeded: succeeded,
          title: switch ((isDraft, succeeded)) {
            (true, true) => messages.dailyOsNextPlanReadyNotificationTitle,
            (false, true) =>
              messages.dailyOsNextPlanChangesReadyNotificationTitle,
            (true, false) => messages.dailyOsNextPlanFailedNotificationTitle,
            (false, false) =>
              messages.dailyOsNextPlanChangesFailedNotificationTitle,
          },
          body: switch ((isDraft, succeeded)) {
            (true, true) => messages.dailyOsNextPlanReadyNotificationBody,
            (false, true) =>
              messages.dailyOsNextPlanChangesReadyNotificationBody,
            (true, false) => messages.dailyOsNextPlanFailedNotificationBody,
            (false, false) =>
              messages.dailyOsNextPlanChangesFailedNotificationBody,
          },
        ),
      );
      // A later result replaces an earlier one rather than stacking two
      // notices about the same day.
      await notifications.retractOpenRows(
        linkedEntityId: job.dayId,
        kind: NotificationKinds.dayPlanOutcome,
        exceptId: id,
      );
    } catch (e, s) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.agentWorkflow,
          e,
          message: 'failed to record plan-outcome notification',
          stackTrace: s,
        );
      }
    }
  }
}
