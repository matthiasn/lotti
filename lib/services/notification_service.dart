import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/l10n/device_messages.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:timezone/timezone.dart';

abstract final class NotificationConstants {
  static const int badgeNotificationId = 1;
  static const int taskThreshold = 5;
  static const String defaultActionName = 'Open notification';
  static const String taskSingular = 'task';
  static const String taskPlural = 'tasks';
  static const String inProgressSuffix = ' in progress';
  static const String encouragementLow = 'Nice';
  static const String encouragementHigh = "Let's get that number down";
}

final JournalDb _db = getIt<JournalDb>();

bool get _skipNotificationsOnCurrentPlatform =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Whether the platform has an app-icon badge Lotti drives.
///
/// Darwin only, and the distinction is load-bearing rather than cosmetic. The
/// badge is a *number on the icon*, carried by a notification's `badge` field
/// and presented with `presentAlert: false`. Android has no equivalent: the
/// same call there posts a visible "3 tasks in progress" notification, turning
/// a silent icon count into a real interruption after every entry write.
bool get _supportsIconBadge =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Android notification channel for everything Lotti schedules.
///
/// One channel, deliberately: the user-facing control that matters is
/// [enableNotificationsFlag] plus the per-feature switches inside the app, and
/// splitting reminders across several system channels would offer a second,
/// competing set of toggles that Lotti's own settings then disagree with.
const _androidChannelId = 'lotti_reminders';

/// How Android is asked to hold a scheduled notification.
///
/// **Inexact, on purpose.** The exact modes need `SCHEDULE_EXACT_ALARM`, which
/// Android 13+ does not grant on install and the Play Store only accepts from
/// apps whose core function is alarms or calendars. Nothing Lotti schedules is
/// that: a check-in reminder for a monthly cadence and a habit reminder are
/// both "some time that morning" affordances, and trading a few minutes of
/// precision for not requesting a restricted permission is the right side of
/// that deal. `allowWhileIdle` is the half that matters — without it, Doze
/// defers the reminder on exactly the idle phone the reminder exists for.
const AndroidScheduleMode _androidScheduleMode =
    AndroidScheduleMode.inexactAllowWhileIdle;

/// The Android status-bar icon.
///
/// A drawable, not `@mipmap/ic_launcher`: Android masks the small icon by its
/// alpha channel and paints the result white, so a full-bleed launcher icon
/// arrives as a solid white square.
const _androidNotificationIcon = 'ic_stat_lotti';

/// Darwin initialization settings that ask the OS for **nothing**.
///
/// [DarwinInitializationSettings] defaults `requestAlertPermission`,
/// `requestBadgePermission` and `requestSoundPermission` to `true`, and the
/// native `initialize` passes whatever it is handed straight to
/// `UNUserNotificationCenter.requestAuthorization`. Constructing the plugin
/// with the defaults therefore raises the system "…would like to send you
/// notifications" dialog as a side effect of construction.
///
/// [NotificationService] is registered lazily, so construction happens on the
/// first `getIt<NotificationService>()` — which is `updateBadge()` during the
/// first entry write. A fresh install got the prompt while creating its first
/// task, before it had ever asked for a notification and with
/// [enableNotificationsFlag] still off.
///
/// With every option false the native `requestPermissionsImpl` returns early
/// without calling `requestAuthorization` at all, so this makes `initialize`
/// silent rather than merely quieter. Permission is instead requested later
/// and explicitly, by [NotificationService._requestPermissions], and only once
/// [NotificationService._notificationsAllowed] has confirmed the user wants
/// notifications.
const _silentDarwinInitialization = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
);

/// Resolves notification timezones while suppressing duplicate diagnostics for
/// persistent invalid zone strings.
class NotificationLocationResolver {
  final Set<String> _loggedUnresolvedTimezones = {};

  Location resolve(String timezone) {
    try {
      return getLocation(timezone);
    } catch (exception, stackTrace) {
      if (_loggedUnresolvedTimezones.add(timezone)) {
        getIt<DomainLogger>().error(
          LogDomain.notifications,
          exception,
          stackTrace: stackTrace,
          subDomain: 'resolveLocation',
        );
      }
      return local;
    }
  }
}

class NotificationService {
  NotificationService({
    AppLocalizations Function()? messages,
    Future<String> Function()? timezoneLookup,
  }) : _messages = messages ?? deviceMessages,
       _timezoneLookup = timezoneLookup ?? getLocalTimezone {
    initialized = _initializePlugin();
  }

  /// Resolves the device IANA zone; injectable to exercise DST independently
  /// of the host timezone.
  final Future<String> Function() _timezoneLookup;

  int badgeCount = 0;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final NotificationLocationResolver _locationResolver =
      NotificationLocationResolver();

  /// Localized copy for the Android notification channel, which is
  /// user-visible in system settings.
  ///
  /// **Fixed at first channel creation, not per notification.**
  /// `AndroidNotificationDetails.channelAction` defaults to
  /// `createIfNotExists`, so Android stores the name and description the first
  /// time a notification creates the channel and ignores what later posts
  /// carry. Switching the app's language therefore does *not* rename the
  /// channel; only `AndroidNotificationChannelAction.update` would, and even
  /// then some channel properties are immutable once created.
  final AppLocalizations Function() _messages;

  /// Completes when the constructor's fire-and-forget plugin initialization
  /// has finished.
  ///
  /// A test seam. Construction cannot be `async`, so `initialize` is started
  /// and left to run; nothing in the app waits for it. A test asserting on what
  /// `initialize` handed to the platform does need to know when it got there.
  ///
  /// It is deliberately *not* what handles failure — [_initializePlugin]
  /// catches around its own `await` for that, which is the part a `try`/`catch`
  /// around the bare call used to miss.
  @visibleForTesting
  // Awaited by notification tests outside DCM's `lib`-only usage graph.
  // ignore: unused-code
  late final Future<void> initialized;

  /// Memoized permission request — see [_requestPermissions].
  Future<void>? _permissionRequest;

  /// Whether the number on the app icon is known to read zero.
  ///
  /// Starts **false**, and that is the point: the icon badge outlives the
  /// process that set it, so a fresh run cannot assume it is clean. A user who
  /// quits with three tasks showing and comes back with notifications switched
  /// off would otherwise keep that number forever, because nothing would ever
  /// post over it.
  bool _badgeCleared = false;

  /// Initializes the plugin, degrading to a silent no-op on failure.
  ///
  /// A sandboxed build (flatpak) can fail to register the platform plugin
  /// entirely. That must not take start-up down: notifications are ancillary,
  /// and every method here already degrades to a no-op when the platform
  /// implementation is missing.
  Future<void> _initializePlugin() async {
    try {
      await flutterLocalNotificationsPlugin.initialize(
        settings: const InitializationSettings(
          // Android settings are not optional: `initialize` throws
          // `ArgumentError('Android settings must be set…')` without them, and
          // because that throw is swallowed below, omitting them left the
          // whole plugin silently uninitialised on Android — no reminders, no
          // habit alerts, no plan-ready banners, and no error the user saw.
          android: AndroidInitializationSettings(_androidNotificationIcon),
          linux: LinuxInitializationSettings(
            defaultActionName: NotificationConstants.defaultActionName,
          ),
          macOS: _silentDarwinInitialization,
          iOS: _silentDarwinInitialization,
        ),
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.notifications,
        exception,
        stackTrace: stackTrace,
        subDomain: 'initialization',
      );
    }
  }

  /// Resolves the local [Location] for scheduling, degrading to [local]
  /// rather than throwing.
  ///
  /// [getLocalTimezone] can still return a zone *abbreviation* when no IANA
  /// name is resolvable, and `getLocation` rejects those — `Location with the
  /// name "CEST" doesn't exist`. A reminder that cannot be scheduled in the
  /// user's exact zone is still worth scheduling in the process-local zone; it
  /// is never worth throwing, because this runs inside entry creation and the
  /// entry has already been written by the time it would.
  ///
  /// [local] is only a sane fallback because `configureLocalTimezone()` points
  /// it at the device's zone during start-up. The `timezone` package defaults
  /// it to **UTC**, and falling back to that would move a 09:00 reminder by
  /// the device's whole offset rather than degrade gracefully.
  Location _resolveLocation(String timezone) =>
      _locationResolver.resolve(timezone);

  /// Whether Lotti may hand anything at all to the OS notification system.
  ///
  /// Two conditions, checked in the order they are cheapest to evaluate:
  ///
  /// 1. The platform must have a notification surface Lotti drives. Linux and
  ///    Windows do not, so nothing there is worth a database read either.
  /// 2. [enableNotificationsFlag] must be on. It ships **off**.
  ///
  /// Every path that can reach [_requestPermissions] goes through here first,
  /// and that ordering is the whole point. Requesting permission is what
  /// raises the OS dialog, so asking before the flag has been consulted
  /// prompts users who have deliberately switched notifications off.
  Future<bool> _notificationsAllowed() async {
    if (_skipNotificationsOnCurrentPlatform) {
      return false;
    }
    return _db.getConfigFlag(enableNotificationsFlag);
  }

  /// Requests alert + badge permission from the OS, at most once per process.
  ///
  /// Reached only after [_notificationsAllowed] has returned true, so a user
  /// with notifications switched off is never asked.
  ///
  /// The result is memoized because the OS shows its dialog for the *first*
  /// request only; every later call is a channel round trip that returns a
  /// decision already on file. Caching the future rather than a boolean also
  /// collapses concurrent callers into a single request.
  ///
  /// A failure is logged and swallowed, and the memo is dropped so the next
  /// call tries again. Both halves matter. Asking is best-effort, but the
  /// callers are not: `NotificationRepository` schedules inside a vector-clock
  /// scope that commits only when its body returns, so an error escaping here
  /// would abort notification creation and every lifecycle transition — and
  /// memoizing a *rejected* future would make that abort permanent for the
  /// life of the process rather than transient.
  Future<void> _requestPermissions() =>
      _permissionRequest ??= _requestPermissionsOnce();

  Future<void> _requestPermissionsOnce() async {
    try {
      await _requestPlatformPermissions();
    } catch (exception, stackTrace) {
      _permissionRequest = null;
      getIt<DomainLogger>().error(
        LogDomain.notifications,
        exception,
        stackTrace: stackTrace,
        subDomain: 'requestPermissions',
      );
    }
  }

  /// `resolvePlatformSpecificImplementation` returns null off its matching
  /// platform, so at most one of these does anything on any given device, and
  /// none do on Linux or Windows.
  ///
  /// Android's `POST_NOTIFICATIONS` is requested here rather than at
  /// `initialize` for the same reason as Darwin's: the runtime prompt must
  /// come after [_notificationsAllowed] has confirmed the user wants
  /// notifications, never as a side effect of the plugin waking up. Exact
  /// alarms are deliberately *not* requested — see [scheduleNotificationAt].
  Future<void> _requestPlatformPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Badge presentation. iOS never alerts for the badge — the number on the
  /// icon is the whole message there — while macOS alerts for a non-zero count
  /// so the "N tasks in progress" text is actually delivered.
  NotificationDetails _badgeDetails({required bool presentAlertOnDesktop}) =>
      NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          badgeNumber: badgeCount,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: presentAlertOnDesktop,
          presentBadge: true,
          badgeNumber: badgeCount,
        ),
      );

  /// Android presentation, or null where it would be discarded.
  ///
  /// Built only on Android and only for a caller that opted into mobile — the
  /// channel name and description are user-visible in system settings, so they
  /// come from the ARB catalogs, and resolving the device locale is not worth
  /// doing for a value iOS and macOS will ignore.
  ///
  /// `high` importance is the Android counterpart of the Darwin
  /// `timeSensitive` interruption level the two branches below use: it is what
  /// makes the notification a heads-up banner rather than a silent row in the
  /// shade.
  /// The channel copy, degrading to English rather than throwing.
  ///
  /// This runs deep inside a notification write: `NotificationRepository`
  /// schedules from within a vector-clock scope that commits only when its
  /// body returns, so an exception escaping here would abort the notification
  /// row itself — the same trap [_requestPermissions] documents and guards
  /// against. Resolving a locale needs the widgets binding, which is one more
  /// thing that can be absent, and a channel labelled in the wrong language is
  /// an incomparably smaller failure than a reminder that is never written.
  AppLocalizations _resolveMessages() {
    try {
      return _messages();
    } catch (exception, stackTrace) {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.notifications,
          exception,
          stackTrace: stackTrace,
          subDomain: 'resolveChannelMessages',
        );
      }
      return AppLocalizationsEn();
    }
  }

  AndroidNotificationDetails? _androidAlertDetails({
    required bool showOnMobile,
  }) {
    if (!showOnMobile || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final messages = _resolveMessages();
    return AndroidNotificationDetails(
      _androidChannelId,
      messages.notificationChannelRemindersName,
      channelDescription: messages.notificationChannelRemindersDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// Presentation shared by the three entry points that raise a real alert.
  ///
  /// A platform the caller did not opt into gets null details, which is what
  /// keeps a mobile-only reminder off the desktop and vice versa.
  NotificationDetails _alertDetails({
    required String title,
    required bool showOnMobile,
    required bool showOnDesktop,
  }) => NotificationDetails(
    android: _androidAlertDetails(showOnMobile: showOnMobile),
    iOS: showOnMobile
        ? const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBanner: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          )
        : null,
    macOS: showOnDesktop
        ? DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            subtitle: title,
            interruptionLevel: InterruptionLevel.timeSensitive,
          )
        : null,
  );

  /// Reflects the number of tasks in progress on the app icon.
  ///
  /// Runs after every entry write, which makes it the first thing to resolve
  /// the lazily registered service — and therefore the first thing that could
  /// prompt for permission. It must not, while notifications are off.
  Future<void> updateBadge() async {
    // Before the flag check, because this is not a "notifications are off"
    // path: there is simply nothing to reflect a count on. Falling through
    // would post the badge notification as a visible alert on Android.
    if (!_supportsIconBadge) {
      return;
    }
    if (!await _notificationsAllowed()) {
      await _clearBadge();
      return;
    }

    await _requestPermissions();

    final count = await _db.getWipCount();

    if (count == badgeCount) {
      return;
    }

    if (count == 0) {
      await _zeroBadge();
      return;
    }

    badgeCount = count;
    _badgeCleared = false;

    await flutterLocalNotificationsPlugin.cancel(
      id: NotificationConstants.badgeNotificationId,
    );

    final label = badgeCount == 1
        ? NotificationConstants.taskSingular
        : NotificationConstants.taskPlural;

    await flutterLocalNotificationsPlugin.show(
      id: NotificationConstants.badgeNotificationId,
      title: '$badgeCount $label${NotificationConstants.inProgressSuffix}',
      body: badgeCount < NotificationConstants.taskThreshold
          ? NotificationConstants.encouragementLow
          : NotificationConstants.encouragementHigh,
      notificationDetails: _badgeDetails(presentAlertOnDesktop: true),
    );
  }

  /// Takes the badge down when notifications are off.
  ///
  /// Switching the flag off has to take the badge with it: the number on the
  /// icon is an OS-level artefact, and leaving it alive for someone who just
  /// said they did not want notifications is the same defect as prompting
  /// them.
  ///
  /// Guarded on [_badgeCleared] so the ordinary case — notifications off, with
  /// [updateBadge] running after every entry write — costs at most one pair of
  /// platform calls per process rather than one per write. It cannot be
  /// guarded on [badgeCount], which starts at zero on a run that inherited a
  /// badge from the previous one.
  ///
  /// The platform check is repeated because [_notificationsAllowed] folds
  /// "unsupported platform" and "user said no" into one answer, and only the
  /// second is a reason to clear. A platform Lotti does not badge has no badge
  /// to take down.
  Future<void> _clearBadge() async {
    if (_badgeCleared || _skipNotificationsOnCurrentPlatform) {
      return;
    }
    await _zeroBadge();
  }

  /// Replaces the badge notification with one carrying `badgeNumber: 0`.
  ///
  /// Both calls are load-bearing, and cancelling alone is not enough.
  /// `cancel` removes the delivered record — the "3 tasks in progress" entry
  /// sitting in Notification Center — but on Darwin the number on the icon is
  /// carried by a notification's `badge` field (`content.badge` natively), and
  /// `removeDeliveredNotifications` does not reset it. Only a post of zero
  /// actually clears the icon.
  ///
  /// Posting this while notifications are off is not a notification in any
  /// sense the user sees: it is empty, `presentAlert: false`, and exists only
  /// to zero the number. It also cannot prompt — the dialog comes from
  /// `requestAuthorization`, never from posting — and without authorization it
  /// silently does nothing, which is correct, because then there is no badge.
  Future<void> _zeroBadge() async {
    badgeCount = 0;
    _badgeCleared = true;

    await flutterLocalNotificationsPlugin.cancel(
      id: NotificationConstants.badgeNotificationId,
    );
    await flutterLocalNotificationsPlugin.show(
      id: NotificationConstants.badgeNotificationId,
      title: '',
      body: '',
      notificationDetails: _badgeDetails(presentAlertOnDesktop: false),
    );
  }

  Future<void> scheduleHabitNotification(
    HabitDefinition habitDefinition, {
    int daysToAdd = 0,
  }) async {
    final alertAtTime = habitDefinition.habitSchedule.maybeMap(
      daily: (d) => d.alertAtTime,
      orElse: () => null,
    );

    if (alertAtTime != null) {
      final location = _resolveLocation(await _timezoneLookup());
      final now = TZDateTime.from(clock.now(), location);
      // Construct a calendar date: adding 24 hours can skip or repeat a day
      // when daylight saving time changes.
      var notifyAt = TZDateTime(
        location,
        now.year,
        now.month,
        now.day + daysToAdd,
        alertAtTime.hour,
        alertAtTime.minute,
        alertAtTime.second,
      );
      if (!notifyAt.isAfter(now)) {
        notifyAt = TZDateTime(
          location,
          now.year,
          now.month,
          now.day + 1,
          alertAtTime.hour,
          alertAtTime.minute,
          alertAtTime.second,
        );
      }

      await getIt<NotificationService>().scheduleNotification(
        title: habitDefinition.name,
        body: habitDefinition.description,
        showOnMobile: true,
        showOnDesktop: false,
        notifyAt: notifyAt,
        notificationId: habitDefinition.id.hashCode,
      );
    }
  }

  /// Schedules the requested calendar date and wall-clock time in the device
  /// zone. Use [scheduleNotificationAt] when [notifyAt] represents an instant.
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime notifyAt,
    required int notificationId,
    required bool showOnMobile,
    required bool showOnDesktop,
    bool repeat = false,
    String? deepLink,
  }) async {
    if (!await _notificationsAllowed()) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
    final location = _resolveLocation(await _timezoneLookup());

    final scheduledDate = TZDateTime(
      location,
      notifyAt.year,
      notifyAt.month,
      notifyAt.day,
      notifyAt.hour,
      notifyAt.minute,
      notifyAt.second,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _alertDetails(
        title: title,
        showOnMobile: showOnMobile,
        showOnDesktop: showOnDesktop,
      ),
      matchDateTimeComponents: repeat ? DateTimeComponents.time : null,
      payload: deepLink,
      androidScheduleMode: _androidScheduleMode,
    );
  }

  Future<void> scheduleNotificationAt({
    required String title,
    required String body,
    required DateTime notifyAt,
    required int notificationId,
    required bool showOnMobile,
    required bool showOnDesktop,
    String? deepLink,
  }) async {
    if (!await _notificationsAllowed()) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
    final location = _resolveLocation(await _timezoneLookup());
    final scheduledDate = TZDateTime.from(notifyAt, location);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _alertDetails(
        title: title,
        showOnMobile: showOnMobile,
        showOnDesktop: showOnDesktop,
      ),
      payload: deepLink,
      androidScheduleMode: _androidScheduleMode,
    );
  }

  Future<void> showNotificationNow({
    required String title,
    required String body,
    required int notificationId,
    required bool showOnMobile,
    required bool showOnDesktop,
    String? deepLink,
  }) async {
    if (!await _notificationsAllowed()) {
      return;
    }

    await _requestPermissions();
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);

    await flutterLocalNotificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: _alertDetails(
        title: title,
        showOnMobile: showOnMobile,
        showOnDesktop: showOnDesktop,
      ),
      payload: deepLink,
    );
  }

  Future<void> cancelNotification(int notificationId) async {
    if (_skipNotificationsOnCurrentPlatform) {
      return;
    }

    await flutterLocalNotificationsPlugin.cancel(id: notificationId);
  }
}
