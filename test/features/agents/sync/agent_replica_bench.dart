import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    show AgentDatabase;
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';

import '../agent_test_device.dart';

/// One message a device's outbox sent: an agent entity or an agent link.
typedef ReplicaWrite = ({String from, SyncMessage message});

/// The devices of a model-conformance trace and the writes they exchange.
///
/// Every write a device commits reaches every other device as its own sync
/// message, in whatever order the trace delivers it; a message is never
/// lost, only delayed — the outbox is durable. This is the network of the
/// TLA+ models in `specs/tla/` that replicate agent entities. Each device is
/// an [AgentTestDevice]; this adds the addressing: who has received what,
/// and when it was sent.
class ReplicaNetwork {
  final replicas = <AgentReplica>[];
  final sent = <ReplicaWrite>[];

  /// When each write in [sent] was sent, on the ambient `clock`.
  final sentAt = <DateTime>[];

  /// Adds a device whose store is a fresh in-memory agent database, on the
  /// test's own isolate so a trace can run under `fakeAsync`.
  AgentReplica join(String host) {
    final replica = AgentReplica._(host, this);
    replicas.add(replica);
    return replica;
  }

  /// Indices into [sent] still to be delivered to [to].
  List<int> pendingFor(AgentReplica to) => [
    for (var i = 0; i < sent.length; i++)
      if (sent[i].from != to.host && !to.received.contains(i)) i,
  ];

  /// Every device has received every write.
  bool get quiescent => replicas.every((r) => pendingFor(r).isEmpty);

  /// Delivers everything, each device in its own order: the even-numbered
  /// devices oldest first, the odd-numbered newest first.
  Future<void> deliverAll() async {
    while (!quiescent) {
      for (final (i, replica) in replicas.indexed) {
        final pending = pendingFor(replica);
        for (final index in i.isOdd ? pending.reversed : pending) {
          await replica.receive(index);
        }
      }
    }
  }

  Future<void> close() async {
    for (final replica in replicas) {
      await replica.device.close();
    }
  }
}

/// One device of a [ReplicaNetwork]: an [AgentTestDevice] whose accepted
/// messages go onto the network.
class AgentReplica {
  AgentReplica._(this.host, this.network) {
    device = AgentTestDevice(
      host,
      background: false,
      onSent: (message) {
        network.sent.add((from: host, message: message));
        network.sentAt.add(clock.now());
      },
    );
  }

  final String host;
  final ReplicaNetwork network;
  late final AgentTestDevice device;

  AgentDatabase get db => device.db;
  AgentRepository get repository => device.repository;
  AgentSyncService get syncService => device.sync;

  /// Indices into [ReplicaNetwork.sent] this device has received.
  final received = <int>{};

  /// A process death and restart over the same database.
  void reboot() => device.reboot();

  /// The receive path for one write ([AgentTestDevice.receiveEntity] or
  /// [AgentTestDevice.receiveLink]).
  Future<void> receive(int index) async {
    received.add(index);
    final message = network.sent[index].message;
    final entity = message.mapOrNull(agentEntity: (m) => m.agentEntity);
    final link = message.mapOrNull(agentLink: (m) => m.agentLink);
    if (entity != null) {
      await device.receiveEntity(entity);
    } else if (link != null) {
      await device.receiveLink(link);
    }
  }
}
