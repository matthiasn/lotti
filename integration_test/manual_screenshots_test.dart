import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
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
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show AiConfigRepository, aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/settings/inference_provider_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/settings/constants/theming_settings_keys.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
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

import '../test/mocks/mocks.dart';
import 'manual_screenshot_utils.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures AI provider onboarding states in the full app shell', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(3840, 2160)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final harness = await _setUpInMemoryFullAppHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      manualScreenshotBoundary(
        child: ProviderScope(
          overrides: _providerOverrides(harness),
          child: MyBeamerApp(
            navService: harness.navService,
            userActivityService: harness.userActivityService,
          ),
        ),
      ),
    );

    await tester.pump();
    harness.navService.beamToNamed('/settings/ai');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final addProviderFab = find.byKey(
      const ValueKey('ai-settings-fab-providers'),
    );
    await _pumpUntilFound(tester, addProviderFab);

    expect(find.text('AI Settings'), findsWidgets);
    expect(addProviderFab, findsOne);

    await captureManualScreenshot(
      binding: binding,
      tester: tester,
      name: 'ai_onboarding_00_full_app_ai_settings',
    );

    await tester.tap(addProviderFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Set up AI features'), findsOneWidget);
    expect(find.text('Google Gemini'), findsWidgets);

    await captureManualScreenshot(
      binding: binding,
      tester: tester,
      name: 'ai_onboarding_01_choose_provider_gemini_selected',
    );

    await tester.tap(find.text('Google Gemini').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await captureManualScreenshot(
      binding: binding,
      tester: tester,
      name: 'ai_onboarding_02_gemini_selected',
    );

    await tester.tap(find.text('Continue').last);
    await tester.pump();
    await _pumpUntilFound(tester, find.byType(InferenceProviderEditPage));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(InferenceProviderEditPage), findsOneWidget);
    expect(find.text('Connect Google Gemini'), findsOneWidget);

    await captureManualScreenshot(
      binding: binding,
      tester: tester,
      name: 'ai_onboarding_03_gemini_connect_provider',
    );
  });
}

class _InMemoryFullAppHarness {
  const _InMemoryFullAppHarness({
    required this.agentDatabase,
    required this.aiConfigRepository,
    required this.documentsDirectory,
    required this.editorDb,
    required this.entitiesCacheService,
    required this.fts5Db,
    required this.journalDb,
    required this.loggingService,
    required this.maintenance,
    required this.matrixService,
    required this.navService,
    required this.outboxService,
    required this.settingsDb,
    required this.syncDatabase,
    required this.userActivityService,
  });

  final AgentDatabase agentDatabase;
  final AiConfigRepository aiConfigRepository;
  final Directory documentsDirectory;
  final EditorDb editorDb;
  final EntitiesCacheService entitiesCacheService;
  final Fts5Db fts5Db;
  final JournalDb journalDb;
  final LoggingService loggingService;
  final Maintenance maintenance;
  final MockMatrixService matrixService;
  final NavService navService;
  final MockOutboxService outboxService;
  final SettingsDb settingsDb;
  final SyncDatabase syncDatabase;
  final UserActivityService userActivityService;

  Future<void> dispose() async {
    await navService.dispose();
    entitiesCacheService.dispose();
    await aiConfigRepository.close();
    await Future.wait<void>([
      agentDatabase.close(),
      editorDb.close(),
      fts5Db.close(),
      journalDb.close(),
      settingsDb.close(),
      syncDatabase.close(),
      loggingService.dispose(),
    ]);
    await getIt.reset();
    try {
      await documentsDirectory.delete(recursive: true);
    } on FileSystemException {
      // Directory already gone; nothing to clean up.
    }
  }
}

Future<_InMemoryFullAppHarness> _setUpInMemoryFullAppHarness() async {
  await getIt.reset();

  final documentsDirectory = await Directory.systemTemp.createTemp(
    'lotti-manual-screenshots-',
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
  final syncActivitySignaler = SyncActivitySignaler();
  final aiConfigRepository = AiConfigRepository(
    AiConfigDb(inMemoryDatabase: true),
  );
  final matrixService = _createMatrixServiceMock();
  final outboxService = _createOutboxServiceMock();

  await Future.wait([
    settingsDb.saveSettingsItem(themeModeKey, ThemeMode.dark.name),
    settingsDb.saveSettingsItem(darkSchemeNameKey, defaultThemeName),
    settingsDb.saveSettingsItem(lightSchemeNameKey, defaultThemeName),
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
    ..registerSingleton<SyncActivitySignaler>(syncActivitySignaler)
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
  final entitiesCacheService = EntitiesCacheService(
    journalDb: journalDb,
    updateNotifications: updateNotifications,
  );
  await entitiesCacheService.init();

  getIt
    ..registerSingleton<DomainLogger>(
      DomainLogger(loggingService: loggingService),
    )
    ..registerSingleton<MetadataService>(metadataService)
    ..registerSingleton<GeolocationService>(geolocationService)
    ..registerSingleton<EntitiesCacheService>(entitiesCacheService)
    ..registerSingleton<PersistenceLogic>(PersistenceLogic())
    ..registerSingleton<EditorStateService>(EditorStateService())
    ..registerSingleton<LinkService>(LinkService());

  final maintenance = Maintenance();
  final navService = NavService(journalDb: journalDb, settingsDb: settingsDb);
  getIt
    ..registerSingleton<Maintenance>(maintenance)
    ..registerSingleton<NavService>(navService)
    ..registerSingleton<TimeService>(TimeService());

  return _InMemoryFullAppHarness(
    agentDatabase: agentDatabase,
    aiConfigRepository: aiConfigRepository,
    documentsDirectory: documentsDirectory,
    editorDb: editorDb,
    entitiesCacheService: entitiesCacheService,
    fts5Db: fts5Db,
    journalDb: journalDb,
    loggingService: loggingService,
    maintenance: maintenance,
    matrixService: matrixService,
    navService: navService,
    outboxService: outboxService,
    settingsDb: settingsDb,
    syncDatabase: syncDatabase,
    userActivityService: userActivityService,
  );
}

MockMatrixService _createMatrixServiceMock() {
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

MockOutboxService _createOutboxServiceMock() {
  final outboxService = MockOutboxService();
  when(
    () => outboxService.notLoggedInGateStream,
  ).thenAnswer((_) => const Stream<void>.empty());
  return outboxService;
}

List<Override> _providerOverrides(_InMemoryFullAppHarness harness) {
  return [
    agentInitializationProvider.overrideWith((ref) async {}),
    aiConfigRepositoryProvider.overrideWithValue(harness.aiConfigRepository),
    aiSetupPromptServiceProvider.overrideWith(_ManualAiSetupPromptService.new),
    audioRecorderControllerProvider.overrideWith(
      () => _ManualAudioRecorderController(
        AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          progress: Duration.zero,
          vu: -20,
          dBFS: -160,
          showIndicator: false,
          modalVisible: false,
        ),
      ),
    ),
    journalDbProvider.overrideWithValue(harness.journalDb),
    loggingServiceProvider.overrideWithValue(harness.loggingService),
    loginStateStreamProvider.overrideWith(
      (ref) => Stream<LoginState>.value(LoginState.loggedIn),
    ),
    maintenanceProvider.overrideWithValue(harness.maintenance),
    matrixServiceProvider.overrideWithValue(harness.matrixService),
    outboxServiceProvider.overrideWithValue(harness.outboxService),
    shouldAutoShowWhatsNewProvider.overrideWith((ref) async => false),
    syncDatabaseProvider.overrideWithValue(harness.syncDatabase),
  ];
}

class _ManualAiSetupPromptService extends AiSetupPromptService {
  @override
  Future<bool> build() async => false;
}

class _ManualAudioRecorderController extends AudioRecorderController {
  _ManualAudioRecorderController(this.stateOverride);

  final AudioRecorderState stateOverride;

  @override
  AudioRecorderState build() => stateOverride;
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 60,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
}
