import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/features/agents/service/agent_template_crud.dart';
import 'package:lotti/features/agents/service/agent_template_seeding.dart';
import 'package:lotti/features/agents/service/soul_template_ops.dart';
import 'package:lotti/features/agents/service/soul_version_ops.dart';

import '../../../mocks/mocks.dart';
import '../agent_test_device.dart';

/// The default seeding and the user's template and soul operations, wired
/// as the app wires them, over one [AgentTestDevice]'s real repository and
/// sync service. The collaborators are built on every access, so a
/// [AgentTestDevice.reboot] is picked up.
class DefaultSeedingDevice {
  DefaultSeedingDevice(this.device);

  final AgentTestDevice device;

  AgentTemplateCrud get templates => AgentTemplateCrud(
    domainLogger: MockDomainLogger(),
    repository: device.repository,
    syncService: device.sync,
  );

  SoulVersionOps get souls => SoulVersionOps(
    domainLogger: MockDomainLogger(),
    repository: device.repository,
    syncService: device.sync,
  );

  SoulTemplateOps get soulAssignments => SoulTemplateOps(
    domainLogger: MockDomainLogger(),
    repository: device.repository,
    syncService: device.sync,
    versionOps: souls,
  );

  /// What the app seeds at every start (`agentInitializationProvider`): the
  /// default templates, then the default souls and their assignments.
  Future<void> start() async {
    await AgentTemplateSeeding(
      domainLogger: MockDomainLogger(),
      syncService: device.sync,
      crud: templates,
    ).seedDefaults();
    await soulAssignments.seedDefaults();
  }

  /// The row stored under [id], a tombstone included.
  Future<AgentDomainEntity?> stored(String id) =>
      device.repository.getEntityIncludingDeleted(id);

  /// The link stored under [id], a tombstone included.
  Future<AgentLink?> storedLink(String id) =>
      device.repository.getLinkByIdIncludingDeleted(id);

  /// Receives everything [from] has sent, in the order it was sent.
  Future<void> receiveAllFrom(DefaultSeedingDevice from) async {
    for (final message in from.device.sent) {
      final entity = message.mapOrNull(agentEntity: (m) => m.agentEntity);
      final link = message.mapOrNull(agentLink: (m) => m.agentLink);
      if (entity != null) await device.receiveEntity(entity);
      if (link != null) await device.receiveLink(link);
    }
  }
}
