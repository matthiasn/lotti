import 'dart:async';

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:lotti/services/startup_tasks.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/window_service.dart';

/// The profile a closed generation belonged to, handed to the work that runs
/// while it is closed.
@immutable
class ClosedProfileGeneration {
  const ClosedProfileGeneration({required this.profile, required this.root});

  final Profile profile;

  /// The profile's root directory. Nothing in the process holds a file in it
  /// open while the generation is closed.
  final Directory root;
}

/// Another switch or closed-generation operation is already running.
class ProfileLifecycleBusyException implements Exception {
  const ProfileLifecycleBusyException();

  @override
  String toString() =>
      'ProfileLifecycleBusyException: a profile switch or backup is running';
}

/// The running generation could not be proven closed, so the work that
/// needed it closed never ran. The same profile was restarted.
class ProfileQuiescenceException implements Exception {
  ProfileQuiescenceException(List<ServiceDisposalFailure> failures)
    : failures = List.unmodifiable(failures);

  /// Every step that threw or missed its deadline while closing.
  final List<ServiceDisposalFailure> failures;

  @override
  String toString() =>
      'ProfileQuiescenceException: could not close ${failures.join('; ')}';
}

/// The profile could not be torn down cleanly enough to start again, or
/// failed to start again after being closed.
///
/// The app is left on the switch splash. The profile's data is untouched and
/// the active-world marker was never changed, so relaunching the app boots
/// the same profile from a clean process.
class ProfileRestartException implements Exception {
  const ProfileRestartException(this.cause, this.causeStackTrace);

  final Object cause;
  final StackTrace causeStackTrace;

  @override
  String toString() => 'ProfileRestartException: $cause';
}

/// The work changed the profile, but the changed profile failed to start
/// or to prove itself healthy, so the change was rolled back and the
/// profile restarted as it was.
class ProfileRolledBackException implements Exception {
  const ProfileRolledBackException(this.cause, this.causeStackTrace);

  /// Why the changed profile was rejected.
  final Object cause;
  final StackTrace causeStackTrace;

  @override
  String toString() => 'ProfileRolledBackException: $cause';
}

/// Orchestrates in-app profile switches: persist the active-world marker,
/// quiesce the running generation, tear it down, and bootstrap the next one
/// against the new root. It also closes and restarts the running profile for
/// work that needs its files at rest, such as a backup
/// ([runWithGenerationClosed]).
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
    _teardown = teardownOverride == null
        ? _defaultTeardown
        : () async {
            await teardownOverride();
            return const <ServiceDisposalFailure>[];
          };
    _bootstrap = bootstrapOverride ?? _bootstrapGeneration;
  }

  final ProfileRegistry registry;
  final AppLifecycleHolder lifecycleHolder;

  /// Must synchronously replace the widget tree with the switch splash.
  final Future<void> Function() onSwitchStarted;

  /// Called after the new generation is bootstrapped; rebuilds the scope.
  final void Function() onSwitchCompleted;

  final Future<void> Function() _settleFrame;

  /// Closes the running generation and returns every step that failed.
  late final Future<List<ServiceDisposalFailure>> Function() _teardown;
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

      // A switch is best effort: whatever failed to close is logged, and the
      // next world boots regardless.
      await _teardown();
      await _bootstrap();

      onSwitchCompleted();
    } finally {
      _switching = false;
    }
  }

  /// Closes the running generation, runs [whileClosed] against the profile's
  /// root while nothing holds a file in it open, then starts the same profile
  /// again.
  ///
  /// Unlike [switchTo], closing is strict. If any step throws or misses its
  /// deadline, [whileClosed] is skipped and a [ProfileQuiescenceException]
  /// names the steps — work that relies on the files being at rest must never
  /// run against a generation that might still be writing. The profile is
  /// restarted in every case: after success, after a close failure, and after
  /// [whileClosed] throws, whose error is rethrown once the profile is back.
  ///
  /// Work that changes the profile's files (a restore) passes [rollBack]:
  /// when [whileClosed] succeeded but the restarted profile then fails to
  /// bootstrap or [verifyRestarted] throws, that generation is torn down,
  /// [rollBack] undoes the change, the profile boots again as it was, and
  /// [ProfileRolledBackException] reports the cause.
  ///
  /// Throws [ProfileLifecycleBusyException] without touching anything while a
  /// switch or another closed-generation operation is running, and
  /// [ProfileRestartException] when the service container cannot be reset,
  /// the restart fails, or a rollback cannot complete; [whileClosed] does not
  /// run in the first case. Work that itself throws [ProfileRestartException]
  /// leaves the profile closed rather than starting files it could not put
  /// back in order.
  Future<T> runWithGenerationClosed<T>(
    Future<T> Function(ClosedProfileGeneration closed) whileClosed, {
    Future<void> Function()? verifyRestarted,
    Future<void> Function()? rollBack,
  }) async {
    if (_switching) throw const ProfileLifecycleBusyException();
    _switching = true;
    try {
      final context = getIt<ProfileContext>();
      final closed = ClosedProfileGeneration(
        profile: context.profile,
        root: context.root,
      );

      await onSwitchStarted();
      await _settleFrame();

      final List<ServiceDisposalFailure> failures;
      try {
        failures = await _teardown();
      } catch (e, st) {
        // The container could not be reset, so bootstrapping onto it is not
        // safe either. Stay on the splash, as a failed switch does.
        throw ProfileRestartException(e, st);
      }

      late T result;
      Object? workError;
      StackTrace? workStackTrace;
      if (failures.isEmpty) {
        try {
          result = await whileClosed(closed);
        } catch (e, st) {
          workError = e;
          workStackTrace = st;
        }
      }

      if (workError is ProfileRestartException) {
        // The work could not leave the files in a startable state. Starting
        // them anyway could make things worse; the next launch recovers.
        Error.throwWithStackTrace(workError, workStackTrace!);
      }
      final workChangedProfile = failures.isEmpty && workError == null;
      try {
        await _bootstrap();
        if (workChangedProfile) await verifyRestarted?.call();
      } catch (e, st) {
        if (!workChangedProfile || rollBack == null) {
          // Left on the splash: the marker still names this profile, so a
          // relaunch boots it from a clean process.
          throw ProfileRestartException(e, st);
        }
        await _restartRolledBack(rollBack);
        onSwitchCompleted();
        throw ProfileRolledBackException(e, st);
      }
      onSwitchCompleted();

      if (failures.isNotEmpty) throw ProfileQuiescenceException(failures);
      if (workError != null) {
        Error.throwWithStackTrace(workError, workStackTrace!);
      }
      return result;
    } finally {
      _switching = false;
    }
  }

  /// Tears down a generation that failed to start or verify, undoes the
  /// work with [rollBack], and boots the profile again. Any failure along the
  /// way — including a service of the rejected generation that would not
  /// close — leaves the app on the splash, without running [rollBack] on
  /// files something might still be writing; the next launch finishes it.
  Future<void> _restartRolledBack(Future<void> Function() rollBack) async {
    try {
      // The rollback moves the rejected generation's files, so that
      // generation has to be closed as strictly as the one before the work:
      // anything still running could keep writing to files being moved.
      final failures = await _teardown();
      if (failures.isNotEmpty) throw ProfileQuiescenceException(failures);
      await rollBack();
      await _bootstrap();
    } catch (e, st) {
      throw ProfileRestartException(e, st);
    }
  }

  /// Default teardown: quiesce, dispose the service generation, reset getIt.
  /// Returns every step that failed; each has also been logged.
  Future<List<ServiceDisposalFailure>> _defaultTeardown() async {
    final failures = <ServiceDisposalFailure>[];
    await _quiesce(failures);
    await _teardownGeneration(failures);
    return failures;
  }

  /// Runs one teardown step, logging and recording a failure instead of
  /// letting it stop the rest of the teardown.
  Future<void> _step(
    List<ServiceDisposalFailure> failures,
    String name,
    Future<void> Function() step,
  ) async {
    try {
      await step();
    } catch (e, st) {
      _logError(e, st, name);
      failures.add(
        ServiceDisposalFailure(service: name, error: e, stackTrace: st),
      );
    }
  }

  /// Stops runtime activity that persists state, while the old generation's
  /// services are still alive to receive the writes.
  Future<void> _quiesce(List<ServiceDisposalFailure> failures) async {
    // Fire-and-forget startup work (MatrixService.init, sequence-log
    // migration) must not still be running when its services are disposed.
    if (getIt.isRegistered<StartupTasks>()) {
      await _step(
        failures,
        'StartupTasks.settle',
        () => getIt<StartupTasks>().settle(),
      );
    }
    if (getIt.isRegistered<TimeService>()) {
      await _step(
        failures,
        'TimeService.stop',
        () => getIt<TimeService>().stop(),
      );
    }
    await _step(
      failures,
      'AudioPlayerController.disposeActivePlayer',
      AudioPlayerController.disposeActivePlayer,
    );
    lifecycleHolder.dispose();
    if (getIt.isRegistered<WindowService>()) {
      await _step(
        failures,
        'WindowService.detachForRestart',
        () => getIt<WindowService>().detachForRestart(),
      );
    }
  }

  Future<void> _teardownGeneration(
    List<ServiceDisposalFailure> failures,
  ) async {
    failures.addAll(await ServiceDisposer(getIt, _logError).disposeAll());

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
    // so there is no double-close. A failure here propagates rather than
    // being recorded: bootstrapping onto a half-reset container is never safe.
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
