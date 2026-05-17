import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/repository/sync_node_profile_repository.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _FakeProbe {
  _FakeProbe({required this.platform, required this.capabilities});

  String platform;
  List<NodeCapability> capabilities;
  int calls = 0;

  Future<SyncNodeProfile> probe({
    required String hostId,
    required DateTime now,
    String? displayName,
    String? appVersion,
  }) async {
    calls++;
    return SyncNodeProfile(
      hostId: hostId,
      displayName: displayName ?? 'Default name',
      platform: platform,
      capabilities: List<NodeCapability>.from(capabilities),
      appVersion: appVersion,
      updatedAt: now,
    );
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      SyncMessage.syncNodeProfile(
        profile: SyncNodeProfile(
          hostId: '_fallback',
          displayName: '_fallback',
          platform: 'macos',
          capabilities: const [],
          updatedAt: DateTime.utc(2000),
        ),
      ),
    );
  });

  late SettingsDb settingsDb;
  late SyncNodeProfileRepository repo;
  late MockVectorClockService vectorClockService;
  late MockOutboxService outboxService;
  late _FakeProbe probe;
  late SyncNodeProfileBroadcaster broadcaster;

  final t0 = DateTime.utc(2026, 3, 15, 12);
  final t1 = DateTime.utc(2026, 3, 15, 13);

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    settingsDb = SettingsDb(inMemoryDatabase: true);
    repo = SyncNodeProfileRepository(settingsDb: settingsDb);

    vectorClockService = MockVectorClockService();
    outboxService = MockOutboxService();
    when(() => vectorClockService.getHost()).thenAnswer((_) async => 'self-h');
    when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});

    probe = _FakeProbe(
      platform: 'macos',
      capabilities: [NodeCapability.mlxAudio],
    );

    var tick = 0;
    broadcaster = SyncNodeProfileBroadcaster(
      repository: repo,
      probe: probe.probe,
      vectorClockService: vectorClockService,
      outboxService: outboxService,
      clock: () => tick++ == 0 ? t0 : t1,
    );
  });

  tearDown(() async {
    await repo.dispose();
    await settingsDb.close();
  });

  test(
    'broadcastIfChanged first invocation persists self and broadcasts',
    () async {
      final broadcast = await broadcaster.broadcastIfChanged();

      expect(broadcast, isTrue);
      expect(probe.calls, 1);

      final self = await repo.getSelf();
      expect(self?.hostId, 'self-h');
      expect(self?.capabilities, [NodeCapability.mlxAudio]);

      final captured = verify(
        () => outboxService.enqueueMessage(captureAny()),
      ).captured;
      expect(captured, hasLength(1));
      final msg = captured.single as SyncSyncNodeProfile;
      expect(msg.profile.hostId, 'self-h');
      expect(msg.profile.capabilities, [NodeCapability.mlxAudio]);
    },
  );

  test('broadcast() re-publishes even when content is unchanged', () async {
    // First call writes the self profile + broadcasts.
    await broadcaster.broadcast();
    reset(outboxService);
    when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});

    // Second call with identical probe output: broadcast() does NOT skip.
    // This is the durability guarantee for peers that joined late or wiped
    // their directory — they get the snapshot on the next startup of any
    // peer, not only on diff.
    final broadcast = await broadcaster.broadcast();

    expect(broadcast, isTrue);
    final captured = verify(
      () => outboxService.enqueueMessage(captureAny()),
    ).captured;
    expect(captured, hasLength(1));
  });

  test('second invocation with identical probe output is a no-op', () async {
    await broadcaster.broadcastIfChanged();
    reset(outboxService);
    when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});

    final broadcast = await broadcaster.broadcastIfChanged();

    expect(broadcast, isFalse);
    expect(probe.calls, 2);
    verifyNever(() => outboxService.enqueueMessage(any()));
  });

  test('capability change triggers a re-broadcast', () async {
    await broadcaster.broadcastIfChanged();
    reset(outboxService);
    when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});

    probe.capabilities = [
      NodeCapability.mlxAudio,
      NodeCapability.ollamaLlm,
    ];

    final broadcast = await broadcaster.broadcastIfChanged();

    expect(broadcast, isTrue);
    final captured = verify(
      () => outboxService.enqueueMessage(captureAny()),
    ).captured;
    final msg = captured.single as SyncSyncNodeProfile;
    expect(msg.profile.capabilities, [
      NodeCapability.mlxAudio,
      NodeCapability.ollamaLlm,
    ]);
  });

  test('displayNameOverride beats the probe default and persists', () async {
    final broadcast = await broadcaster.broadcastIfChanged(
      displayNameOverride: 'Studio Mac',
    );

    expect(broadcast, isTrue);
    final self = await repo.getSelf();
    expect(self?.displayName, 'Studio Mac');
  });

  test('after rename, probe defaults do not reset the chosen name', () async {
    await broadcaster.broadcastIfChanged(
      displayNameOverride: 'Studio Mac',
    );
    reset(outboxService);
    when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});

    final broadcast = await broadcaster.broadcastIfChanged();

    expect(broadcast, isFalse);
    final self = await repo.getSelf();
    expect(self?.displayName, 'Studio Mac');
  });

  test('skips broadcast when vector-clock host is missing', () async {
    when(() => vectorClockService.getHost()).thenAnswer((_) async => null);

    final broadcast = await broadcaster.broadcastIfChanged();

    expect(broadcast, isFalse);
    expect(probe.calls, 0);
    verifyNever(() => outboxService.enqueueMessage(any()));
  });

  test(
    'setDisplayName routes through broadcastIfChanged with the override and '
    'persists the new name',
    () async {
      await broadcaster.setDisplayName('Studio Mac');

      final self = await repo.getSelf();
      expect(self?.displayName, 'Studio Mac');
      verify(() => outboxService.enqueueMessage(any())).called(1);
    },
  );

  test(
    'with a DomainLogger wired, the issued-broadcast and skipped-unchanged '
    'log paths fire on the matching control flow',
    () async {
      final logger = MockDomainLogger();
      when(
        () => logger.log(any(), any(), subDomain: any(named: 'subDomain')),
      ).thenAnswer((_) {});

      var tick = 0;
      final loggingBroadcaster = SyncNodeProfileBroadcaster(
        repository: repo,
        probe: probe.probe,
        vectorClockService: vectorClockService,
        outboxService: outboxService,
        domainLogger: logger,
        clock: () => tick++ == 0 ? t0 : t1,
      );

      await loggingBroadcaster.broadcastIfChanged();
      verify(
        () => logger.log(
          LogDomains.sync,
          any(that: contains('broadcast issued')),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);

      // Identical re-probe → diff path returns false and logs the skip.
      await loggingBroadcaster.broadcastIfChanged();
      verify(
        () => logger.log(
          LogDomains.sync,
          any(that: contains('skipped: unchanged')),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    },
  );

  test(
    'logs the no-host-id skip when DomainLogger is wired',
    () async {
      final logger = MockDomainLogger();
      when(
        () => logger.log(any(), any(), subDomain: any(named: 'subDomain')),
      ).thenAnswer((_) {});
      when(() => vectorClockService.getHost()).thenAnswer((_) async => null);

      final loggingBroadcaster = SyncNodeProfileBroadcaster(
        repository: repo,
        probe: probe.probe,
        vectorClockService: vectorClockService,
        outboxService: outboxService,
        domainLogger: logger,
        clock: () => t0,
      );

      await loggingBroadcaster.broadcastIfChanged();

      verify(
        () => logger.log(
          LogDomains.sync,
          any(that: contains('no host id')),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    },
  );
}
