import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    hide aiConfigRepositoryProvider;
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/utils/fd_limits.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:media_kit/media_kit.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:window_manager/window_manager.dart';

class AppConstants {
  const AppConstants._();

  static const Size defaultWindowSize = Size(1280, 720);
  static const Size minimumWindowSize = Size(360, 640);
}

/// Held for the lifetime of the process so the listener stays subscribed and
/// `onExitRequested` is invoked when macOS / desktop OS asks the app to quit.
// ignore: unused_element
late final AppLifecycleListener _appLifecycleListener;

/// Runs the same ordered teardown and platform-aware close path used by
/// window-manager close events. On macOS this reaches the immediate-exit path
/// only after all SQLite handles have been released.
Future<AppExitResponse> _handleAppExitRequested() async {
  await getIt<WindowService>().closeWindow();
  return AppExitResponse.exit;
}

/// Test seam for the desktop exit callback.
Future<AppExitResponse> handleAppExitRequested() => _handleAppExitRequested();

Future<void> main() async {
  // Raise the file descriptor soft limit before anything opens an FD. On
  // macOS, GUI apps inherit launchd's legacy soft limit of 256, which is
  // trivially exhausted (sockets, SQLite, attachments, logs). Captured
  // synchronously so we can log the outcome once LoggingService exists.
  final fdAdjustment = ensureFileDescriptorSoftLimit();

  await runZonedGuarded(
    () async {
      // Register DomainLogger immediately after its LoggingService sink so the
      // startup diagnostics below — and the runZonedGuarded error handler — can
      // resolve it before registerSingletons() runs. registerSingletons() then
      // reuses this instance instead of re-registering.
      final loggingService = LoggingService();
      getIt
        ..registerSingleton<LoggingService>(
          loggingService,
          dispose: (service) => service.dispose(),
        )
        ..registerSingleton<DomainLogger>(
          DomainLogger(loggingService: loggingService),
        );

      getIt<DomainLogger>().log(
        LogDomain.general,
        fdAdjustment.toString(),
        subDomain: 'fdLimits',
      );

      WidgetsFlutterBinding.ensureInitialized();
      try {
        MediaKit.ensureInitialized();
      } catch (e) {
        getIt<DomainLogger>().error(
          LogDomain.general,
          e,
          subDomain:
              'MediaKit initialization failed - continuing without media support',
        );
      }
      Animate.restartOnHotReload = true;

      if (isDesktop) {
        await windowManager.ensureInitialized();

        // Configure window options for flatpak compatibility
        const windowOptions = WindowOptions(
          size: AppConstants.defaultWindowSize,
          minimumSize: AppConstants.minimumWindowSize,
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
        );
        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
      }

      final docDir = await findDocumentsDirectory();

      getIt
        ..registerSingleton<SecureStorage>(SecureStorage())
        ..registerSingleton<Directory>(docDir)
        ..registerSingleton<SettingsDb>(SettingsDb())
        ..registerSingleton<WindowService>(WindowService());

      await getIt<WindowService>().restore();
      tz.initializeTimeZones();

      await registerSingletons();

      _appLifecycleListener = AppLifecycleListener(
        onExitRequested: _handleAppExitRequested,
      );

      FlutterError.onError = handleFlutterFrameworkError;

      runApp(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(getIt<MatrixService>()),
            maintenanceProvider.overrideWithValue(getIt<Maintenance>()),
            journalDbProvider.overrideWithValue(getIt<JournalDb>()),
            syncDatabaseProvider.overrideWithValue(getIt<SyncDatabase>()),
            loggingServiceProvider.overrideWithValue(getIt<LoggingService>()),
            outboxServiceProvider.overrideWithValue(getIt<OutboxService>()),
            aiConfigRepositoryProvider.overrideWithValue(
              getIt<AiConfigRepository>(),
            ),
          ],
          child: const MyBeamerApp(),
        ),
      );
    },
    handleUncaughtZoneError,
  );
}

/// Global framework error handler: presents the error on the console exactly
/// like Flutter's default handler and persists its full stack once per stable
/// fingerprint. Identical repeats are suppressed, with stack-free counted
/// summaries emitted every 100 observations or after at most one minute. This
/// preserves the diagnostic while preventing a rebuild loop from writing
/// thousands of copies of the same stack trace.
@visibleForTesting
void handleFlutterFrameworkError(FlutterErrorDetails details) {
  final report = _frameworkErrorLimiter.observe(details);
  switch (report.kind) {
    case _FrameworkErrorReportKind.full:
      FlutterError.presentError(details);
      getIt<DomainLogger>().error(
        LogDomain.general,
        details.exception,
        stackTrace: details.stack,
        subDomain: details.library,
      );
    case _FrameworkErrorReportKind.summary:
      _emitFrameworkErrorSummary(report, details.library);
    case _FrameworkErrorReportKind.suppressed:
      return;
  }
}

void _emitFrameworkErrorSummary(_FrameworkErrorReport report, String? library) {
  final summary =
      'Repeated Flutter framework error '
      'fingerprint=${report.fingerprint} '
      'errorType=${report.errorType} '
      'observed=${report.observed} '
      'suppressed=${report.observed} total=${report.total}';
  debugPrint(summary);
  getIt<DomainLogger>().error(
    LogDomain.general,
    const _RepeatedFlutterFrameworkError(),
    subDomain: library,
    message: summary,
  );
}

const _defaultFrameworkErrorSummaryEvery = 100;
const _defaultFrameworkErrorSummaryInterval = Duration(minutes: 1);
const _frameworkErrorFingerprintCapacity = 256;

var _frameworkErrorLimiter = _FrameworkErrorLimiter();

/// Resets process-global framework error sampling with deterministic thresholds.
///
/// Production never calls this; tests use it to isolate cases, keep timers off
/// by default, and opt into virtual-time scheduling for the interval drain.
@visibleForTesting
void resetFrameworkErrorSuppressionForTesting({
  int summaryEvery = _defaultFrameworkErrorSummaryEvery,
  Duration summaryInterval = _defaultFrameworkErrorSummaryInterval,
  bool scheduleIntervalSummaries = false,
}) {
  _frameworkErrorLimiter.dispose();
  _frameworkErrorLimiter = _FrameworkErrorLimiter(
    summaryEvery: summaryEvery,
    summaryInterval: summaryInterval,
    scheduleIntervalSummaries: scheduleIntervalSummaries,
  );
}

enum _FrameworkErrorReportKind { full, summary, suppressed }

class _FrameworkErrorReport {
  const _FrameworkErrorReport({
    required this.kind,
    required this.fingerprint,
    required this.errorType,
    required this.observed,
    required this.total,
  });

  final _FrameworkErrorReportKind kind;
  final String fingerprint;
  final String errorType;
  final int observed;
  final int total;
}

class _FrameworkErrorState {
  _FrameworkErrorState(this.lastReportedAt);

  DateTime lastReportedAt;
  int total = 0;
  int pending = 0;
  Timer? summaryTimer;
}

class _FrameworkErrorLimiter {
  _FrameworkErrorLimiter({
    this.summaryEvery = _defaultFrameworkErrorSummaryEvery,
    this.summaryInterval = _defaultFrameworkErrorSummaryInterval,
    this.scheduleIntervalSummaries = true,
  }) : assert(summaryEvery > 0, 'summaryEvery must be positive'),
       assert(
         summaryInterval > Duration.zero,
         'summaryInterval must be positive',
       );

  final int summaryEvery;
  final Duration summaryInterval;
  final bool scheduleIntervalSummaries;
  final LinkedHashMap<String, _FrameworkErrorState> _states =
      LinkedHashMap<String, _FrameworkErrorState>();

  _FrameworkErrorReport observe(FlutterErrorDetails details) {
    final now = clock.now();
    final fingerprint = _fingerprint(details);
    final errorType = details.exception.runtimeType.toString();
    final library = details.library;
    final state = _states.remove(fingerprint) ?? _FrameworkErrorState(now);
    _states[fingerprint] = state;
    while (_states.length > _frameworkErrorFingerprintCapacity) {
      _states.remove(_states.keys.first)?.summaryTimer?.cancel();
    }

    state.total++;
    if (state.total == 1) {
      return _FrameworkErrorReport(
        kind: _FrameworkErrorReportKind.full,
        fingerprint: fingerprint,
        errorType: errorType,
        observed: 1,
        total: 1,
      );
    }

    state.pending++;
    final elapsed = now.difference(state.lastReportedAt);
    if (state.pending >= summaryEvery || elapsed >= summaryInterval) {
      final observed = state.pending;
      state
        ..summaryTimer?.cancel()
        ..summaryTimer = null
        ..pending = 0
        ..lastReportedAt = now;
      return _FrameworkErrorReport(
        kind: _FrameworkErrorReportKind.summary,
        fingerprint: fingerprint,
        errorType: errorType,
        observed: observed,
        total: state.total,
      );
    }

    if (scheduleIntervalSummaries && state.summaryTimer == null) {
      state.summaryTimer = Timer(summaryInterval - elapsed, () {
        final observed = state.pending;
        state
          ..summaryTimer = null
          ..pending = 0
          ..lastReportedAt = clock.now();
        _emitFrameworkErrorSummary(
          _FrameworkErrorReport(
            kind: _FrameworkErrorReportKind.summary,
            fingerprint: fingerprint,
            errorType: errorType,
            observed: observed,
            total: state.total,
          ),
          library,
        );
      });
    }

    return _FrameworkErrorReport(
      kind: _FrameworkErrorReportKind.suppressed,
      fingerprint: fingerprint,
      errorType: errorType,
      observed: state.pending,
      total: state.total,
    );
  }

  String _fingerprint(FlutterErrorDetails details) {
    final signature = jsonEncode(<String>[
      details.exception.runtimeType.toString(),
      details.exceptionAsString(),
      details.library ?? '',
      details.context?.toDescription() ?? '',
      details.stack?.toString() ?? '',
      ...?details.informationCollector?.call().map(
        (node) => node.toStringDeep(),
      ),
    ]);
    return sha256.convert(utf8.encode(signature)).toString().substring(0, 16);
  }

  void dispose() {
    for (final state in _states.values) {
      state.summaryTimer?.cancel();
    }
    _states.clear();
  }
}

class _RepeatedFlutterFrameworkError {
  const _RepeatedFlutterFrameworkError();

  @override
  String toString() => 'Repeated Flutter framework error';
}

/// Uncaught-zone error handler: always echoes to the console, then records a
/// durable log entry when logging is already up. An error thrown before
/// DomainLogger is registered must not be masked by a GetIt lookup failure
/// in the handler itself.
@visibleForTesting
void handleUncaughtZoneError(Object error, StackTrace stackTrace) {
  debugPrint('Uncaught zone error: $error\n$stackTrace');
  if (getIt.isRegistered<DomainLogger>()) {
    getIt<DomainLogger>().error(
      LogDomain.general,
      error,
      stackTrace: stackTrace,
      subDomain: 'runZonedGuarded',
    );
  }
}
