/// Deterministic manual screenshots for the production Sync surfaces.
///
/// Mobile captures render the real routed pages. Desktop captures render the
/// same surfaces inside the production Settings V2 master/detail shell. Demo
/// data follows the Project Waddle world used by the task and Daily OS manual
/// so operational states remain recognizable across chapters.
///
/// Generated PNGs are staging inputs for the R2 manual catalog and are never committed
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
import 'package:intl/intl.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_branch_page.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/services/historical_sync_service.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/state/backfill_stats_controller.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/state/matrix_unverified_provider.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/pages/sync_node_profile_page.dart';
import 'package:lotti/features/sync/ui/provisioned/add_device_page.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/features/sync/ui/provisioned_sync_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/pairing_check_code_view.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_message_card.dart';
import 'package:lotti/features/sync/ui/widgets/sync_well.dart';
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
    message: SyncMessage.journalEntity(
      id: manualOrbitalHabitatTaskId,
      jsonPath: '/sync/project-waddle/orbital-habitat.json',
      vectorClock: const VectorClock({'mission-control-mac': 14}),
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
    message: SyncMessage.journalEntity(
      id: manualHabitatCoverImageId,
      jsonPath: '/sync/project-waddle/habitat-photo.json',
      vectorClock: const VectorClock({'penguin-phone': 8}),
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

/// What an already-paired device hands to a new one: same account and room,
/// `handover` kind, so the joining device joins without rotating the password.
final String _manualHandover = base64UrlEncode(
  utf8.encode(
    jsonEncode(
      _provisioningBundle.copyWith(kind: SyncBundleKind.handover).toJson(),
    ),
  ),
);

/// The account as the Add device sheet finds it: this device, plus the peer
/// that has already been verified.
final List<SyncDeviceInfo> _manualDevices = [
  SyncDeviceInfo(
    deviceId: 'MISSIONCONTROL',
    displayName: _t('Mission Control Mac', 'Mission-Control-Mac'),
    isCurrentDevice: true,
    verified: true,
    lastSeen: _syncTime,
  ),
  SyncDeviceInfo(
    deviceId: 'PEBBLEPHONE',
    displayName: _t('Admiral Pebble\u2019s Phone', 'Admiral Pebbles Telefon'),
    isCurrentDevice: false,
    verified: true,
    lastSeen: _syncTime.subtract(const Duration(minutes: 6)),
  ),
];

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

/// Holds the provisioning flow at a fixed point so the onboarding surfaces
/// render deterministically: [terminal] is where importing lands, and the Add
/// device sheet mints a fixed bundle instead of reading persisted config.
class _ManualProvisioningController extends ProvisioningController {
  _ManualProvisioningController({this.terminal});

  /// Where the flow lands when the bundle is imported. Null keeps the real
  /// progression, which no manual surface needs.
  final ProvisioningState? terminal;

  @override
  ProvisioningState build() => const ProvisioningState.initial();

  @override
  Future<String?> regenerateHandover() async => _manualHandover;

  /// The real call walks login, room join and password rotation against a
  /// live homeserver. The manual wants the frame at the end of that, so this
  /// jumps straight to it.
  @override
  Future<void> configureFromBundle(SyncProvisioningBundle bundle) async {
    final target = terminal;
    if (target != null) state = target;
  }
}

/// The viewfinder as the manual should depict it: a framed target area, not
/// the black rectangle a camera-less capture would otherwise produce.
class _ViewfinderStandIn extends StatelessWidget {
  const _ViewfinderStandIn({required this.side});

  final double side;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      child: Center(
        child: SizedBox.square(
          dimension: side * 0.6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: tokens.colors.text.mediumEmphasis,
                width: tokens.spacing.step1,
              ),
              borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
            ),
            child: Center(
              child: Icon(
                LottiIcons.scanQr,
                size: side * 0.3,
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualSyncDevicesController extends SyncDevicesController {
  _ManualSyncDevicesController(this.devices);

  final List<SyncDeviceInfo> devices;

  @override
  Future<List<SyncDeviceInfo>> build() async => devices;

  @override
  Future<bool> refresh() async => true;
}

class _ManualSyncMaintenanceController extends SyncMaintenanceController {
  @override
  SyncState build() => const SyncState();
}

enum _SyncSurface {
  hub,
  provisioned,
  addDevice,
  paired,
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
    _SyncSurface.addDevice => 'add_device',
    _SyncSurface.paired => 'paired',
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
    _SyncSurface.addDevice => '/settings/sync/provisioned',
    _SyncSurface.paired => '/settings/sync/provisioned',
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
    _SyncSurface.addDevice => const ProvisionedSyncPage(),
    _SyncSurface.paired => const ProvisionedSyncPage(),
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
  late MockHistoricalSyncService historicalSyncService;
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
    historicalSyncService = MockHistoricalSyncService();
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
      () => matrixService.incomingKeyVerificationRunnerStream,
    ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());
    when(() => matrixService.keyVerificationRunner).thenReturn(null);
    when(
      () => matrixService.incomingKeyVerificationRunner,
    ).thenReturn(null);
    when(
      () => matrixService.verifyDevice(unverifiedDevice),
    ).thenAnswer((_) async {});
    when(() => matrixService.getUnverifiedDevices()).thenReturn([]);
    when(() => matrixService.getSyncDevices()).thenAnswer((_) async => []);
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
      // Seed the counters the panel actually renders, so the manual
      // screenshots show representative diagnostics rather than a grid of
      // zeros. Unnamespaced keys ('journalEntities') were never read by
      // SyncMetrics.fromMap — the per-type rows come from the
      // 'droppedByType.<type>' namespace.
      (_) async => SyncMetrics.fromMap({
        'dbApplied': 2847,
        'dbIgnoredByVectorClock': 96,
        'conflictsCreated': 2,
        'dbMissingBase': 1,
        'dbEntryLinkNoop': 14,
        'droppedByType.journalEntity': 3,
        'signalConnectivity': 11,
        'queueActive': 7,
        'queueApplied': 2840,
        'queueAbandoned': 0,
        'queueRetrying': 1,
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
    // A capture has no camera plugin, so the real scanner is a black square
    // and a stream of MissingPluginExceptions. This stands in for the
    // viewfinder and makes the scanning step legible in the manual.
    scannerPreviewOverride = (context, side) => _ViewfinderStandIn(side: side);
  });

  tearDown(() async {
    beamToNamedOverride = null;
    scannerPreviewOverride = null;
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
    historicalSyncServiceProvider.overrideWithValue(historicalSyncService),
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
    // Scoped to the onboarding surfaces. Applied globally, these replace
    // the controllers the older surfaces drive for real, and their captures
    // stop reaching the states they assert on.
    if (surface == _SyncSurface.provisioned)
      provisioningControllerProvider.overrideWith(
        () => _ManualProvisioningController(
          terminal: ProvisioningState.ready(_manualHandover),
        ),
      ),
    if (surface == _SyncSurface.paired)
      provisioningControllerProvider.overrideWith(
        () => _ManualProvisioningController(
          terminal: const ProvisioningState.done(),
        ),
      ),
    if (surface == _SyncSurface.addDevice)
      provisioningControllerProvider.overrideWith(
        _ManualProvisioningController.new,
      ),
    if (surface == _SyncSurface.addDevice || surface == _SyncSurface.status)
      syncDevicesControllerProvider.overrideWith(
        () => _ManualSyncDevicesController(_manualDevices),
      ),
  ];

  /// Opens the setup modal and imports a deterministic demo bundle.
  ///
  /// Since the add-device redesign the import page opens the camera on mobile,
  /// so the paste field sits behind *enter manually* rather than being the
  /// first thing rendered. A first-device bundle connects immediately because
  /// there is no peer code to compare. A handover bundle stops on the decoded
  /// review unless [confirm], which carries on into the pairing flow.
  Future<void> openBundleImport(
    WidgetTester tester, {
    bool confirm = false,
    String? bundleText,
  }) async {
    await tester.tap(find.byKey(const Key('sync_setup_cta')));
    await settleFrames(tester, 10);
    expect(find.byType(BundleImportWidget), findsOneWidget);

    final manual = find.byKey(const Key('bundle_import_enter_manually'));
    if (manual.evaluate().isNotEmpty) {
      await tester.ensureVisible(manual);
      await tester.pump();
      await tester.tap(manual, warnIfMissed: false);
      await settleFrames(tester, 8);
    }

    final importedText = bundleText ?? _provisioningBundleText;
    await tester.enterText(
      find.byType(TextField),
      importedText,
    );
    await tester.pump();

    final context = tester.element(find.byType(BundleImportWidget));
    final importButton = find.text(
      context.messages.provisionedSyncImportButton,
    );
    await tester.ensureVisible(importButton);
    await tester.pump();
    await tester.tap(importButton, warnIfMissed: false);
    await settleFrames(tester, 8);

    final importedBundle = SyncProvisioningBundle.fromJson(
      jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(importedText))),
          )
          as Map<String, dynamic>,
    );
    final needsPeerConfirmation =
        importedBundle.kind == SyncBundleKind.handover;
    expect(
      find.byKey(const ValueKey('bundle_import_decoded')),
      needsPeerConfirmation ? findsOneWidget : findsNothing,
    );
    if (!needsPeerConfirmation) return;
    if (!confirm) return;

    final connect = find.text(context.messages.syncPairConnectButton);
    await tester.ensureVisible(connect);
    await tester.pump();
    await tester.tap(connect, warnIfMissed: false);
  }

  Future<void> configureSurface(
    WidgetTester tester,
    _SyncSurface surface,
  ) async {
    switch (surface) {
      case _SyncSurface.provisioned:
        await openBundleImport(tester);
        await settleFrames(tester, 8);
      case _SyncSurface.addDevice:
        await tester.tap(find.byKey(const Key('sync_devices_add_device')));
        await settleFrames(tester, 18);
      case _SyncSurface.paired:
        // A handover bundle, not the provisioned one: production sends
        // `provisioned` through password rotation to `ready` and the
        // first-device view, and only a peer's `handover` reaches `done` and
        // the paired steps this capture documents.
        await openBundleImport(
          tester,
          confirm: true,
          bundleText: _manualHandover,
        );
        await settleFrames(tester, 18);
      case _SyncSurface.status:
        // A configured account renders the roster inline on the page; there is
        // no settings card left to tap since the add-device redesign.
        await settleFrames(tester, 8);
      case _SyncSurface.verification:
        // Same inline roster, and the embedded AutoVerificationLauncher opens
        // the ceremony on its own once a device is unverified.
        await settleFrames(tester, 8);
        expect(find.byType(VerificationModal), findsOneWidget);
        verificationStream.add(verificationRunner);
        await settleFrames(tester, 10);
      case _SyncSurface.outbox:
        await tester.tap(find.byKey(const ValueKey('syncFilter-failed')));
        await settleFrames(tester, 6);
        await tester.tap(find.byType(OutboxMessageCard));
        await settleFrames(tester, 4);
      case _SyncSurface.conflictCombine:
        final messages = tester.element(find.byType(Scaffold).first).messages;
        final context = tester.element(
          find.text(messages.conflictFieldTitle),
        );
        final combine = find.text(context.messages.conflictPickerCombine);
        await tester.ensureVisible(combine);
        await tester.pump();
        await tester.tap(combine, warnIfMissed: false);
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

  /// Refuses to publish a QR code that encodes anything real.
  ///
  /// This capture ends up in a public docs repository and the payload is a
  /// live credential by design — it carries the sync account's password.
  ///
  /// `QrImageView` keeps its payload private, so this guards the two things
  /// that decide it instead: that the provisioning controller is still the
  /// stubbed one (drop that override and the sheet mints a bundle from
  /// whatever sync config the machine running the capture has), and that the
  /// bundle it mints is demo data.
  void expectQrCarriesOnlyDemoData(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AddDeviceView)),
    );
    expect(
      container.read(provisioningControllerProvider.notifier),
      isA<_ManualProvisioningController>(),
      reason: "A real controller would mint this machine's sync credentials",
    );

    final bundle = SyncProvisioningBundle.fromJson(
      jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(_manualHandover))),
          )
          as Map<String, dynamic>,
    );
    expect(bundle.password, 'manual-demo-only');
    expect(bundle.user, endsWith('.test'));
    // `.test` is reserved by RFC 2606; it can never resolve.
    expect(Uri.parse(bundle.homeServer).host, endsWith('.test'));
    expect(bundle.roomId, endsWith('.test'));
  }

  void expectSurface(WidgetTester tester, _SyncSurface surface) {
    final context = tester.element(find.byType(Scaffold).first);
    final messages = context.messages;

    switch (surface) {
      case _SyncSurface.hub:
        expect(find.text(messages.provisionedSyncTitle), findsWidgets);
        expect(find.text(messages.settingsMaintenanceTitle), findsWidgets);
      case _SyncSurface.provisioned:
        // A fresh CLI bundle establishes this account's first device. With no
        // peer available for comparison, it skips the check-code review and
        // lands directly on the honest first-device success state.
        expect(
          find.byKey(const Key('paired_first_device')),
          findsOneWidget,
        );
        expect(
          find.text(messages.syncPairedFirstDeviceTitle),
          findsOneWidget,
        );
        expect(find.byKey(const Key('bundle_import_check_code')), findsNothing);
      case _SyncSurface.addDevice:
        // The pairing check code is the point of the sheet: both devices
        // derive it independently and it must be compared before connecting.
        expect(find.byType(PairingCheckCodeView), findsOneWidget);
        expect(find.text(messages.syncAddDeviceIntro), findsWidgets);
        expectQrCarriesOnlyDemoData(tester);
      case _SyncSurface.paired:
        // The quiet "connected" line plus the card that says what is still
        // outstanding — the point of the screen is the second half.
        expect(find.text(messages.provisionedSyncDone), findsOneWidget);
        expect(find.byType(SyncWell), findsWidgets);
      case _SyncSurface.status:
        expect(find.byType(ProvisionedStatusWidget), findsOneWidget);
        // The roster rows are the subject of this capture; asserting only the
        // surrounding widget passed happily against an empty list.
        for (final device in _manualDevices) {
          expect(find.text(device.displayName!), findsWidgets);
        }
        expect(
          find.text(messages.settingsMatrixDiagnosticShowButton),
          findsOneWidget,
        );
        expect(find.text(messages.provisionedSyncDisconnect), findsOneWidget);
      case _SyncSurface.verification:
        expect(
          find.text(_t('Admiral Pebble’s Phone', 'Admiral Pebbles Telefon')),
          findsWidgets,
        );
        expect(
          find.text(messages.syncVerifyPromptQuestion),
          findsOneWidget,
        );
        expect(find.text(messages.syncVerifyTheyMatch), findsOneWidget);
      case _SyncSurface.nodeProfile:
        expect(find.text(_localNode.displayName), findsOneWidget);
        expect(
          find.text(_knownNodes[1].displayName),
          findsOneWidget,
        );
      case _SyncSurface.backfill:
        expect(find.text(messages.backfillDevicesMeta(2)), findsOneWidget);
        expect(find.text(formatCount(context, 2868)), findsOneWidget);
      case _SyncSurface.stats:
        expect(
          find.textContaining(messages.settingsMatrixMetrics),
          findsOneWidget,
        );
      case _SyncSurface.outbox:
        expect(
          find.text(
            _t('Habitat pressure-seal photo', 'Foto der Habitat-Druckdichtung'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(messages.outboxRetryAll),
          findsOneWidget,
        );
      case _SyncSurface.conflicts:
        final label = toBeginningOfSentenceCase(
          messages.conflictsUnresolved,
          Localizations.localeOf(context).toString(),
        );
        expect(
          find.text(messages.syncListCountSummary(label, 2)),
          findsOneWidget,
        );
        expect(find.text(messages.entryTypeLabelTask), findsOneWidget);
      case _SyncSurface.conflictDetail:
        expect(find.text(messages.conflictFieldTitle), findsOneWidget);
        expect(find.text(messages.conflictFieldBody), findsOneWidget);
        expect(
          find.text(messages.conflictPickerUseThisDevice),
          findsOneWidget,
        );
        expect(
          find.text(messages.conflictPickerUseFromSync),
          findsOneWidget,
        );
      case _SyncSurface.conflictCombine:
        expect(find.text(messages.conflictCombineStartFrom), findsOneWidget);
        expect(find.text(messages.conflictFieldTitle), findsOneWidget);
        expect(find.text(messages.conflictFieldBody), findsOneWidget);
        expect(
          find.text(messages.conflictCombineApply),
          findsOneWidget,
        );
      case _SyncSurface.maintenance:
        expect(
          find.text(messages.maintenanceReSync),
          findsOneWidget,
        );
        expect(
          find.text(messages.maintenancePurgeSentOutbox),
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
          surface == _SyncSurface.verification ||
          surface == _SyncSurface.addDevice;
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

          expectSurface(tester, surface);
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
