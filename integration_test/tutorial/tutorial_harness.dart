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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show AiConfigRepository, aiConfigRepositoryProvider;
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/features/theming/model/theme_definitions.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/geolocation_service.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/providers/service_providers.dart'
    show
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
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

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

  Duration get elapsed => _clock.elapsed;

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
        }),
      );
  }
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
      ..registerSingleton<AiConfigRepository>(aiConfigRepository);

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
      ..registerSingleton<LinkService>(LinkService());

    final persistenceLogic = getIt<PersistenceLogic>();
    final world = ManualDemoWorld.penguinLogistics();
    await _seedWorld(world, persistenceLogic, documentsDirectory);
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
    PersistenceLogic persistenceLogic,
    Directory documentsDirectory,
  ) async {
    await persistenceLogic.upsertEntityDefinition(world.category);
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
    agentInitializationProvider.overrideWith((ref) async {}),
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
  }) : timeline = TutorialTimeline();

  static const _postNarrationPad = Duration(milliseconds: 600);

  final WidgetTester tester;
  final TutorialManifest manifest;
  final TutorialTimeline timeline;

  /// Runs [action], then holds the step until both the scenario's
  /// min_duration and the narration clip length (plus a short pad) have
  /// elapsed since the step started.
  Future<void> step(String id, Future<void> Function() action) async {
    final plan = manifest.step(id);
    final start = timeline.elapsed;
    await action();
    final floor = _longer(
      plan.minDuration,
      plan.narration.duration + _postNarrationPad,
    );
    await holdUntil(start + floor);
    timeline.addStep(id: id, start: start, end: timeline.elapsed);
  }

  /// Live-pumps frames until the harness wall clock reaches [deadline].
  Future<void> holdUntil(Duration deadline) async {
    while (timeline.elapsed < deadline) {
      await tester.pump(const Duration(milliseconds: 100));
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
    final playback = Process.run('paplay', ['--device=$sink', clip.path]);
    await holdUntil(
      timeline.elapsed + clip.duration + const Duration(milliseconds: 400),
    );
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
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scrolls [scrollable] until [target] is hit-testable.
  ///
  /// Works with virtualized lists (where off-screen rows are unmounted, so
  /// `scrollUntilVisible` cannot resolve the target widget): sweeps the
  /// viewport in steps, checking after each one.
  Future<void> scrollIntoView(
    Finder target, {
    required Finder scrollable,
    double step = 250,
    int maxSteps = 30,
  }) async {
    for (var i = 0; i < maxSteps; i++) {
      if (target.hitTestable().evaluate().isNotEmpty) return;
      // NOTE: [scrollable] must be a plain (non-`.first`) finder — `.first`
      // finders throw on evaluate() when empty instead of returning [].
      if (scrollable.evaluate().isEmpty) {
        await _failWithContext(
          'scroll_no_scrollable',
          'No scrollable found while scrolling to $target',
        );
      }
      await tester.drag(
        scrollable.first,
        Offset(0, -step),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
    await _failWithContext(
      'scroll_exhausted',
      'Could not scroll $target into view',
    );
  }

  /// Live-pumps until [condition] returns true, failing after [timeout].
  Future<void> pumpUntil(
    FutureOr<bool> Function() condition, {
    required String description,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final deadline = timeline.elapsed + timeout;
    while (!await condition()) {
      if (timeline.elapsed > deadline) {
        await _failWithContext(
          'pump_until',
          'Timed out waiting for $description',
        );
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  static Duration _longer(Duration a, Duration b) => a > b ? a : b;
}
