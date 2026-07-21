/// Harness for tutorial-video driver tests.
///
/// This is NOT a CI verification suite: it drives the real Linux desktop app
/// at human pace while the host workbench (`tools/tutorial_videos`) records
/// the screen. It boots the production `MyBeamerApp` shell on a real getIt
/// graph with in-memory databases and a temp documents directory (forked from
/// the legacy full-shell screenshot harness), seeds the Intergalactic Penguin
/// Logistics demo world through real repositories, and coordinates with the
/// host via three contracts:
///
///  * `LOTTI_TUTORIAL_MANIFEST` — the TTS durations manifest (JSON) produced
///    by `python3 -m tutorial_videos tts`; narration lengths become per-step
///    minimum durations so the voice-over never outruns the video.
///  * `LOTTI_TUTORIAL_TIMELINE` — output path for `timeline.json` with the
///    actual wall-clock step boundaries the compositor aligns clips to.
///  * `LOTTI_TUTORIAL_MIC_SINK` — the PulseAudio null sink acting as the
///    virtual microphone; dictation clips are `paplay`ed into it while the
///    app's real recorder captures the default source (the sink's monitor).
///
/// Wall-clock pacing (`Stopwatch` + live `tester.pump`) is intentional here —
/// this harness produces video, not test timing guarantees — and is exempt
/// from the fake-time policy in `test/README.md`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    hide aiConfigRepositoryProvider;
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_repository.dart';
import 'package:lotti/features/theming/model/theme_definitions.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/providers/service_providers.dart'
    show
        aiConfigRepositoryProvider,
        journalDbProvider,
        loggingServiceProvider,
        maintenanceProvider,
        matrixServiceProvider,
        outboxServiceProvider,
        syncDatabaseProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../../test/helpers/fallbacks.dart';
import '../../test/helpers/manual_demo_world.dart';
import '../../test/mocks/mocks.dart';

/// One narration/dictation clip from the TTS manifest.
class TutorialClip {
  TutorialClip({required this.path, required this.duration});

  final String path;
  final Duration duration;
}

/// Per-step pacing input parsed from `LOTTI_TUTORIAL_MANIFEST`.
class TutorialStepPlan {
  TutorialStepPlan({
    required this.id,
    required this.minDuration,
    required this.narration,
    this.dictation,
  });

  final String id;
  final Duration minDuration;
  final TutorialClip narration;
  final TutorialClip? dictation;
}

class TutorialManifest {
  TutorialManifest({
    required this.scenario,
    required this.locale,
    required this.dictionary,
    required this.steps,
  });

  factory TutorialManifest.fromEnvironment() {
    final path = Platform.environment['LOTTI_TUTORIAL_MANIFEST'];
    if (path == null || path.isEmpty) {
      throw StateError(
        'LOTTI_TUTORIAL_MANIFEST is not set — run the TTS pre-pass first '
        '(python3 -m tutorial_videos tts).',
      );
    }
    final raw = jsonDecode(File(path).readAsStringSync());
    if (raw is! Map<String, dynamic>) {
      throw StateError('$path: manifest is not a JSON object');
    }
    Duration secondsToDuration(num seconds) =>
        Duration(milliseconds: (seconds * 1000).round());
    TutorialClip clip(Map<String, dynamic> json) => TutorialClip(
      path: json['clip'] as String,
      duration: secondsToDuration(json['duration'] as num),
    );
    return TutorialManifest(
      scenario: raw['scenario'] as String,
      locale: raw['locale'] as String,
      dictionary: (raw['dictionary'] as List<dynamic>).cast<String>(),
      steps: [
        for (final step
            in (raw['steps'] as List<dynamic>).cast<Map<String, dynamic>>())
          TutorialStepPlan(
            id: step['id'] as String,
            minDuration: secondsToDuration(step['min_duration'] as num),
            narration: clip(step['narration'] as Map<String, dynamic>),
            dictation: step['dictation'] == null
                ? null
                : clip(step['dictation'] as Map<String, dynamic>),
          ),
      ],
    );
  }

  final String scenario;
  final String locale;
  final List<String> dictionary;
  final List<TutorialStepPlan> steps;

  TutorialStepPlan step(String id) => steps.firstWhere((step) => step.id == id);
}

/// Records actual wall-clock step boundaries and writes `timeline.json`.
class TutorialTimeline {
  TutorialTimeline()
    : _clock = Stopwatch()..start(),
      _zeroEpochMs = DateTime.now().millisecondsSinceEpoch;

  final Stopwatch _clock;

  /// Absolute epoch of timeline zero — the compositor subtracts the host's
  /// capture-start epoch from this to trim the recording head (app build/boot
  /// happens before the tutorial flow starts).
  final int _zeroEpochMs;
  final List<Map<String, Object>> _entries = [];

  /// Spans where the flow was only waiting on external work (cloud
  /// transcription / agent roundtrips). The compositor time-warps these:
  /// footage speeds up while narration keeps playing at normal speed.
  final List<Map<String, Object>> _waits = [];

  /// Spans where the dictation clip played into the virtual microphone —
  /// the compositor mixes the same clip into the final audio here, so the
  /// narrator is audibly "speaking into Lotti" on camera.
  final List<Map<String, Object>> _dictations = [];

  Duration get elapsed => _clock.elapsed;

  void addWait({required Duration start, required Duration end}) {
    _waits.add({
      'start': start.inMilliseconds / 1000,
      'end': end.inMilliseconds / 1000,
    });
  }

  void addDictation({required Duration start, required Duration end}) {
    _dictations.add({
      'start': start.inMilliseconds / 1000,
      'end': end.inMilliseconds / 1000,
    });
  }

  void addStep({
    required String id,
    required Duration start,
    required Duration end,
  }) {
    _entries.add({
      'id': id,
      'start': start.inMilliseconds / 1000,
      'end': end.inMilliseconds / 1000,
    });
  }

  void write() {
    final path = Platform.environment['LOTTI_TUTORIAL_TIMELINE'];
    if (path == null || path.isEmpty) return;
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'total': elapsed.inMilliseconds / 1000,
          'zero_epoch_ms': _zeroEpochMs,
          'steps': _entries,
          'waits': _waits,
          'dictations': _dictations,
        }),
      );
  }
}

/// Animated on-screen cursor for the recording.
///
/// Synthetic `tester.tap` calls never move the real X pointer, so recordings
/// show controls activating themselves. This overlay draws its own pointer
/// (WidgetTester drives it via [TutorialDriver.tapLikeUser]) and the capture
/// hides the real cursor (`x11grab -draw_mouse 0`).
class TutorialCursorController {
  final ValueNotifier<Offset> position = ValueNotifier(const Offset(640, 500));
  final ValueNotifier<bool> pressed = ValueNotifier(false);
}

class TutorialCursorLayer extends StatelessWidget {
  const TutorialCursorLayer({
    required this.controller,
    required this.child,
    this.elapsed,
    super.key,
  });

  final TutorialCursorController controller;

  /// Real elapsed wall-clock time shown as a HUD chip. Because it displays
  /// REAL time, it visibly races during time-warped (fast-forwarded) wait
  /// footage — the honesty cue that the wait actually happened.
  final ValueListenable<Duration>? elapsed;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          if (elapsed != null)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ValueListenableBuilder<Duration>(
                  valueListenable: elapsed!,
                  builder: (context, value, _) {
                    final minutes = value.inMinutes;
                    final seconds = value.inSeconds % 60;
                    return Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xE60B120E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0x882EE6A8),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 20,
                                color: Color(0xFF2EE6A8),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$minutes:${seconds.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: Color(0xFFDFFCEF),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ValueListenableBuilder<Offset>(
            valueListenable: controller.position,
            builder: (context, position, _) => ValueListenableBuilder<bool>(
              valueListenable: controller.pressed,
              builder: (context, pressed, _) => Positioned(
                left: position.dx - 6,
                top: position.dy - 4,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: const Size(24, 28),
                    painter: _CursorPainter(pressed: pressed),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  _CursorPainter({required this.pressed});

  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    if (pressed) {
      canvas.drawCircle(
        const Offset(6, 4),
        16,
        Paint()..color = const Color(0x552EE6A8),
      );
    }
    final arrow = Path()
      ..moveTo(0, 0)
      ..lineTo(0, 20)
      ..lineTo(4.6, 15.4)
      ..lineTo(7.8, 22.6)
      ..lineTo(11.2, 21.1)
      ..lineTo(8, 14)
      ..lineTo(14, 14)
      ..close();
    canvas
      ..drawPath(
        arrow,
        Paint()
          ..color = const Color(0xFF1A1A1A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawPath(arrow, Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) =>
      oldDelegate.pressed != pressed;
}

/// Real-service in-memory app harness (fork of the legacy full-shell
/// screenshot harness, minus the recorder stub: the tutorial exercises the
/// REAL audio recorder against the virtual microphone).
class TutorialAppHarness {
  TutorialAppHarness._({
    required this.aiConfigRepository,
    required this.documentsDirectory,
    required this.entitiesCacheService,
    required this.journalDb,
    required this.navService,
    required this.persistenceLogic,
    required this.userActivityService,
    required this.world,
    required List<Object> closeables,
  }) : _closeables = closeables; // ignore: prefer_initializing_formals

  final AiConfigRepository aiConfigRepository;
  final Directory documentsDirectory;
  final EntitiesCacheService entitiesCacheService;
  final JournalDb journalDb;
  final NavService navService;
  final PersistenceLogic persistenceLogic;
  final UserActivityService userActivityService;
  final ManualDemoWorld world;
  final List<Object> _closeables;

  static Future<TutorialAppHarness> setUp({
    required List<AiConfig> aiConfigs,
    required String languageCode,
    CategoryDefinition Function(CategoryDefinition category)? categoryTransform,
  }) async {
    await getIt.reset();

    final documentsDirectory = await Directory.systemTemp.createTemp(
      'lotti-tutorial-video-',
    );

    final loggingService = LoggingService();
    final settingsDb = SettingsDb(inMemoryDatabase: true);
    final journalDb = JournalDb(
      inMemoryDatabase: true,
      background: false,
      readPool: 0,
      loggingService: DomainLogger(loggingService: loggingService),
      documentsDirectory: documentsDirectory,
    );
    final fts5Db = Fts5Db(inMemoryDatabase: true);
    final editorDb = EditorDb(inMemoryDatabase: true);
    final syncDatabase = SyncDatabase(inMemoryDatabase: true);
    final agentDatabase = AgentDatabase(
      inMemoryDatabase: true,
      background: false,
      readPool: 0,
    );
    final updateNotifications = UpdateNotifications();
    final userActivityService = UserActivityService();
    final aiConfigRepository = AiConfigRepository(
      AiConfigDb(inMemoryDatabase: true),
    );
    final matrixService = _matrixServiceMock();
    final outboxService = _outboxServiceMock();

    await Future.wait([
      settingsDb.saveSettingsItem(themeModeKey, ThemeMode.dark.name),
      settingsDb.saveSettingsItem(darkSchemeNameKey, defaultThemeName),
      settingsDb.saveSettingsItem(lightSchemeNameKey, defaultThemeName),
      // The app shell resolves its UI language from this settings override
      // (ManualLanguageController) — platformDispatcher test locales are not
      // enough for the real desktop shell.
      settingsDb.saveSettingsItem(manualLanguageSettingsKey, languageCode),
      // No pane-width override: the app's own defaults (see
      // pane_width_controller.dart) are the balanced layout its designers
      // already tuned for a 1920px canvas. Earlier custom overrides here
      // (progressively narrower sidebar/list) were an over-correction that
      // left a large empty gutter beside the detail pane's content instead.
    ]);

    getIt
      ..registerSingleton<Directory>(documentsDirectory)
      ..registerSingleton<LoggingService>(loggingService)
      ..registerSingleton<SettingsDb>(settingsDb)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<Fts5Db>(fts5Db)
      ..registerSingleton<EditorDb>(editorDb)
      ..registerSingleton<SyncDatabase>(syncDatabase)
      ..registerSingleton<AgentDatabase>(agentDatabase)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<UserActivityService>(userActivityService)
      ..registerSingleton<SyncActivitySignaler>(SyncActivitySignaler())
      ..registerSingleton<SecureStorage>(MockSecureStorage())
      ..registerSingleton<MatrixService>(matrixService)
      ..registerSingleton<OutboxService>(outboxService)
      ..registerSingleton<AiConfigRepository>(aiConfigRepository)
      // Daily OS's audio-capture processing pipeline resolves this via
      // getIt directly (day_processing_runtime_provider.dart) rather than a
      // Riverpod override — MyBeamerApp fails to build at all without it,
      // even for scenarios that never touch Daily OS.
      ..registerSingleton<DayProcessingOutboxRepository>(
        DayProcessingOutboxRepository(
          rootDirectory: Directory(
            path.join(documentsDirectory.path, '.day_processing_outbox'),
          ),
        ),
      )
      ..registerSingleton<SavedTaskFiltersRepository>(
        SavedTaskFiltersRepository(
          SavedTaskFiltersPersistence(settingsDb),
          updateNotifications,
        ),
      );

    await initConfigFlags(journalDb, inMemoryDatabase: true);

    final vectorClockService = VectorClockService();
    getIt.registerSingleton<VectorClockService>(vectorClockService);
    await vectorClockService.initialized;

    final metadataService = MetadataService(
      vectorClockService: vectorClockService,
    );
    final geolocationService = GeolocationService(
      journalDb: journalDb,
      loggingService: DomainLogger(loggingService: loggingService),
      metadataService: metadataService,
    );

    getIt
      ..registerSingleton<DomainLogger>(
        DomainLogger(loggingService: loggingService),
      )
      ..registerSingleton<MetadataService>(metadataService)
      ..registerSingleton<GeolocationService>(geolocationService)
      ..registerSingleton<PersistenceLogic>(PersistenceLogic())
      ..registerSingleton<EditorStateService>(EditorStateService())
      ..registerSingleton<LinkService>(LinkService())
      // Every createDbEntity call ends with an updateBadge() call; without
      // this registration it throws (caught, but the caller sees `null`
      // back where a real entity was expected — createAiResponseEntryImpl's
      // "Failed to persist" is this exact swallowed failure). Safe as a
      // plain instance: updateBadge() no-ops on Linux/Windows.
      ..registerSingleton<NotificationService>(NotificationService());

    final persistenceLogic = getIt<PersistenceLogic>();
    final world = ManualDemoWorld.penguinLogistics();
    final category = categoryTransform == null
        ? world.category
        : categoryTransform(world.category);
    await _seedWorld(
      world,
      category,
      persistenceLogic,
      documentsDirectory,
    );
    for (final config in aiConfigs) {
      await aiConfigRepository.saveConfig(config, fromSync: true);
    }

    // Cache init AFTER seeding so the penguin category is in the cache.
    final entitiesCacheService = EntitiesCacheService(
      journalDb: journalDb,
      updateNotifications: updateNotifications,
    );
    await entitiesCacheService.init();
    getIt.registerSingleton<EntitiesCacheService>(entitiesCacheService);

    final maintenance = Maintenance();
    final navService = NavService(journalDb: journalDb, settingsDb: settingsDb);
    getIt
      ..registerSingleton<Maintenance>(maintenance)
      ..registerSingleton<NavService>(navService)
      ..registerSingleton<TimeService>(TimeService());

    return TutorialAppHarness._(
      aiConfigRepository: aiConfigRepository,
      documentsDirectory: documentsDirectory,
      entitiesCacheService: entitiesCacheService,
      journalDb: journalDb,
      navService: navService,
      persistenceLogic: persistenceLogic,
      userActivityService: userActivityService,
      world: world,
      closeables: [
        agentDatabase,
        editorDb,
        fts5Db,
        journalDb,
        settingsDb,
        syncDatabase,
        loggingService,
        aiConfigRepository,
        navService,
        entitiesCacheService,
      ],
    );
  }

  static Future<void> _seedWorld(
    ManualDemoWorld world,
    CategoryDefinition category,
    PersistenceLogic persistenceLogic,
    Directory documentsDirectory,
  ) async {
    await persistenceLogic.upsertEntityDefinition(category);
    for (final label in world.labels) {
      await persistenceLogic.upsertEntityDefinition(label);
    }
    await world.installMedia(documentsDirectory);
    for (final image in world.coverImages) {
      await persistenceLogic.createDbEntity(
        image,
        shouldAddGeolocation: false,
        enqueueSync: false,
      );
    }
    for (final task in world.tasks) {
      await persistenceLogic.createDbEntity(
        task,
        shouldAddGeolocation: false,
        enqueueSync: false,
      );
    }
  }

  List<Override> providerOverrides() => [
    // agentInitializationProvider is intentionally NOT overridden: the real
    // agent runtime (templates, wake orchestrator, subscriptions) must run
    // so the task agent proposes a title + checklist after transcription.
    aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
    journalDbProvider.overrideWithValue(journalDb),
    loggingServiceProvider.overrideWithValue(getIt<LoggingService>()),
    loginStateStreamProvider.overrideWith(
      (ref) => Stream<LoginState>.value(LoginState.loggedIn),
    ),
    maintenanceProvider.overrideWithValue(getIt<Maintenance>()),
    matrixServiceProvider.overrideWithValue(
      getIt<MatrixService>() as MockMatrixService,
    ),
    outboxServiceProvider.overrideWithValue(
      getIt<OutboxService>() as MockOutboxService,
    ),
    shouldAutoShowOnboardingProvider.overrideWith((ref) async => false),
    shouldAutoShowWhatsNewProvider.overrideWith((ref) async => false),
    syncDatabaseProvider.overrideWithValue(getIt<SyncDatabase>()),
  ];

  Future<void> dispose() async {
    for (final closeable in _closeables) {
      try {
        switch (closeable) {
          case final NavService service:
            await service.dispose();
          case final EntitiesCacheService service:
            service.dispose();
          case final AiConfigRepository repository:
            await repository.close();
          case final LoggingService service:
            await service.dispose();
          case final JournalDb db:
            await db.close();
          case final SettingsDb db:
            await db.close();
          case final Fts5Db db:
            await db.close();
          case final EditorDb db:
            await db.close();
          case final SyncDatabase db:
            await db.close();
          case final AgentDatabase db:
            await db.close();
        }
      } on Object {
        // Best effort: teardown must not mask the test result.
      }
    }
    await getIt.reset();
    try {
      await documentsDirectory.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  }

  static MockMatrixService _matrixServiceMock() {
    final matrixService = MockMatrixService();
    final client = MockMatrixClient();
    when(
      matrixService.getIncomingKeyVerificationStream,
    ).thenAnswer((_) => const Stream<KeyVerification>.empty());
    when(
      () => matrixService.incomingKeyVerificationRunnerStream,
    ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());
    when(() => matrixService.client).thenReturn(client);
    return matrixService;
  }

  static MockOutboxService _outboxServiceMock() {
    final outboxService = MockOutboxService();
    registerFallbackValue(fallbackSyncMessage);
    when(
      () => outboxService.notLoggedInGateStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(
      () => outboxService.enqueueMessage(any()),
    ).thenAnswer((_) async {});
    return outboxService;
  }
}

/// Paces steps against the manifest and records the timeline.
class TutorialDriver {
  TutorialDriver({
    required this.tester,
    required this.manifest,
    required this.cursor,
    this.hud,
  }) : timeline = TutorialTimeline();

  static const _postNarrationPad = Duration(milliseconds: 600);

  final WidgetTester tester;
  final TutorialManifest manifest;
  final TutorialCursorController cursor;

  /// Elapsed-time HUD notifier (see [TutorialCursorLayer.elapsed]); updated
  /// on every [tick] so the on-screen clock tracks real wall time.
  final ValueNotifier<Duration>? hud;

  final TutorialTimeline timeline;

  /// Renders one frame and refreshes the HUD clock. All driver-internal
  /// waiting goes through this so the recording stays smooth (~60 fps) and
  /// the clock never stalls.
  Future<void> tick() async {
    hud?.value = timeline.elapsed;
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// Glides the overlay cursor to [finder]'s center, pulses a press, and
  /// performs the actual (synthetic) tap.
  Future<void> tapLikeUser(Finder finder) async {
    final target = tester.getCenter(finder.first);
    final start = cursor.position.value;
    const steps = 22;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final eased = Curves.easeInOut.transform(t);
      cursor.position.value = Offset.lerp(start, target, eased)!;
      await tick();
    }
    await tester.pump(const Duration(milliseconds: 150));
    cursor.pressed.value = true;
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(finder.first, warnIfMissed: false);
    cursor.pressed.value = false;
    await tester.pump(const Duration(milliseconds: 120));
  }

  TutorialStepPlan? _activePlan;
  Duration _activeStepStart = Duration.zero;

  /// Holds until the active step's narration has finished (plus a beat) —
  /// used before the dictation so the narrator never talks over themselves.
  Future<void> waitForNarration() async {
    final plan = _activePlan;
    if (plan == null) return;
    await holdUntil(
      _activeStepStart +
          plan.narration.duration +
          const Duration(milliseconds: 400),
    );
  }

  /// Runs [action], then holds the step until both the scenario's
  /// min_duration and the narration clip length (plus a short pad) have
  /// elapsed since the step started.
  Future<void> step(String id, Future<void> Function() action) async {
    final plan = manifest.step(id);
    final start = timeline.elapsed;
    _activePlan = plan;
    _activeStepStart = start;
    await action();
    final floor = _longer(
      plan.minDuration,
      plan.narration.duration + _postNarrationPad,
    );
    await holdUntil(start + floor);
    timeline.addStep(id: id, start: start, end: timeline.elapsed);
  }

  /// Live-pumps frames until the harness wall clock reaches [deadline].
  ///
  /// 16 ms cadence: the capture records real frames, so page/modal
  /// animations must be pumped at display rate — sparse pumping renders
  /// them at ~10 fps, which reads as mushy cross-fades on video.
  Future<void> holdUntil(Duration deadline) async {
    while (timeline.elapsed < deadline) {
      await tick();
    }
  }

  /// Plays [clip] into the virtual microphone sink and waits for playback to
  /// finish (plus a trailing beat so the recorder captures natural silence).
  Future<void> speakIntoMic(TutorialClip clip) async {
    final sink = Platform.environment['LOTTI_TUTORIAL_MIC_SINK'];
    if (sink == null || sink.isEmpty) {
      throw StateError(
        'LOTTI_TUTORIAL_MIC_SINK is not set — the host must create the '
        'virtual microphone before launching the app.',
      );
    }
    final start = timeline.elapsed;
    final playback = Process.run('paplay', ['--device=$sink', clip.path]);
    await holdUntil(
      timeline.elapsed + clip.duration + const Duration(milliseconds: 400),
    );
    // Recorded so the compositor mixes the same clip into the final audio —
    // the narrator audibly speaks into Lotti at exactly this moment.
    timeline.addDictation(start: start, end: timeline.elapsed);
    final result = await playback;
    if (result.exitCode != 0) {
      throw StateError('paplay failed: ${result.stderr}');
    }
  }

  /// Optional callback returning extra context appended to timeout failures.
  String Function()? diagnostics;

  /// Optional async hook invoked (with a short context tag) before a timeout
  /// failure is thrown — used to capture an on-failure screenshot.
  Future<void> Function(String context)? onTimeout;

  Future<Never> _failWithContext(String context, String message) async {
    try {
      await onTimeout?.call(context);
    } on Object {
      // Screenshot capture is best effort.
    }
    final extra = diagnostics?.call();
    fail('$message${extra == null ? '' : '\nDiagnostics:\n$extra'}');
  }

  /// Live-pumps until [finder] matches, failing after [timeout].
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = timeline.elapsed + timeout;
    while (finder.evaluate().isEmpty) {
      if (timeline.elapsed > deadline) {
        await _failWithContext(
          'pump_until_found',
          'Timed out waiting for $finder',
        );
      }
      await tick();
    }
  }

  /// Scrolls [scrollable] so [target] sits at [alignment] within the
  /// viewport (0.0 = flush with the leading/top edge, 0.5 = centered, 1.0 =
  /// flush with the trailing/bottom edge) — computed directly from the
  /// widget's own geometry via [Scrollable.ensureVisible] and animated
  /// there smoothly.
  ///
  /// Deliberately NOT "sweep toward a page edge and stop at the first
  /// `hitTestable` frame": a widget sitting a single pixel over the fold
  /// already satisfies `hitTestable`, which reads as "not actually shown"
  /// on camera, and sweeping to `maxScrollExtent`/`minScrollExtent`
  /// overshoots the moment any more content exists past the target.
  /// [Scrollable.ensureVisible] also walks outward through nested
  /// scrollables correctly (e.g. a checklist's own reorderable list inside
  /// the page's outer pane) instead of guessing which one is "the" page
  /// scrollable.
  ///
  /// [target] must already be built somewhere in the tree. A virtualized
  /// list only builds rows near the current scroll offset, so when
  /// [target] isn't there yet this first does a coarse sweep — checking
  /// bare existence, not `hitTestable` — using the matching [scrollable]
  /// with the most actual scroll range (`maxScrollExtent -
  /// minScrollExtent`), then hands off to [Scrollable.ensureVisible] for
  /// the exact, animated placement.
  ///
  /// Deliberately NOT "the largest `viewportDimension`": a shrink-wrapped,
  /// `NeverScrollableScrollPhysics` inner list (e.g. a checklist's own
  /// `ReorderableListView`, embedded in — not competing with — the page's
  /// real scrollable) sizes itself to its full content height, which can
  /// exceed the outer pane's visible viewport height while having ZERO
  /// scroll range of its own — driving it is a silent no-op that never
  /// reaches a target sitting further down the actual page.
  Future<void> scrollIntoView(
    Finder target, {
    required Finder scrollable,
    double alignment = 0.5,
    double step = 250,
    Duration animation = const Duration(milliseconds: 900),
  }) async {
    // The coarse "get it built" sweep below is only needed when [target]
    // isn't in the tree yet (a virtualized list far off-screen) — a page
    // that already fits entirely within the viewport has no scrollable
    // with actual range at all, which is fine as long as there's nothing
    // to build: don't demand one just to hand off to
    // [Scrollable.ensureVisible], which needs no scroll position of its
    // own.
    if (target.evaluate().isEmpty) {
      // NOTE: [scrollable] must be a plain (non-`.first`) finder — `.first`
      // finders throw on evaluate() when empty instead of returning [].
      if (scrollable.evaluate().isEmpty) {
        await _failWithContext(
          'scroll_no_scrollable',
          'No scrollable found while scrolling to $target',
        );
      }
      ScrollableState? best;
      for (final element in scrollable.evaluate()) {
        final state = (element as StatefulElement).state as ScrollableState;
        if (!state.position.hasViewportDimension) continue;
        final range =
            state.position.maxScrollExtent - state.position.minScrollExtent;
        if (range <= 0) continue;
        final bestRange = best == null
            ? 0.0
            : best.position.maxScrollExtent - best.position.minScrollExtent;
        if (best == null || range > bestRange) {
          best = state;
        }
      }
      if (best == null) {
        await _failWithContext(
          'scroll_no_scrollable',
          'No scrollable with actual scroll range found while scrolling to '
              '$target',
        );
      }
      final position = best.position;

      Future<bool> sweepUntilBuilt(double destination) async {
        final direction = destination >= position.pixels ? 1 : -1;
        while ((destination - position.pixels) * direction > 1) {
          if (target.evaluate().isNotEmpty) return true;
          position.jumpTo(
            (position.pixels + step * direction).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
          for (var frame = 0; frame < 8; frame++) {
            await tick();
          }
        }
        return target.evaluate().isNotEmpty;
      }

      if (!await sweepUntilBuilt(position.maxScrollExtent) &&
          !await sweepUntilBuilt(position.minScrollExtent)) {
        await _failWithContext(
          'scroll_exhausted',
          'Could not scroll $target into the tree',
        );
      }
    }

    final settle = Scrollable.ensureVisible(
      target.evaluate().first,
      alignment: alignment,
      duration: animation,
      curve: Curves.easeInOut,
    );
    final deadline =
        timeline.elapsed + animation + const Duration(milliseconds: 200);
    while (timeline.elapsed < deadline) {
      await tick();
    }
    await settle;
  }

  /// Live-pumps until [condition] returns true, failing after [timeout].
  ///
  /// Waits longer than [_waitSpanThreshold] are recorded in the timeline so
  /// the compositor can time-warp them (footage fast-forwards while the
  /// narration keeps playing at normal speed).
  Future<void> pumpUntil(
    FutureOr<bool> Function() condition, {
    required String description,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final start = timeline.elapsed;
    final deadline = start + timeout;
    while (!await condition()) {
      if (timeline.elapsed > deadline) {
        await _failWithContext(
          'pump_until',
          'Timed out waiting for $description',
        );
      }
      await tick();
    }
    final end = timeline.elapsed;
    if (end - start > _waitSpanThreshold) {
      timeline.addWait(start: start, end: end);
    }
  }

  static const _waitSpanThreshold = Duration(seconds: 3);

  static Duration _longer(Duration a, Duration b) => a > b ? a : b;
}
