import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  // A deterministic, per-test clock that dispenses successive timestamps from a
  // queue. Unlike a stateful `tick++` counter, this makes each clock reading an
  // explicit element — adding timestamps for tests that probe more than twice is
  // a matter of seeding more entries, not reasoning about counter arithmetic.
  late List<DateTime> clockQueue;
  DateTime nextClock() =>
      clockQueue.length > 1 ? clockQueue.removeAt(0) : clockQueue.first;

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

    clockQueue = [t0, t1];
    broadcaster = SyncNodeProfileBroadcaster(
      repository: repo,
      probe: probe.probe,
      vectorClockService: vectorClockService,
      outboxService: outboxService,
      clock: nextClock,
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

  test(
    'enqueueMessage throw propagates after the self profile was persisted',
    () async {
      when(
        () => outboxService.enqueueMessage(any()),
      ).thenThrow(StateError('outbox unavailable'));

      // The broadcaster does not swallow outbox failures — the caller owns
      // retry policy. The local self profile is already persisted by then,
      // so the next broadcastIfChanged sees unchanged content.
      await expectLater(
        broadcaster.broadcastIfChanged,
        throwsStateError,
      );
      final self = await repo.getSelf();
      expect(self?.hostId, 'self-h');
    },
  );

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

      final loggingBroadcaster = SyncNodeProfileBroadcaster(
        repository: repo,
        probe: probe.probe,
        vectorClockService: vectorClockService,
        outboxService: outboxService,
        domainLogger: logger,
        clock: nextClock,
      );

      await loggingBroadcaster.broadcastIfChanged();
      verify(
        () => logger.log(
          LogDomain.sync,
          any(that: contains('broadcast issued')),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);

      // Identical re-probe → diff path returns false and logs the skip.
      await loggingBroadcaster.broadcastIfChanged();
      verify(
        () => logger.log(
          LogDomain.sync,
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
        clock: nextClock,
      );

      await loggingBroadcaster.broadcastIfChanged();

      verify(
        () => logger.log(
          LogDomain.sync,
          any(that: contains('no host id')),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    },
  );

  group('glados: broadcastIfChanged diff invariant', () {
    glados.Glados(
      glados.any.probeSequence,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'returns true iff probed content differs from the last persisted '
      'self profile; false on an identical re-probe',
      (steps) async {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        // Glados reuses one binding across runs — own a fresh in-memory DB per
        // run so prior persisted state never leaks into the next sequence.
        final db = SettingsDb(inMemoryDatabase: true);
        final localRepo = SyncNodeProfileRepository(settingsDb: db);
        final vcs = MockVectorClockService();
        // ignore: unnecessary_lambdas — mocktail requires the call inside when().
        when(() => vcs.getHost()).thenAnswer((_) async => 'self-h');
        final outbox = MockOutboxService();
        when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});

        final localProbe = _FakeProbe(
          platform: 'macos',
          capabilities: const [],
        );
        // Each broadcast reads the clock once; a monotonically increasing
        // counter keeps updatedAt distinct so content equality is the only
        // thing the diff can hinge on.
        var seconds = 0;
        final localBroadcaster = SyncNodeProfileBroadcaster(
          repository: localRepo,
          probe: localProbe.probe,
          vectorClockService: vcs,
          outboxService: outbox,
          clock: () => DateTime.utc(2026, 3, 15, 12, 0, seconds++),
        );

        try {
          _ProbeShape? lastPersisted;
          for (final shape in steps) {
            localProbe
              ..platform = shape.platform
              ..capabilities = List<NodeCapability>.from(shape.capabilities);

            final broadcast = await localBroadcaster.broadcastIfChanged();

            // The invariant: a broadcast is issued exactly when the probed
            // content differs from whatever was last persisted (displayName is
            // carried forward by the broadcaster, so only platform/capabilities
            // vary here).
            final expectedChange =
                lastPersisted == null || !lastPersisted.contentEquals(shape);
            expect(
              broadcast,
              expectedChange,
              reason:
                  'shape=$shape lastPersisted=$lastPersisted '
                  'broadcast=$broadcast',
            );

            // On a broadcast the new content becomes the persisted baseline;
            // on a no-op the baseline is unchanged.
            if (broadcast) lastPersisted = shape;
          }

          // Final cross-check against the actual persisted row.
          final self = await localRepo.getSelf();
          if (lastPersisted != null) {
            expect(self?.platform, lastPersisted.platform);
            expect(self?.capabilities, lastPersisted.capabilities);
          }
        } finally {
          await localRepo.dispose();
          await db.close();
        }
      },
      tags: 'glados',
    );
  });
}

/// One probed snapshot used by the diff-invariant Glados property: the
/// dimensions the broadcaster actually diffs on in these runs.
class _ProbeShape {
  const _ProbeShape({required this.platform, required this.capabilities});

  final String platform;
  final List<NodeCapability> capabilities;

  bool contentEquals(_ProbeShape other) {
    if (platform != other.platform) return false;
    if (capabilities.length != other.capabilities.length) return false;
    for (var i = 0; i < capabilities.length; i++) {
      if (capabilities[i] != other.capabilities[i]) return false;
    }
    return true;
  }

  @override
  String toString() => '_ProbeShape(platform=$platform, caps=$capabilities)';
}

extension _AnyProbeSequence on glados.Any {
  glados.Generator<List<NodeCapability>> get capabilityList =>
      glados.ListAnys(this).list(
        glados.AnyUtils(this).choose(NodeCapability.values),
      );

  glados.Generator<_ProbeShape> get probeShape =>
      glados.CombinableAny(this).combine2(
        glados.AnyUtils(this).choose(const ['macos', 'linux', 'ios']),
        capabilityList,
        (String platform, List<NodeCapability> caps) =>
            _ProbeShape(platform: platform, capabilities: caps),
      );

  glados.Generator<List<_ProbeShape>> get probeSequence =>
      glados.ListAnys(this).nonEmptyList(probeShape);
}
