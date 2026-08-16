import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/workflow/prompt_log_wrap.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    hide aiConfigRepositoryProvider;
import 'package:lotti/features/daily_os_next/agents/prompt/day_prompt_log_wraps.dart';
import 'package:lotti/features/daily_os_next/agents/state/daily_os_runtime_maintenance.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_workflow_providers.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_inference_setup_sheet.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/demo_media_startup.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/main.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:lotti/widgets/media/image_viewer_orientation_scope.dart';
import 'package:media_kit/media_kit.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:window_manager/window_manager.dart';

/// The bootstrap is split along the profile-switch boundary:
///
/// - [registerProcessLogging] and [initPlatformOnce] run exactly once per
///   process. They own state that must survive a profile switch (log sinks
///   flush per-write against the active root; native inits are not
///   re-runnable).
/// - [resolveActiveProfile] and [bootstrapProfileServices] run once per
///   service generation: on cold boot and again after every profile switch,
///   re-pointing the entire documents/database layer at the active world.

/// Registers the process-lifetime logging pair. LoggingService resolves its
/// log directory per write via the registered `Directory`, so a single
/// instance follows the active profile across switches.
void registerProcessLogging() {
  final loggingService = LoggingService();
  getIt
    ..registerSingleton<LoggingService>(
      loggingService,
      dispose: (service) => service.dispose(),
    )
    ..registerSingleton<DomainLogger>(
      DomainLogger(loggingService: loggingService),
    );
}

/// One-time, process-global platform initialization. Never re-run on a
/// profile switch. Excluded from coverage: every line is a native platform
/// call (window manager, MediaKit, orientation, vodozemac) that cannot run
/// under flutter test.
// coverage:ignore-start
Future<void> initPlatformOnce() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Platform startup call; controller behavior is covered by focused tests.
  await appOrientationController.lockToPortrait();
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

  tz.initializeTimeZones();
  // Loading the database does not pick a zone — without this the package's
  // `local` stays UTC and scheduled reminders land hours off.
  await configureLocalTimezone(
    onError: handleTimezoneConfigurationError,
  );

  // Process-global crypto init for the vodozemac bindings; required before
  // any Matrix stack is constructed, harmless when none ever is.
  await vod.init();
}
// coverage:ignore-end

/// What [resolveActiveProfile] found: the OS-derived real root and the
/// registry's view of which world should be running.
class ProfileBootInfo {
  const ProfileBootInfo({
    required this.realRoot,
    required this.registry,
    required this.active,
    required this.activeRoot,
  });

  final Directory realRoot;
  final ProfileRegistry registry;
  final Profile active;
  final Directory activeRoot;
}

/// Reads the registry at the OS documents root and resolves the active
/// profile. Pure read — a missing or corrupt registry resolves to the real
/// world.
Future<ProfileBootInfo> resolveActiveProfile() async {
  final realRoot = await findDocumentsDirectory();
  final registry = ProfileRegistry(
    realRoot: realRoot,
    logging: getIt.isRegistered<DomainLogger>() ? getIt<DomainLogger>() : null,
  );
  final state = await registry.load();
  final active = state.activeProfile;
  return ProfileBootInfo(
    realRoot: realRoot,
    registry: registry,
    active: active,
    activeRoot: registry.rootFor(active),
  );
}

/// Owns the app-exit listener across generations. The listener is created
/// after each bootstrap and disposed during window teardown (via the
/// WindowService beforeLogFlush hook) or a profile switch.
class AppLifecycleHolder {
  AppLifecycleListener? listener;

  void dispose() {
    listener?.dispose();
    listener = null;
  }
}

/// Per-generation service bootstrap: registers the world-scoped singletons
/// for the active profile and runs the full [registerSingletons] sequence
/// against its root. Runs on cold boot and after every profile switch;
/// expects getIt to contain only the process-lifetime registrations.
Future<ProfileContext> bootstrapProfileServices(
  ProfileBootInfo info, {
  required AppLifecycleHolder lifecycleHolder,
  bool restoreWindow = true,
  bool registerLateAndOptional = true,
}) async {
  // A dangling marker can point at a world whose directory was removed
  // externally; recreate the skeleton rather than failing boot.
  if (!info.activeRoot.existsSync()) {
    await info.activeRoot.create(recursive: true);
  }

  final context = ProfileContext.forProfile(
    profile: info.active,
    root: info.activeRoot,
  );

  getIt
    ..registerSingleton<SecureStorage>(SecureStorage())
    ..registerSingleton<ProfileContext>(context)
    ..registerSingleton<Directory>(info.activeRoot)
    ..registerSingleton<SettingsDb>(SettingsDb())
    ..registerSingleton<WindowService>(
      WindowService(
        beforeLogFlush: () async {
          lifecycleHolder.dispose();
          flushPendingFrameworkErrorSummaries();
        },
      ),
    );

  if (restoreWindow) {
    await getIt<WindowService>().restore();
  }

  await registerSingletons(
    profile: context,
    registerLateAndOptional: registerLateAndOptional,
  );
  await registerDemoMediaHydration(
    serviceLocator: getIt,
    profile: context,
    catalog: demoMediaAssets,
  );
  return context;
}

/// The getIt→Riverpod bridge overrides, recomputed for every service
/// generation so a rebuilt ProviderScope binds to the fresh singletons.
///
/// In guest worlds [matrixServiceProvider] is deliberately NOT overridden:
/// the Matrix stack is never constructed there, and an accidental resolution
/// should fail loudly (UnimplementedError) instead of silently no-opping —
/// every sync surface is expected to gate on [syncFeatureAvailableProvider].
///
/// This is also where the agent runtime learns about the agent *kinds* other
/// features own (`agentWakeRunnersProvider` and friends). `features/agents`
/// cannot import those features without recreating the dependency cycle
/// between them, so the composition root — the one place allowed to see both
/// sides — supplies them. A kind whose override is missing here is simply
/// absent at runtime: its wakes fall through to the task-agent default and its
/// prompt records reconstruct unsectioned, so
/// `test/app_bootstrap_test.dart` pins these registrations.
List<Override> buildProviderOverrides(ProfileContext context) {
  return [
    profileContextProvider.overrideWithValue(context),
    if (context.capabilities.syncEnabled)
      matrixServiceProvider.overrideWithValue(getIt<MatrixService>()),
    maintenanceProvider.overrideWithValue(getIt<Maintenance>()),
    journalDbProvider.overrideWithValue(getIt<JournalDb>()),
    syncDatabaseProvider.overrideWithValue(getIt<SyncDatabase>()),
    loggingServiceProvider.overrideWithValue(getIt<LoggingService>()),
    outboxServiceProvider.overrideWithValue(getIt<OutboxService>()),
    aiConfigRepositoryProvider.overrideWithValue(getIt<AiConfigRepository>()),
    // Daily OS and Goals plug their agent kinds into the shared runtime.
    // These are MERGES, not replacements: a kind missing from the map
    // silently falls back to the task-agent workflow.
    agentWakeRunnersProvider.overrideWith(
      (ref) => {
        ...ref.watch(dayAgentWakeRunnersProvider),
        ...ref.watch(goalAgentWakeRunnersProvider),
        ...ref.watch(relationshipAgentWakeRunnersProvider),
      },
    ),
    agentRuntimeMaintenanceProvider.overrideWith(
      (ref) => [
        ...ref.watch(dailyOsRuntimeMaintenanceProvider),
        ref.watch(goalRuntimeMaintenanceProvider),
        ref.watch(relationshipRuntimeMaintenanceProvider),
      ],
    ),
    // The banner dock renders every kind through one substrate; each kind
    // registers its active-banner source here (ADR 0059 Decision 6). A
    // source missing from this list simply never speaks.
    nudgeBannerSourcesProvider.overrideWithValue(
      [activeGoalNudgesProvider],
    ),
    promptLogWrapRenderersProvider.overrideWithValue(
      dayPromptLogWrapRenderers,
    ),
    dailyOsSetupSheetLauncherProvider.overrideWithValue(
      DailyOsInferenceSetupSheet.show,
    ),
  ];
}
