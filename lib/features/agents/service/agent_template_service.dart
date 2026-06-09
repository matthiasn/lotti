import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

part 'agent_template_crud.dart';
part 'agent_template_metrics.dart';
part 'agent_template_seeding.dart';

const _uuid = Uuid();

/// Thrown when a template cannot be deleted because active agents reference it.
class TemplateInUseException implements Exception {
  const TemplateInUseException({
    required this.templateId,
    required this.activeCount,
  });

  final String templateId;
  final int activeCount;

  @override
  String toString() =>
      'TemplateInUseException: cannot delete template $templateId — '
      '$activeCount active instance(s)';
}

/// Bundled result of [AgentTemplateService.gatherEvolutionData].
///
/// Contains all data needed to build an evolution session context, fetched
/// in parallel for efficiency.
class EvolutionDataBundle {
  const EvolutionDataBundle({
    required this.metrics,
    required this.recentVersions,
    required this.instanceReports,
    required this.instanceObservations,
    required this.pastNotes,
    required this.sessions,
    required this.observationPayloads,
    required this.changesSinceLastSession,
  });

  final TemplatePerformanceMetrics metrics;
  final List<AgentTemplateVersionEntity> recentVersions;
  final List<AgentReportEntity> instanceReports;
  final List<AgentMessageEntity> instanceObservations;
  final List<EvolutionNoteEntity> pastNotes;
  final List<EvolutionSessionEntity> sessions;
  final Map<String, AgentMessagePayloadEntity> observationPayloads;
  final int changesSinceLastSession;

  /// Compute the next session number from the existing sessions.
  int get nextSessionNumber =>
      sessions.fold(
        0,
        (max, s) => s.sessionNumber > max ? s.sessionNumber : max,
      ) +
      1;
}

/// Well-known template IDs for seeded defaults.
const lauraTemplateId = 'template-laura-001';
const tomTemplateId = 'template-tom-001';
const dayAgentTemplateId = 'template-day-agent-001';
const projectTemplateId = 'template-project-001';
const improverTemplateId = 'template-improver-001';
const metaImproverTemplateId = 'template-meta-improver-001';
const kDefaultAgentTemplateModelId = 'models/gemini-3-flash-preview';

abstract class _AgentTemplateServiceBase {
  _AgentTemplateServiceBase({
    required this.repository,
    required this.syncService,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;
}

/// High-level service for agent template management.
///
/// Provides operations for creating, versioning, listing, and managing
/// agent templates — reusable blueprints that define an agent's directives,
/// model, and category bindings.
class AgentTemplateService extends _AgentTemplateServiceBase
    with _AgentTemplateCrud, _AgentTemplateMetrics, _AgentTemplateSeeding {
  AgentTemplateService({
    required super.repository,
    required super.syncService,
  });
}
