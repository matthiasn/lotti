import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/window_service.dart';

/// Orchestrates in-app profile switches: persist the active-world marker,
/// quiesce the running generation, tear it down, and bootstrap the next one
/// against the new root.
///
/// Lives OUTSIDE getIt — it must survive `getIt.reset()`. Owned by the app
/// root widget, which supplies the UI hooks: [onSwitchStarted] swaps the
/// tree to a splash (unmounting every widget that watches the old
/// generation's services) and [onSwitchCompleted] rebuilds the ProviderScope
/// against the fresh registrations.
class ProfileSwitcher {
  ProfileSwitcher({
    required this.registry,
    required this.lifecycleHolder,
    required this.onSwitchStarted,
    required this.onSwitchCompleted,
    @visibleForTesting Future<void> Function()? settleFrame,
    // Test seams (also forwarded by LottiAppRoot's own seams); production
    // callers must leave these null.
    Future<void> Function()? teardownOverride,
    Future<void> Function()? bootstrapOverride,
  }) : _settleFrame = settleFrame ?? _endOfFrame {
    _teardown = teardownOverride ?? _defaultTeardown;
    _bootstrap = bootstrapOverride ?? _bootstrapGeneration;
  }

  final ProfileRegistry registry;
  final AppLifecycleHolder lifecycleHolder;

  /// Must synchronously replace the widget tree with the switch splash.
  final Future<void> Function() onSwitchStarted;

  /// Called after the new generation is bootstrapped; rebuilds the scope.
  final void Function() onSwitchCompleted;

  final Future<void> Function() _settleFrame;
  late final Future<void> Function() _teardown;
  late final Future<void> Function() _bootstrap;

  bool _switching = false;
  bool get isSwitching => _switching;

  static Future<void> _endOfFrame() => WidgetsBinding.instance.endOfFrame;

  /// Switches the app to [profileId]. The marker is persisted FIRST so a
  /// crash mid-switch reopens the intended world on next launch.
  ///
  /// If teardown or bootstrap throws, the app stays on the switch splash and
  /// the error propagates; recovery is an app restart, which boots the
  /// marked world from a clean process.
  Future<void> switchTo(String profileId) async {
    if (_switching) return;
    _switching = true;
    try {
      final state = await registry.load();
      if (state.profileById(profileId) == null) {
        throw ArgumentError.value(profileId, 'profileId', 'unknown profile');
      }
      if (state.activeProfileId == profileId) return;

      await registry.setActiveProfile(profileId);

      // Splash replaces the app tree; wait a frame so every widget-level
      // listener detaches before the services below are disposed.
      await onSwitchStarted();
      await _settleFrame();

      await _teardown();
      await _bootstrap();

      onSwitchCompleted();
    } finally {
      _switching = false;
    }
  }

  /// Default teardown: quiesce, dispose the service generation, reset getIt.
  Future<void> _defaultTeardown() async {
    await _quiesce();
    await _teardownGeneration();
  }

  /// Stops runtime activity that persists state, while the old generation's
  /// services are still alive to receive the writes.
  Future<void> _quiesce() async {
    if (getIt.isRegistered<TimeService>()) {
      try {
        await getIt<TimeService>().stop();
      } catch (e, st) {
        _logError(e, st, 'TimeService.stop');
      }
    }
    try {
      await AudioPlayerController.disposeActivePlayer();
    } catch (e, st) {
      _logError(e, st, 'AudioPlayerController.disposeActivePlayer');
    }
    lifecycleHolder.dispose();
    if (getIt.isRegistered<WindowService>()) {
      getIt<WindowService>().detachForRestart();
    }
  }

  Future<void> _teardownGeneration() async {
    await ServiceDisposer(getIt, _logError).disposeAll();

    // Best-effort final flush of the outgoing generation's log sink before
    // getIt.reset() disposes the LoggingService.
    try {
      if (getIt.isRegistered<LoggingService>()) {
        await getIt<LoggingService>().flush().timeout(
          const Duration(seconds: 1),
        );
      }
    } catch (_) {
      // Logging is best-effort during teardown.
    }

    // Fires the remaining registered dispose callbacks (UpdateNotifications,
    // EntitiesCacheService, NavService, EmbeddingStore, ...). Databases were
    // already closed above; they are registered without dispose callbacks,
    // so there is no double-close.
    await getIt.reset();
  }

  Future<void> _bootstrapGeneration() async {
    registerProcessLogging();
    final info = await resolveActiveProfile();
    await bootstrapProfileServices(
      info,
      lifecycleHolder: lifecycleHolder,
      // The window keeps its current geometry across an in-app switch.
      restoreWindow: false,
    );
    lifecycleHolder.listener = AppLifecycleListener(
      onExitRequested: handleAppExitRequested,
    );
  }

  void _logError(dynamic error, StackTrace stackTrace, String service) {
    try {
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.general,
          error as Object,
          stackTrace: stackTrace,
          subDomain: 'profileSwitch_$service',
        );
      }
    } catch (_) {
      // The logger itself may already be torn down.
    }
  }
}
