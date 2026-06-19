import 'dart:async';
import 'dart:ui';

import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/notification_service.dart';

/// Raises an OS notification when a *new* sync conflict is detected, so the
/// user learns about divergence proactively instead of having to dig through
/// settings.
///
/// Conflicts already present when the observer starts are primed silently — we
/// only alert for conflicts that appear during the session, and coalesce a
/// burst (e.g. a device coming back online after a long offline stretch) into
/// a single "N entries were edited on two devices" banner.
class ConflictNotificationObserver {
  ConflictNotificationObserver({
    JournalDb? db,
    NotificationService? notificationService,
    AppLocalizations Function()? messages,
  }) : _db = db ?? getIt<JournalDb>(),
       // Stored as-is (resolved lazily via `_notifications`); a private named
       // initializing formal isn't valid Dart.
       // ignore: prefer_initializing_formals
       _notificationService = notificationService,
       _messages = messages ?? _deviceMessages;

  /// Resolves the user's locale for the OS banner copy, falling back to English
  /// for locales the app doesn't ship translations for.
  static AppLocalizations _deviceMessages() {
    final locale = PlatformDispatcher.instance.locale;
    return AppLocalizations.delegate.isSupported(locale)
        ? lookupAppLocalizations(locale)
        : AppLocalizationsEn();
  }

  /// Stable notification id — repeated alerts replace the previous banner
  /// rather than stacking.
  static const int notificationId = 0x5C0F;

  /// Deep link payload pointing at the conflicts list (consumed once OS-tap
  /// routing is wired; harmless until then).
  static const String deepLink = '/settings/advanced/conflicts';

  final JournalDb _db;
  final NotificationService? _notificationService;
  final AppLocalizations Function() _messages;

  /// Resolved lazily so the lazily-registered [NotificationService] is not
  /// forced to instantiate during DI bootstrap — only when the first alert
  /// actually needs to be raised.
  NotificationService get _notifications =>
      _notificationService ?? getIt<NotificationService>();

  final Set<String> _known = {};
  bool _primed = false;
  StreamSubscription<List<Conflict>>? _subscription;

  /// Subscribes to the unresolved-conflict stream. Idempotent.
  void start() {
    _subscription ??= _db
        .watchConflicts(ConflictStatus.unresolved)
        .listen(handleSnapshot);
  }

  /// Processes one snapshot of unresolved conflicts. Visible for testing so the
  /// priming/coalescing logic can be exercised without a live stream.
  void handleSnapshot(List<Conflict> conflicts) {
    final ids = conflicts.map((c) => c.id).toSet();
    final hasNew = ids.difference(_known).isNotEmpty;
    _known
      ..clear()
      ..addAll(ids);

    if (!_primed) {
      _primed = true;
      return;
    }
    if (!hasNew) return;

    final messages = _messages();
    _notifications.showNotificationNow(
      title: messages.conflictNotificationTitle,
      body: messages.conflictNotificationBody(ids.length),
      notificationId: notificationId,
      showOnMobile: true,
      showOnDesktop: true,
      deepLink: deepLink,
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
