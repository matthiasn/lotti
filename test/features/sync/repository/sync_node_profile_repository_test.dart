import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/repository/sync_node_profile_repository.dart';

void main() {
  late SettingsDb settingsDb;
  late SyncNodeProfileRepository repo;

  final t0 = DateTime.utc(2026, 3, 15, 12);
  final t1 = DateTime.utc(2026, 3, 15, 13);
  final t2 = DateTime.utc(2026, 3, 15, 14);

  SyncNodeProfile makeProfile({
    required String hostId,
    required DateTime updatedAt,
    String displayName = 'Node',
    List<NodeCapability> capabilities = const [NodeCapability.mlxAudio],
  }) {
    return SyncNodeProfile(
      hostId: hostId,
      displayName: displayName,
      platform: 'macos',
      capabilities: capabilities,
      updatedAt: updatedAt,
    );
  }

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    settingsDb = SettingsDb(inMemoryDatabase: true);
    repo = SyncNodeProfileRepository(settingsDb: settingsDb);
  });

  tearDown(() async {
    await repo.dispose();
    await settingsDb.close();
  });

  group('self profile', () {
    test('getSelf returns null before anything is written', () async {
      expect(await repo.getSelf(), isNull);
    });

    test('setSelf then getSelf round-trips the profile', () async {
      final profile = makeProfile(
        hostId: 'self-host',
        updatedAt: t0,
        displayName: 'Studio Mac',
        capabilities: const [
          NodeCapability.mlxAudio,
          NodeCapability.ollamaLlm,
        ],
      );

      await repo.setSelf(profile);
      final restored = await repo.getSelf();

      expect(restored, profile);
    });

    test('setSelf overwrites a previously written profile', () async {
      await repo.setSelf(makeProfile(hostId: 'h', updatedAt: t0));
      await repo.setSelf(
        makeProfile(
          hostId: 'h',
          updatedAt: t1,
          displayName: 'Renamed',
        ),
      );

      final restored = await repo.getSelf();
      expect(restored?.displayName, 'Renamed');
      expect(restored?.updatedAt, t1);
    });
  });

  group('directory upsert', () {
    test('upsertNode adds an unknown host and returns true', () async {
      final profile = makeProfile(hostId: 'peer-1', updatedAt: t0);
      final changed = await repo.upsertNode(profile);

      expect(changed, isTrue);
      expect(await repo.getNode('peer-1'), profile);
      expect(await repo.listKnownNodes(), [profile]);
    });

    test('upsertNode with newer updatedAt replaces existing entry', () async {
      await repo.upsertNode(
        makeProfile(hostId: 'peer-1', updatedAt: t0, displayName: 'Old'),
      );
      final newer = makeProfile(
        hostId: 'peer-1',
        updatedAt: t1,
        displayName: 'New',
      );

      final changed = await repo.upsertNode(newer);

      expect(changed, isTrue);
      expect((await repo.getNode('peer-1'))?.displayName, 'New');
    });

    test(
      'upsertNode with older updatedAt is dropped (last-write-wins)',
      () async {
        await repo.upsertNode(
          makeProfile(hostId: 'peer-1', updatedAt: t1, displayName: 'New'),
        );
        final stale = makeProfile(
          hostId: 'peer-1',
          updatedAt: t0,
          displayName: 'Old',
        );

        final changed = await repo.upsertNode(stale);

        expect(changed, isFalse);
        expect((await repo.getNode('peer-1'))?.displayName, 'New');
      },
    );

    test('upsertNode with identical content returns false', () async {
      final profile = makeProfile(hostId: 'peer-1', updatedAt: t0);
      await repo.upsertNode(profile);

      final changed = await repo.upsertNode(profile);

      expect(changed, isFalse);
    });

    test('upsertNode preserves other peers when updating one', () async {
      await repo.upsertNode(makeProfile(hostId: 'peer-1', updatedAt: t0));
      await repo.upsertNode(
        makeProfile(hostId: 'peer-2', updatedAt: t0, displayName: 'Other'),
      );

      await repo.upsertNode(
        makeProfile(
          hostId: 'peer-1',
          updatedAt: t1,
          displayName: 'Peer 1 renamed',
        ),
      );

      final nodes = await repo.listKnownNodes();
      expect(nodes, hasLength(2));
      expect(
        nodes.firstWhere((p) => p.hostId == 'peer-1').displayName,
        'Peer 1 renamed',
      );
      expect(
        nodes.firstWhere((p) => p.hostId == 'peer-2').displayName,
        'Other',
      );
    });
  });

  group('directory listing', () {
    test(
      'listKnownNodes returns profiles sorted by displayName then hostId',
      () async {
        await repo.upsertNode(
          makeProfile(hostId: 'a', updatedAt: t0, displayName: 'Zeta'),
        );
        await repo.upsertNode(
          makeProfile(hostId: 'b', updatedAt: t0, displayName: 'alpha'),
        );
        await repo.upsertNode(
          makeProfile(hostId: 'c', updatedAt: t0, displayName: 'alpha'),
        );

        final names = (await repo.listKnownNodes())
            .map((p) => '${p.displayName}/${p.hostId}')
            .toList();

        expect(names, ['alpha/b', 'alpha/c', 'Zeta/a']);
      },
    );

    test('listKnownNodes returns empty list when directory is empty', () async {
      expect(await repo.listKnownNodes(), isEmpty);
    });
  });

  group('removeNode', () {
    test('removeNode deletes an existing entry and returns true', () async {
      await repo.upsertNode(makeProfile(hostId: 'peer-1', updatedAt: t0));

      final removed = await repo.removeNode('peer-1');

      expect(removed, isTrue);
      expect(await repo.getNode('peer-1'), isNull);
    });

    test('removeNode on unknown host returns false', () async {
      expect(await repo.removeNode('unknown'), isFalse);
    });
  });

  group('watchKnownNodes', () {
    test('emits the updated directory on upsert', () async {
      final emissions = <List<SyncNodeProfile>>[];
      final sub = repo.watchKnownNodes().listen(emissions.add);

      await repo.upsertNode(makeProfile(hostId: 'peer-1', updatedAt: t0));
      await repo.upsertNode(makeProfile(hostId: 'peer-2', updatedAt: t1));
      await repo.upsertNode(
        makeProfile(
          hostId: 'peer-1',
          updatedAt: t2,
          displayName: 'Renamed',
        ),
      );

      // Give pending async writes time to settle through SettingsDb.
      await pumpEventQueue();

      expect(emissions, hasLength(3));
      expect(
        emissions.last.map((p) => p.hostId),
        containsAll(['peer-1', 'peer-2']),
      );
      expect(
        emissions.last.firstWhere((p) => p.hostId == 'peer-1').displayName,
        'Renamed',
      );

      await sub.cancel();
    });

    test('does not emit on stale upsert', () async {
      await repo.upsertNode(makeProfile(hostId: 'peer-1', updatedAt: t1));

      final emissions = <List<SyncNodeProfile>>[];
      final sub = repo.watchKnownNodes().listen(emissions.add);

      // Stale: older updatedAt
      final stale = makeProfile(hostId: 'peer-1', updatedAt: t0);
      final changed = await repo.upsertNode(stale);

      await pumpEventQueue();

      expect(changed, isFalse);
      expect(emissions, isEmpty);
      await sub.cancel();
    });
  });

  group('persistence across instances', () {
    test(
      'a fresh repository sees previously-written directory entries',
      () async {
        await repo.upsertNode(makeProfile(hostId: 'peer-1', updatedAt: t0));
        await repo.upsertNode(
          makeProfile(hostId: 'peer-2', updatedAt: t0, displayName: 'Other'),
        );
        await repo.dispose();

        final second = SyncNodeProfileRepository(settingsDb: settingsDb);
        addTearDown(second.dispose);

        final nodes = await second.listKnownNodes();
        expect(nodes.map((p) => p.hostId), containsAll(['peer-1', 'peer-2']));
      },
    );
  });

  group('glados: directory state machine', () {
    glados.Glados(
      glados.any.directoryOperationList,
      glados.ExploreConfig(numRuns: 60),
    ).test(
      'directory converges to per-hostId max-updatedAt snapshot; stream '
      'emits once per actual change',
      (operations) async {
        // Fresh repo per run — glados reuses the test binding across runs,
        // so we explicitly dispose at the end of each iteration instead of
        // using addTearDown (which only fires after every iteration completes
        // and would leak handles across runs).
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        final settingsDb2 = SettingsDb(inMemoryDatabase: true);
        final repo2 = SyncNodeProfileRepository(settingsDb: settingsDb2);

        // Reference model: replays operations using only the lwww rule.
        // The repository must match this exactly.
        final expected = <String, SyncNodeProfile>{};

        // Subscribe BEFORE issuing operations so we observe every emission.
        final emissions = <List<SyncNodeProfile>>[];
        final sub = repo2.watchKnownNodes().listen(emissions.add);
        var expectedEmissionCount = 0;

        for (final op in operations) {
          switch (op) {
            case _Upsert():
              final profile = SyncNodeProfile(
                hostId: op.hostId,
                displayName: op.displayName,
                platform: 'macos',
                capabilities: const [NodeCapability.mlxAudio],
                updatedAt: op.updatedAt,
              );
              final existing = expected[op.hostId];
              // Mirror the repository's predicate exactly: write iff the
              // existing snapshot is null, OR the incoming updatedAt is not
              // older than the existing one AND content differs.
              final wouldChange =
                  existing == null ||
                  (!existing.updatedAt.isAfter(profile.updatedAt) &&
                      existing != profile);
              final returned = await repo2.upsertNode(profile);

              if (wouldChange) {
                expected[op.hostId] = profile;
                expect(returned, isTrue, reason: 'upsert $op');
                expectedEmissionCount++;
              } else {
                expect(returned, isFalse, reason: 'stale or identical $op');
              }
            case _Remove():
              final wasPresent = expected.containsKey(op.hostId);
              final returned = await repo2.removeNode(op.hostId);
              expect(returned, wasPresent, reason: 'remove $op');
              if (wasPresent) {
                expected.remove(op.hostId);
                expectedEmissionCount++;
              }
          }
        }

        await pumpEventQueue();

        // Property 1: directory matches the model.
        final actual = await repo2.listKnownNodes();
        final actualById = {for (final p in actual) p.hostId: p};
        expect(
          actualById.keys.toSet(),
          expected.keys.toSet(),
          reason: 'host set mismatch for $operations',
        );
        for (final hostId in expected.keys) {
          expect(
            actualById[hostId],
            expected[hostId],
            reason: 'profile mismatch for $hostId in $operations',
          );
        }

        // Property 2: exactly one stream emission per actual mutation.
        expect(
          emissions.length,
          expectedEmissionCount,
          reason:
              'expected $expectedEmissionCount emissions but got '
              '${emissions.length} for $operations',
        );

        await sub.cancel();
        await repo2.dispose();
        await settingsDb2.close();
      },
      tags: 'glados',
    );
  });
}

// ---------------------------------------------------------------------------
// Glados scenario types for the directory state machine.
// ---------------------------------------------------------------------------

sealed class _DirOp {
  const _DirOp();
  String get hostId;
}

class _Upsert extends _DirOp {
  const _Upsert({
    required this.hostId,
    required this.displayName,
    required this.updatedAt,
  });
  @override
  final String hostId;
  final String displayName;
  final DateTime updatedAt;

  @override
  String toString() => 'Upsert($hostId, "$displayName", $updatedAt)';
}

class _Remove extends _DirOp {
  const _Remove(this.hostId);
  @override
  final String hostId;

  @override
  String toString() => 'Remove($hostId)';
}

const _hosts = ['A', 'B', 'C'];
final _times = [
  DateTime.utc(2026, 3, 15, 10),
  DateTime.utc(2026, 3, 15, 11),
  DateTime.utc(2026, 3, 15, 12),
];
const _names = ['alpha', 'beta', 'gamma'];

extension _AnyDirectoryOp on glados.Any {
  glados.Generator<_DirOp> get directoryOperation =>
      glados.CombinableAny(this).combine4(
        glados.AnyUtils(this).choose(_hosts),
        glados.AnyUtils(this).choose(_names),
        glados.AnyUtils(this).choose(_times),
        glados.BoolAny(this).bool,
        (
          String hostId,
          String name,
          DateTime t,
          bool isUpsert,
        ) => isUpsert
            ? _Upsert(hostId: hostId, displayName: name, updatedAt: t)
            : _Remove(hostId),
      );

  glados.Generator<List<_DirOp>> get directoryOperationList =>
      glados.ListAnys(this).listWithLengthInRange(0, 12, directoryOperation);
}
