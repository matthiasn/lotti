/// Deterministic manual screenshots for the production Sync surfaces.
///
/// Mobile captures render the real routed pages. Desktop captures render the
/// same surfaces inside the production Settings V2 master/detail shell. Demo
/// data follows the Project Waddle world used by the task and Daily OS manual
/// so operational states remain recognizable across chapters.
///
/// Generated PNGs are staging inputs for `lotti-docs` and are never committed
/// to this repository.
///
/// Opt in with:
/// `LOTTI_SCREENSHOT_DIR=/tmp/lotti_sync_manual fvm flutter test \
///   test/features/sync/ui/sync_manual_screenshots_test.dart`
library;

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_branch_page.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/state/backfill_stats_controller.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/pages/sync_node_profile_page.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/provisioned_sync_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_message_card.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/manual_demo_world.dart';
import '../../../helpers/target_platform.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../daily_os_next/screenshot_harness.dart';

const String _subdir = 'sync';
const String _conflictId = 'habitat';

String _t(String en, String de) => manualScreenshotText(en: en, de: de);

final ManualDemoWorld _world = ManualDemoWorld.penguinLogistics();
final DateTime _syncTime = DateTime(2026, 7, 17, 10, 22);

final SyncNodeProfile _localNode = SyncNodeProfile(
  hostId: 'mission-control-mac',
  displayName: _t('Mission Control Mac', 'Missionskontrolle Mac'),
  platform: 'macos',
  capabilities: const [
    NodeCapability.mlxAudio,
    NodeCapability.ollamaLlm,
    NodeCapability.whisper,
  ],
  updatedAt: _syncTime,
);

final List<SyncNodeProfile> _knownNodes = [
  _localNode,
  SyncNodeProfile(
    hostId: 'habitat-linux',
    displayName: _t('Orbital Habitat Console', 'Orbitale Habitatkonsole'),
    platform: 'linux',
    capabilities: const [
      NodeCapability.ollamaLlm,
      NodeCapability.voxtral,
    ],
    updatedAt: _syncTime.subtract(const Duration(minutes: 3)),
  ),
  SyncNodeProfile(
    hostId: 'penguin-phone',
    displayName: _t('Admiral Pebble’s Phone', 'Admiral Pebbles Telefon'),
    platform: 'android',
    capabilities: const [],
    updatedAt: _syncTime.subtract(const Duration(minutes: 8)),
  ),
];

final BackfillStats _backfillStats = BackfillStats.fromHostStats([
  const BackfillHostStats(
    receivedCount: 1842,
    missingCount: 3,
    requestedCount: 2,
    backfilledCount: 47,
    deletedCount: 9,
    unresolvableCount: 1,
    burnedCount: 6,
  ),
  const BackfillHostStats(
    receivedCount: 933,
    missingCount: 1,
    requestedCount: 0,
    backfilledCount: 18,
    deletedCount: 4,
    unresolvableCount: 0,
    burnedCount: 2,
  ),
]);

Task _taskVersion({
  required String title,
  required String description,
  required Map<String, int> clock,
}) {
  final base = _world.orbitalHabitatTask;
  return base.copyWith(
    meta: base.meta.copyWith(
      vectorClock: VectorClock(Map.unmodifiable(clock)),
      updatedAt: _syncTime,
    ),
    data: base.data.copyWith(title: title),
    entryText: EntryText(plainText: description),
  );
}

final Task _localTask = _taskVersion(
  title: _t(
    'Inspect orbital penguin habitat before launch',
    'Orbitales Pinguinhabitat vor dem Start inspizieren',
  ),
  description: _t(
    'Mission Control cleared 36 penguins. Recheck pressure seal C and hold '
        'the sardine cargo pod until the final emperor arrives.',
    'Die Missionskontrolle hat 36 Pinguine freigegeben. Druckdichtung C '
        'erneut prüfen und den Sardinen-Frachtbehälter zurückhalten, bis der '
        'letzte Kaiserpinguin eintrifft.',
  ),
  clock: const {'mission-control-mac': 14, 'penguin-phone': 7},
);

final Task _remoteTask = _taskVersion(
  title: _t(
    'Launch orbital penguin habitat after seal inspection',
    'Orbitales Pinguinhabitat nach Dichtungsprüfung starten',
  ),
  description: _t(
    'Habitat Console cleared all 37 penguins and pressure seal C. Release '
        'the zero-gravity sardine cargo pod at 11:20.',
    'Die Habitatkonsole hat alle 37 Pinguine und Druckdichtung C '
        'freigegeben. Den Schwerelosigkeits-Sardinenbehälter um 11:20 Uhr '
        'ausklinken.',
  ),
  clock: const {'mission-control-mac': 13, 'habitat-linux': 11},
);

Conflict _conflictFor({
  required String id,
  required JournalEntity remote,
  required ConflictStatus status,
  required DateTime createdAt,
}) => Conflict(
  id: id,
  createdAt: createdAt,
  updatedAt: createdAt,
  serialized: jsonEncode(remote.toJson()),
  schemaVersion: 1,
  status: status.index,
);

final Conflict _taskConflict = _conflictFor(
  id: _conflictId,
  remote: _remoteTask,
  status: ConflictStatus.unresolved,
  createdAt: _syncTime,
);

final JournalEntry _cargoNote = JournalEntry(
  meta: Metadata(
    id: 'cargo-note-europa',
    createdAt: _syncTime.subtract(const Duration(minutes: 25)),
    updatedAt: _syncTime.subtract(const Duration(minutes: 25)),
    dateFrom: _syncTime.subtract(const Duration(minutes: 25)),
    dateTo: _syncTime.subtract(const Duration(minutes: 20)),
    vectorClock: const VectorClock({'penguin-phone': 9}),
  ),
  entryText: EntryText(
    plainText: _t(
      'Europa sardine cargo manifest revised by Admiral Pebble.',
      'Sardinen-Frachtmanifest für Europa von Admiral Pebble überarbeitet.',
    ),
  ),
);

final List<Conflict> _unresolvedConflicts = [
  _taskConflict,
  _conflictFor(
    id: 'sardines',
    remote: _cargoNote,
    status: ConflictStatus.unresolved,
    createdAt: _syncTime.subtract(const Duration(minutes: 25)),
  ),
];

final List<Conflict> _resolvedConflicts = [
  _conflictFor(
    id: 'fish-feeder-4ab6',
    remote: _world.fishFeederTask,
    status: ConflictStatus.resolved,
    createdAt: _syncTime.subtract(const Duration(hours: 3)),
  ),
];

String _messageJson(SyncMessage message) => jsonEncode(message.toJson());

OutboxItem _outboxItem({
  required int id,
  required OutboxStatus status,
  required String subject,
  required SyncMessage message,
  required Duration age,
  int retries = 0,
  String? filePath,
  int? payloadSize,
}) {
  final createdAt = _syncTime.subtract(age);
  return OutboxItem(
    id: id,
    createdAt: createdAt,
    updatedAt: createdAt,
    status: status.index,
    retries: retries,
    message: _messageJson(message),
    subject: subject,
    filePath: filePath,
    payloadSize: payloadSize,
    priority: OutboxPriority.high.index,
  );
}

final List<OutboxItem> _outboxItems = [
  _outboxItem(
    id: 1,
    status: OutboxStatus.sending,
    subject: _t(
      'Inspect orbital penguin habitat',
      'Orbitales Pinguinhabitat inspizieren',
    ),
    message: const SyncMessage.journalEntity(
      id: manualOrbitalHabitatTaskId,
      jsonPath: '/sync/project-waddle/orbital-habitat.json',
      vectorClock: VectorClock({'mission-control-mac': 14}),
      status: SyncEntryStatus.update,
    ),
    age: const Duration(seconds: 18),
    payloadSize: 18432,
  ),
  _outboxItem(
    id: 2,
    status: OutboxStatus.pending,
    subject: _t('Project Waddle node profile', 'Project-Waddle-Knotenprofil'),
    message: SyncMessage.syncNodeProfile(profile: _localNode),
    age: const Duration(minutes: 2),
    payloadSize: 1220,
  ),
  _outboxItem(
    id: 3,
    status: OutboxStatus.error,
    subject: _t(
      'Habitat pressure-seal photo',
      'Foto der Habitat-Druckdichtung',
    ),
    message: const SyncMessage.journalEntity(
      id: manualHabitatCoverImageId,
      jsonPath: '/sync/project-waddle/habitat-photo.json',
      vectorClock: VectorClock({'penguin-phone': 8}),
      status: SyncEntryStatus.initial,
    ),
    age: const Duration(minutes: 7),
    retries: 2,
    filePath: '/attachments/habitat-pressure-seal.webp',
    payloadSize: 2400000,
  ),
  _outboxItem(
    id: 4,
    status: OutboxStatus.sent,
    subject: _t(
      'Project Waddle private-mode flag',
      'Project-Waddle-Flag für privaten Modus',
    ),
    message: SyncMessage.configFlag(
      name: 'privateFlag',
      description: _t('Show private entries', 'Private Einträge anzeigen'),
      status: true,
    ),
    age: const Duration(minutes: 12),
    payloadSize: 642,
  ),
];

const SyncProvisioningBundle _provisioningBundle = SyncProvisioningBundle(
  v: 2,
  kind: SyncBundleKind.provisioned,
  homeServer: 'https://sync.project-waddle.test',
  user: '@mission-control:project-waddle.test',
  password: 'manual-demo-only',
  roomId: '!orbital-habitat:project-waddle.test',
);

final String _provisioningBundleText = base64UrlEncode(
  utf8.encode(jsonEncode(_provisioningBundle.toJson())),
);

class _ManualBackfillStatsController extends BackfillStatsController {
  @override
  BackfillStatsState build() => BackfillStatsState(stats: _backfillStats);
}

class _ManualBackfillConfigController extends BackfillConfigController {
  @override
  Future<bool> build() async => true;
}

class _ManualMatrixStatsController extends MatrixStatsController {
  @override
  Future<MatrixStats> build() async => const MatrixStats(
    sentCount: 2847,
    messageCounts: {
      'm.room.message': 2714,
      'm.room.encrypted': 118,
      'm.key.verification.start': 15,
    },
  );
}

class _ManualUnverifiedController extends MatrixUnverifiedController {
  _ManualUnverifiedController(this.devices);

  final List<DeviceKeys> devices;

  @override
  Future<List<DeviceKeys>> build() async => devices;
}

class _ManualSyncMaintenanceController extends SyncMaintenanceController {
  @override
  SyncState build() => const SyncState();
}

enum _SyncSurface {
  hub,
  provisioned,
  status,
  verification,
  nodeProfile,
  backfill,
  stats,
  outbox,
  conflicts,
  conflictDetail,
  conflictCombine,
  maintenance,
}

extension on _SyncSurface {
  String get id => switch (this) {
    _SyncSurface.hub => 'hub',
    _SyncSurface.provisioned => 'provisioned',
    _SyncSurface.status => 'status',
    _SyncSurface.verification => 'verification',
    _SyncSurface.nodeProfile => 'node_profile',
    _SyncSurface.backfill => 'backfill',
    _SyncSurface.stats => 'stats',
    _SyncSurface.outbox => 'outbox',
    _SyncSurface.conflicts => 'conflicts',
    _SyncSurface.conflictDetail => 'conflict_detail',
    _SyncSurface.conflictCombine => 'conflict_combine',
    _SyncSurface.maintenance => 'maintenance',
  };

  String get route => switch (this) {
    _SyncSurface.hub => '/settings/sync',
    _SyncSurface.provisioned => '/settings/sync/provisioned',
    _SyncSurface.status => '/settings/sync/provisioned',
    _SyncSurface.verification => '/settings/sync/provisioned',
    _SyncSurface.nodeProfile => '/settings/sync/node-profile',
    _SyncSurface.backfill => '/settings/sync/backfill',
    _SyncSurface.stats => '/settings/sync/stats',
    _SyncSurface.outbox => '/settings/sync/outbox',
    _SyncSurface.conflicts => '/settings/advanced/conflicts',
    _SyncSurface.conflictDetail => '/settings/advanced/conflicts/$_conflictId',
    _SyncSurface.conflictCombine => '/settings/advanced/conflicts/$_conflictId',
    _SyncSurface.maintenance => '/settings/sync/matrix/maintenance',
  };

  Map<String, String> get pathParameters => switch (this) {
    _SyncSurface.conflictDetail => const {'conflictId': _conflictId},
    _SyncSurface.conflictCombine => const {'conflictId': _conflictId},
    _ => const {},
  };

  Widget mobilePage() => switch (this) {
    _SyncSurface.hub => const SettingsMobileBranchPage(branchId: 'sync'),
    _SyncSurface.provisioned => const ProvisionedSyncPage(),
    _SyncSurface.status => const ProvisionedSyncPage(),
    _SyncSurface.verification => const ProvisionedSyncPage(),
    _SyncSurface.nodeProfile => const SyncNodeProfilePage(),
    _SyncSurface.backfill => const BackfillSettingsPage(),
    _SyncSurface.stats => const SyncStatsPage(),
    _SyncSurface.outbox => const OutboxMonitorPage(),
    _SyncSurface.conflicts => const ConflictsPage(),
    _SyncSurface.conflictDetail => const ConflictDetailRoute(
      conflictId: _conflictId,
    ),
    _SyncSurface.conflictCombine => const ConflictDetailRoute(
      conflictId: _conflictId,
    ),
    _SyncSurface.maintenance => const MatrixSyncMaintenancePage(),
  };
}

Widget _app({
  required Widget home,
  required Brightness brightness,
  required Size size,
  required List<Override> overrides,
}) {
  return RepaintBoundary(
    key: screenshotBoundaryKey,
    child: ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: manualScreenshotLocale,
          home: home,
        ),
      ),
    ),
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'sync manual screenshot harness (opt-in)',
      () {},
      skip:
          'Manual screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir>.',
    );
    return;
  }

  setUpAll(() async {
    registerAllFallbackValues();
    registerFallbackValue(
      const MatrixConfig(
        homeServer: '',
        user: '',
        password: '',
      ),
    );
    await loadScreenshotFonts();
  });

  late TestGetItMocks mocks;
  late MockMatrixService matrixService;
  late MockMatrixClient matrixClient;
  late MockSyncDatabase syncDatabase;
  late MockMaintenance maintenance;
  late MockSyncNodeProfileBroadcaster nodeBroadcaster;
  late MockPersistenceLogic persistenceLogic;
  late MockEntitiesCacheService entitiesCache;
  late MockDeviceKeys unverifiedDevice;
  late MockKeyVerificationRunner verificationRunner;
  late StreamController<KeyVerificationRunner> verificationStream;
  late NavService navService;

  setUp(() async {
    mocks = await setUpTestGetIt();
    matrixService = MockMatrixService();
    matrixClient = MockMatrixClient();
    syncDatabase = MockSyncDatabase();
    maintenance = MockMaintenance();
    nodeBroadcaster = MockSyncNodeProfileBroadcaster();
    persistenceLogic = MockPersistenceLogic();
    entitiesCache = MockEntitiesCacheService();
    unverifiedDevice = MockDeviceKeys();
    verificationRunner = MockKeyVerificationRunner();
    verificationStream = StreamController<KeyVerificationRunner>.broadcast();
    navService = NavService();

    when(
      () => mocks.journalDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(true));
    when(
      () => mocks.journalDb.watchConflicts(ConflictStatus.unresolved),
    ).thenAnswer((_) => Stream.value(_unresolvedConflicts));
    when(
      () => mocks.journalDb.watchConflicts(ConflictStatus.resolved),
    ).thenAnswer((_) => Stream.value(_resolvedConflicts));
    when(
      () => mocks.journalDb.watchConflictById(_conflictId),
    ).thenAnswer((_) => Stream.value([_taskConflict]));
    when(
      () => mocks.journalDb.journalEntityById(_conflictId),
    ).thenAnswer((_) async => _localTask);

    when(matrixService.isLoggedIn).thenReturn(false);
    when(() => matrixService.syncRoomId).thenReturn(null);
    when(() => matrixService.client).thenReturn(matrixClient);
    when(() => matrixClient.userID).thenReturn(null);
    when(
      () => matrixService.keyVerificationStream,
    ).thenAnswer((_) => verificationStream.stream);
    when(
      () => matrixService.verifyDevice(unverifiedDevice),
    ).thenAnswer((_) async {});
    when(() => matrixService.getUnverifiedDevices()).thenReturn([]);
    when(() => matrixService.deleteConfig()).thenAnswer((_) async {});
    when(() => matrixService.loadConfig()).thenAnswer(
      (_) async => const MatrixConfig(
        homeServer: 'https://sync.project-waddle.test',
        user: '@mission-control:project-waddle.test',
        password: 'manual-demo-only',
      ),
    );
    when(
      () => matrixService.setConfig(any()),
    ).thenAnswer((_) async {});
    when(
      () => matrixService.getSyncMetrics(),
    ).thenAnswer(
      (_) async => SyncMetrics.fromMap({
        'processed': 2847,
        'failures': 2,
        'retriesScheduled': 7,
        'journalEntities': 1944,
        'entryLinks': 622,
        'agentEntities': 281,
      }),
    );
    when(
      () => matrixService.getSyncDiagnosticsText(),
    ).thenAnswer(
      (_) async => _t(
        'Project Waddle sync healthy',
        'Project-Waddle-Synchronisierung fehlerfrei',
      ),
    );

    when(
      () => syncDatabase.getOutboxItems(limit: any(named: 'limit')),
    ).thenAnswer((_) async => _outboxItems);
    when(
      () => syncDatabase.watchOutboxCount(),
    ).thenAnswer((_) => Stream.value(3));
    when(
      () => syncDatabase.getDailyOutboxVolume(days: any(named: 'days')),
    ).thenAnswer((_) async => const []);

    when(
      () => nodeBroadcaster.broadcastIfChanged(
        displayNameOverride: any(named: 'displayNameOverride'),
        appVersion: any(named: 'appVersion'),
      ),
    ).thenAnswer((_) async => true);
    when(() => entitiesCache.getCategoryById(any())).thenReturn(
      _world.category,
    );
    when(
      () => persistenceLogic.updateJournalEntity(any(), any()),
    ).thenAnswer((_) async => true);
    when(() => unverifiedDevice.userId).thenReturn(
      '@admiral-pebble:project-waddle.test',
    );
    when(() => unverifiedDevice.deviceDisplayName).thenReturn(
      _t('Admiral Pebble’s Phone', 'Admiral Pebbles Telefon'),
    );
    when(() => unverifiedDevice.deviceId).thenReturn('PEBBLE-PHONE-7F3A');
    when(() => verificationRunner.lastStep).thenReturn(
      'm.key.verification.key',
    );
    when(() => verificationRunner.emojis).thenReturn([
      FakeKeyVerificationEmoji('🐧', _t('Penguin', 'Pinguin')),
      FakeKeyVerificationEmoji('🐟', _t('Fish', 'Fisch')),
      FakeKeyVerificationEmoji('🚀', _t('Rocket', 'Rakete')),
      FakeKeyVerificationEmoji('🧊', _t('Ice', 'Eis')),
      FakeKeyVerificationEmoji('🌍', _t('Earth', 'Erde')),
      FakeKeyVerificationEmoji('🌙', _t('Moon', 'Mond')),
      FakeKeyVerificationEmoji('⭐', _t('Star', 'Stern')),
      FakeKeyVerificationEmoji('🔭', _t('Telescope', 'Teleskop')),
    ]);
    final keyVerification = MockKeyVerification();
    when(() => keyVerification.isDone).thenReturn(false);
    when(() => verificationRunner.keyVerification).thenReturn(keyVerification);
    when(
      verificationRunner.cancelVerification,
    ).thenAnswer((_) async {});
    when(
      verificationRunner.acceptEmojiVerification,
    ).thenAnswer((_) async {});
    when(() => maintenance.deleteSyncDb()).thenAnswer((_) async {});
    when(
      () => maintenance.purgeSentOutboxItems(
        retention: any(named: 'retention'),
        chunkSize: any(named: 'chunkSize'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => 0);

    getIt
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<SyncDatabase>(syncDatabase)
      ..registerSingleton<Maintenance>(maintenance)
      ..registerSingleton<SyncNodeProfileBroadcaster>(nodeBroadcaster)
      ..registerSingleton<PersistenceLogic>(persistenceLogic)
      ..registerSingleton<EntitiesCacheService>(entitiesCache)
      ..registerSingleton<NavService>(navService);

    beamToNamedOverride = (_) {};
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await verificationStream.close();
    await navService.dispose();
    await tearDownTestGetIt();
  });

  List<Override> overrides(_SyncSurface surface) => [
    configFlagProvider(enableMatrixFlag).overrideWith(
      (ref) => Stream.value(true),
    ),
    templatesPendingReviewProvider.overrideWith((ref) async => <String>{}),
    matrixServiceProvider.overrideWithValue(matrixService),
    journalDbProvider.overrideWithValue(mocks.journalDb),
    syncDatabaseProvider.overrideWithValue(syncDatabase),
    maintenanceProvider.overrideWithValue(maintenance),
    localSyncNodeSelfProvider.overrideWith((ref) => Stream.value(_localNode)),
    knownSyncNodesProvider.overrideWith((ref) => Stream.value(_knownNodes)),
    backfillConfigControllerProvider.overrideWith(
      _ManualBackfillConfigController.new,
    ),
    backfillStatsControllerProvider.overrideWith(
      _ManualBackfillStatsController.new,
    ),
    backfillMissingCountProvider.overrideWith((ref) => Stream.value(4)),
    matrixStatsControllerProvider.overrideWith(
      _ManualMatrixStatsController.new,
    ),
    matrixUnverifiedControllerProvider.overrideWith(
      () => _ManualUnverifiedController(
        surface == _SyncSurface.verification ? [unverifiedDevice] : const [],
      ),
    ),
    outboxConnectionStateProvider.overrideWith(
      (ref) => Stream.value(OutboxConnectionState.online),
    ),
    syncControllerProvider.overrideWith(
      _ManualSyncMaintenanceController.new,
    ),
  ];

  Future<void> configureSurface(
    WidgetTester tester,
    _SyncSurface surface,
  ) async {
    switch (surface) {
      case _SyncSurface.provisioned:
        await tester.tap(find.byType(ProvisionedSyncSettingsCard));
        await settleFrames(tester, 10);
        expect(find.byType(BundleImportWidget), findsOneWidget);
        await tester.enterText(find.byType(TextField), _provisioningBundleText);
        await tester.pump();
        final context = tester.element(find.byType(BundleImportWidget));
        await tester.tap(
          find.text(context.messages.provisionedSyncImportButton),
        );
        await settleFrames(tester, 8);
      case _SyncSurface.status:
        await tester.tap(find.byType(ProvisionedSyncSettingsCard));
        await settleFrames(tester, 18);
      case _SyncSurface.verification:
        await tester.tap(find.byType(ProvisionedSyncSettingsCard));
        await settleFrames(tester, 18);
        expect(find.byType(VerificationModal), findsOneWidget);
        verificationStream.add(verificationRunner);
        await settleFrames(tester, 10);
      case _SyncSurface.outbox:
        await tester.tap(find.byKey(const ValueKey('syncFilter-failed')));
        await settleFrames(tester, 6);
        await tester.tap(find.byType(OutboxMessageCard));
        await settleFrames(tester, 4);
      case _SyncSurface.conflictCombine:
        final context = tester.element(find.text(_t('Title', 'Titel')));
        await tester.tap(find.text(context.messages.conflictPickerCombine));
        await settleFrames(tester, 4);
      case _SyncSurface.hub:
      case _SyncSurface.nodeProfile:
      case _SyncSurface.backfill:
      case _SyncSurface.stats:
      case _SyncSurface.conflicts:
      case _SyncSurface.conflictDetail:
      case _SyncSurface.maintenance:
        break;
    }
  }

  void expectSurface(_SyncSurface surface) {
    switch (surface) {
      case _SyncSurface.hub:
        expect(
          find.text(_t('Provisioned Sync', 'Provisionierte Synchronisierung')),
          findsWidgets,
        );
        expect(find.text(_t('Maintenance', 'Wartung')), findsWidgets);
      case _SyncSurface.provisioned:
        expect(find.text(_provisioningBundle.homeServer), findsOneWidget);
        expect(find.text(_provisioningBundle.user), findsOneWidget);
      case _SyncSurface.status:
        expect(find.byType(ProvisionedStatusWidget), findsOneWidget);
        expect(
          find.text(_t('Show Diagnostic Info', 'Diagnoseinfos anzeigen')),
          findsOneWidget,
        );
        expect(find.text(_t('Disconnect', 'Trennen')), findsOneWidget);
      case _SyncSurface.verification:
        expect(
          find.text(_t('Admiral Pebble’s Phone', 'Admiral Pebbles Telefon')),
          findsWidgets,
        );
        expect(
          find.textContaining(_t('emojis below', 'unten stehenden Emojis')),
          findsOneWidget,
        );
        expect(find.text(_t('Accept', 'Akzeptieren')), findsOneWidget);
      case _SyncSurface.nodeProfile:
        expect(find.text(_localNode.displayName), findsOneWidget);
        expect(
          find.text(_t('Orbital Habitat Console', 'Orbitale Habitatkonsole')),
          findsOneWidget,
        );
      case _SyncSurface.backfill:
        expect(find.text(_t('2 device IDs', '2 Geräte-IDs')), findsOneWidget);
        expect(find.text(_t('2,868', '2.868')), findsOneWidget);
      case _SyncSurface.stats:
        expect(
          find.textContaining(_t('Sync Metrics', 'Sync-Metriken')),
          findsOneWidget,
        );
        expect(find.text('Top KPIs'), findsOneWidget);
        expect(find.text('Processed'), findsWidgets);
      case _SyncSurface.outbox:
        expect(
          find.text(
            _t('Habitat pressure-seal photo', 'Foto der Habitat-Druckdichtung'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(_t('Retry all', 'Alle erneut senden')),
          findsOneWidget,
        );
      case _SyncSurface.conflicts:
        expect(
          find.text(_t('Unresolved · 2 items', 'Ungelöst · 2 Elemente')),
          findsOneWidget,
        );
        expect(find.text(_t('Task', 'Aufgabe')), findsOneWidget);
      case _SyncSurface.conflictDetail:
        expect(find.text(_t('Title', 'Titel')), findsOneWidget);
        expect(find.text(_t('Body', 'Text')), findsOneWidget);
        expect(
          find.text(_t('Use this device', 'Dieses Gerät verwenden')),
          findsOneWidget,
        );
        expect(
          find.text(_t('Use from sync', 'Aus Sync verwenden')),
          findsOneWidget,
        );
      case _SyncSurface.conflictCombine:
        expect(find.text(_t('Start from', 'Ausgehen von')), findsOneWidget);
        expect(find.text(_t('Title', 'Titel')), findsOneWidget);
        expect(find.text(_t('Body', 'Text')), findsOneWidget);
        expect(
          find.text(_t('Apply combined', 'Kombiniert übernehmen')),
          findsOneWidget,
        );
      case _SyncSurface.maintenance:
        expect(
          find.text(
            _t('Re-sync messages', 'Nachrichten erneut synchronisieren'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _t(
              'Purge old sent outbox items',
              'Alte gesendete Outbox-Einträge löschen',
            ),
          ),
          findsOneWidget,
        );
    }
  }

  Future<void> pumpSurface(
    WidgetTester tester, {
    required _SyncSurface surface,
    required ScreenshotDevice device,
    required Brightness brightness,
  }) => withTargetPlatform(
    device.isPhone ? TargetPlatform.android : TargetPlatform.linux,
    () async {
      applyScreenshotDevice(tester, device);

      final configured =
          surface == _SyncSurface.status ||
          surface == _SyncSurface.verification;
      when(matrixService.isLoggedIn).thenReturn(configured);
      when(
        () => matrixService.syncRoomId,
      ).thenReturn(configured ? _provisioningBundle.roomId : null);

      final previousIsDesktop = platform.isDesktop;
      final previousIsMobile = platform.isMobile;
      platform.isDesktop = !device.isPhone;
      platform.isMobile = device.isPhone;
      addTearDown(() {
        platform.isDesktop = previousIsDesktop;
        platform.isMobile = previousIsMobile;
      });

      navService.isDesktopMode = !device.isPhone;
      navService.desktopSelectedSettingsRoute.value = device.isPhone
          ? null
          : (
              path: surface.route,
              pathParameters: surface.pathParameters,
              queryParameters: const <String, String>{},
            );

      await withClock(Clock.fixed(_syncTime), () async {
        await tester.pumpWidget(
          _app(
            home: device.isPhone
                ? surface.mobilePage()
                : const SettingsRootPage(),
            brightness: brightness,
            size: device.size,
            overrides: overrides(surface),
          ),
        );
        await settleFrames(tester, 18);
        await configureSurface(tester, surface);
      });
    },
  );

  for (final (viewport, device) in [
    ('mobile', miniDevice),
    ('desktop', desktopDevice),
  ]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;
      for (final surface in _SyncSurface.values) {
        testWidgets('${surface.id} $viewport manual — $theme', (tester) async {
          await pumpSurface(
            tester,
            surface: surface,
            device: device,
            brightness: brightness,
          );

          expectSurface(surface);
          expect(tester.takeException(), isNull);
          await captureScreenshot(
            tester,
            'sync_${surface.id}_${viewport}_$theme',
            subdir: _subdir,
          );
        });
      }
    }
  }
}
