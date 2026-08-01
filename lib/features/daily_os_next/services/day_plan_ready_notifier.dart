import 'package:flutter/widgets.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';

/// Raises the ADR 0032 §5 "your plan is ready" OS notification when a durable
/// draft/refine job completes while the app is not in the foreground.
///
/// Wired as `DayProcessingOutboxProcessor.onJobOutcome`: the processor fires
/// it once per attempt outcome and this filters, so the path is event-driven —
/// no
/// polling, and a job that completes after the user backgrounded the app (or
/// closed the drafting modal) still surfaces its result.
class DayPlanReadyNotifier {
  DayPlanReadyNotifier({
    NotificationService? notificationService,
    AppLocalizations Function()? messages,
    bool Function()? isAppInForeground,
  }) : // Stored as-is (resolved lazily via `_notifications`); a private named
       // initializing formal isn't valid Dart.
       // ignore: prefer_initializing_formals
       _notificationService = notificationService,
       _messages = messages ?? _deviceMessages,
       _isAppInForeground = isAppInForeground ?? _lifecycleForeground;

  /// Resolves the user's locale for the OS banner copy, falling back to
  /// English for locales the app doesn't ship translations for.
  static AppLocalizations _deviceMessages() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return AppLocalizations.delegate.isSupported(locale)
        ? lookupAppLocalizations(locale)
        : AppLocalizationsEn();
  }

  /// Foreground check via the widgets binding: `resumed` means the UI is
  /// visible and the in-app Activity timeline is the completion surface, so
  /// no OS banner. A `null` lifecycle (before the first frame) is treated as
  /// foreground so startup drains never produce surprise banners.
  static bool _lifecycleForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Stable notification id — a newer completion replaces the previous
  /// banner rather than stacking one per job.
  static const int notificationId = 0xDA9;

  /// Deep link payload pointing at the Daily OS day surface.
  static const String deepLink = '/calendar';

  final NotificationService? _notificationService;
  final AppLocalizations Function() _messages;
  final bool Function() _isAppInForeground;

  /// Resolved lazily so the lazily-registered [NotificationService] is not
  /// forced to instantiate during DI bootstrap.
  NotificationService get _notifications =>
      _notificationService ?? getIt<NotificationService>();

  /// Handles one terminal job from the outbox processor.
  ///
  /// Never throws: the hook is invoked fire-and-forget from the processor's
  /// completion path, so a delivery failure (service resolution, locale
  /// lookup, platform plugin) must stay a contained best-effort miss instead
  /// of surfacing as an unhandled async error on job completion.
  Future<void> onJobOutcome(DayProcessingJob job) async {
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
      await _notifications.showNotificationNow(
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
          (false, true) => messages.dailyOsNextPlanChangesReadyNotificationBody,
          (true, false) => messages.dailyOsNextPlanFailedNotificationBody,
          (false, false) =>
            messages.dailyOsNextPlanChangesFailedNotificationBody,
        },
        // Same id for both outcomes: a later result replaces an earlier one
        // rather than stacking two notifications about the same day.
        notificationId: notificationId,
        showOnMobile: true,
        showOnDesktop: true,
        deepLink: deepLink,
      );
    } catch (e, s) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.agentWorkflow,
          e,
          message: 'failed to raise plan-outcome notification',
          stackTrace: s,
        );
      }
    }
  }
}
