import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/shadow_projection.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';

const _agentId = 'agent-1';

/// A mocktail `AgentRepository` backed by real in-memory maps, so the
/// `AgentSyncService` append path (head read → chain → head advance) behaves
/// across multiple appends exactly as it would against the database. This is
/// the only way to test that the edges the append path *writes* reproduce the
/// head it *maintains* when fed back through the projection kernel.
class _InMemoryAgentRepository extends MockAgentRepository {
  final Map<String, AgentDomainEntity> _entities = {};
  final Map<String, AgentLink> _links = {};

  /// All persisted messages (the projection's event source).
  List<AgentMessageEntity> get messages =>
      _entities.values.whereType<AgentMessageEntity>().toList();

  /// All persisted links (the projection reads `messagePrev` edges from these).
  List<AgentLink> get links => _links.values.toList();

  AgentMessageEntity message(String id) => _entities[id]! as AgentMessageEntity;

  AgentLink link(String id) => _links[id]!;

  void seed({
    Iterable<AgentDomainEntity> entities = const [],
    Iterable<AgentLink> links = const [],
  }) {
    for (final entity in entities) {
      _entities[entity.id] = entity;
    }
    for (final link in links) {
      _links[link.id] = link;
    }
  }

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();

  @override
  Future<void> upsertEntity(AgentDomainEntity entity) async {
    _entities[entity.id] = entity;
  }

  @override
  Future<void> upsertLink(AgentLink link) async {
    _links[link.id] = link;
  }

  @override
  Future<AgentDomainEntity?> getEntity(String id) async => _entities[id];

  @override
  Future<AgentStateEntity?> getAgentState(String agentId) async {
    final states = _entities.values
        .whereType<AgentStateEntity>()
        .where((s) => s.agentId == agentId)
        .toList();
    // Exactly one state per agent — `.single` fails fast if a test seeds two.
    return states.isEmpty ? null : states.single;
  }

  @override
  Future<List<AgentMessageEntity>> getAgentMessages(String agentId) async {
    return _entities.values
        .whereType<AgentMessageEntity>()
        .where((m) => m.agentId == agentId)
        .toList();
  }
}

/// One simulated device: a real [AgentSyncService] over its own in-memory
/// store, stamping single-host vector clocks for [host].
class _Device {
  _Device(this.host) {
    final vc = MockVectorClockService();
    var counter = 0;
    when(
      () => vc.getNextVectorClock(previous: any(named: 'previous')),
    ).thenAnswer((_) async => VectorClock({host: ++counter}));
    final outbox = MockOutboxService();
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    sync = AgentSyncService(
      repository: repo,
      outboxService: outbox,
      vectorClockService: vc,
    );
  }

  final String host;
  final _InMemoryAgentRepository repo = _InMemoryAgentRepository();
  late final AgentSyncService sync;

  /// Appends a message through the real causal-DAG append path. The projection
  /// orders by edges + id, so `createdAt` is irrelevant and left at default.
  Future<void> append(String id) =>
      sync.upsertEntity(makeTestMessage(id: id, agentId: _agentId));

  Future<String?> liveHead() async =>
      (await repo.getAgentState(_agentId))?.recentHeadMessageId;
}

/// The shadow report over the union of every device's persisted log — what all
/// devices converge to once fully synced. Value-equal duplicates (the shared
/// prefix held by several repos, plus content-addressed `messagePrev` links)
/// collapse harmlessly in `canonicalOrder`, so no manual dedup is needed.
ShadowProjectionReport _unionReport(
  List<_InMemoryAgentRepository> repos,
  String? liveHeadId,
) => compareShadowProjection(
  messages: repos.expand((r) => r.messages),
  links: repos.expand((r) => r.links),
  liveHeadId: liveHeadId,
);

void main() {
  setUpAll(registerAllFallbackValues);

  /// A device with a fresh, head-less state row (a brand-new agent).
  _Device freshDevice(String host) =>
      _Device(host)..repo.seed(entities: [makeTestState(agentId: _agentId)]);

  /// Two devices that share the prefix m1 ← m2 and have each appended a
  /// concurrent child off the shared head m2 (deviceA → mA, deviceB → mB).
  Future<(_Device, _Device)> forkedPair() async {
    final deviceA = freshDevice('A');
    await deviceA.append('m1');
    await deviceA.append('m2'); // shared head = m2

    // Device B holds the same prefix and head (received via sync).
    final deviceB = _Device('B')
      ..repo.seed(
        entities: [
          ...deviceA.repo.messages,
          makeTestState(agentId: _agentId).copyWith(recentHeadMessageId: 'm2'),
        ],
        links: deviceA.repo.links,
      );

    await deviceA.append('mA');
    await deviceB.append('mB');
    return (deviceA, deviceB);
  }

  /// Delivers [messageId] and its `messagePrev` link from [from] to [to]
  /// through the raw sync path — what cross-device sync does on receipt.
  Future<void> deliver(_Device from, _Device to, String messageId) async {
    await to.sync.upsertEntity(from.repo.message(messageId), fromSync: true);
    await to.sync.upsertLink(
      from.repo.link('msgprev-$messageId'),
      fromSync: true,
    );
  }

  group('append path → shadow projection (integration)', () {
    test(
      'a forward corpus projects to a single head equal to the live '
      'head — the edges the append path writes reproduce live state',
      () async {
        final device = freshDevice('A');
        await device.append('m1');
        await device.append('m2');
        await device.append('m3');

        final liveHead = await device.liveHead();
        expect(liveHead, 'm3');

        final report = compareShadowProjection(
          messages: device.repo.messages,
          links: device.repo.links,
          liveHeadId: liveHead,
        );
        expect(report.status, ShadowProjectionStatus.match);
        expect(report.projectedHeadIds, ['m3']);

        // The persisted spine is m1(root) ← m2 ← m3.
        expect(device.repo.message('m1').prevMessageId, isNull);
        expect(device.repo.message('m2').prevMessageId, 'm1');
        expect(device.repo.message('m3').prevMessageId, 'm2');
      },
    );

    test('two devices appending off a shared head fork; the projection '
        'reports both tips while live state tracks one (R2)', () async {
      final (deviceA, deviceB) = await forkedPair();

      expect(deviceA.repo.message('mA').prevMessageId, 'm2');
      expect(deviceB.repo.message('mB').prevMessageId, 'm2');
      expect(await deviceA.liveHead(), 'mA');
      expect(await deviceB.liveHead(), 'mB');

      // The union projection sees the fork; live state names one of the tips.
      final repos = [deviceA.repo, deviceB.repo];
      final report = _unionReport(repos, 'mA');
      expect(report.status, ShadowProjectionStatus.forked);
      expect(report.projectedHeadIds.toSet(), {'mA', 'mB'});
      // Either tip is the expected divergence, not a mismatch.
      expect(_unionReport(repos, 'mB').status, ShadowProjectionStatus.forked);
    });

    test('after cross-syncing both appends, both devices converge to the '
        'same fork heads', () async {
      final (deviceA, deviceB) = await forkedPair();

      // Sync delivers each device's message + link to the other (raw path —
      // no re-stamp, no re-chaining), in opposite orders.
      await deliver(deviceB, deviceA, 'mB');
      await deliver(deviceA, deviceB, 'mA');

      final headsA = compareShadowProjection(
        messages: deviceA.repo.messages,
        links: deviceA.repo.links,
        liveHeadId: 'mA',
      );
      final headsB = compareShadowProjection(
        messages: deviceB.repo.messages,
        links: deviceB.repo.links,
        liveHeadId: 'mB',
      );
      expect(headsA.projectedHeadIds.toSet(), {'mA', 'mB'});
      expect(headsB.projectedHeadIds.toSet(), {'mA', 'mB'});
      // Convergence: independent of which device applied which event first.
      expect(headsA.projectedHeadIds.toSet(), headsB.projectedHeadIds.toSet());
    });

    test('re-applying a synced message + its content-addressed link is '
        'idempotent — no duplicate-id projection error', () async {
      final (deviceA, deviceB) = await forkedPair();

      // Deliver mB twice (a duplicate sync round-trip).
      await deliver(deviceB, deviceA, 'mB');
      await deliver(deviceB, deviceA, 'mB');

      final report = compareShadowProjection(
        messages: deviceA.repo.messages,
        links: deviceA.repo.links,
        liveHeadId: 'mA',
      );
      expect(report.status, ShadowProjectionStatus.forked);
      expect(report.projectedHeadIds.toSet(), {'mA', 'mB'});
    });
  });

  group('append path → shadow projection — properties', () {
    glados.Glados(
      glados.IntAnys(glados.any).intInRange(1, 16), // chain length 1..15
      glados.ExploreConfig(numRuns: 60),
    ).test(
      'any forward corpus projects to one head equal to the live head',
      (n) async {
        final device = freshDevice('A');
        for (var i = 0; i < n; i++) {
          await device.append('m$i');
        }

        final liveHead = await device.liveHead();
        final report = compareShadowProjection(
          messages: device.repo.messages,
          links: device.repo.links,
          liveHeadId: liveHead,
        );

        expect(liveHead, 'm${n - 1}', reason: 'n=$n');
        expect(report.status, ShadowProjectionStatus.match, reason: 'n=$n');
        expect(report.projectedHeadIds, ['m${n - 1}'], reason: 'n=$n');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.IntAnys(glados.any).intInRange(1, 16), // fork width 1..15
      glados.ExploreConfig(numRuns: 60),
    ).test(
      'W concurrent appends off one head yield exactly the W appended tips',
      (width) async {
        // Build the shared root m0 through the real (root) append path.
        final root = freshDevice('A');
        await root.append('m0');
        final prefixMessages = root.repo.messages;
        final prefixLinks = root.repo.links;

        final repos = <_InMemoryAgentRepository>[];
        final childIds = <String>{};
        for (var i = 0; i < width; i++) {
          final device = _Device('D$i')
            ..repo.seed(
              entities: [
                ...prefixMessages,
                makeTestState(
                  agentId: _agentId,
                ).copyWith(recentHeadMessageId: 'm0'),
              ],
              links: prefixLinks,
            );
          await device.append('c$i');
          childIds.add('c$i');
          repos.add(device.repo);
        }

        // Live state tracks one tip (c0); the projection must surface all tips.
        final report = _unionReport(repos, 'c0');
        expect(report.projectedHeadIds.toSet(), childIds, reason: 'w=$width');
        expect(
          report.status,
          width > 1
              ? ShadowProjectionStatus.forked
              : ShadowProjectionStatus.match,
          reason: 'w=$width',
        );
      },
      tags: 'glados',
    );
  });
}
