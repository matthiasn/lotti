import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'constants.dart';
import 'template_factories.dart';
import 'wake_factories.dart';

// ── Evolution entity factories ────────────────────────────────────────────────

EvolutionSessionEntity makeTestEvolutionSession({
  String id = 'evo-session-001',
  String agentId = kTestTemplateId,
  String templateId = kTestTemplateId,
  int sessionNumber = 1,
  EvolutionSessionStatus status = EvolutionSessionStatus.active,
  DateTime? createdAt,
  DateTime? updatedAt,
  VectorClock? vectorClock,
  String? proposedVersionId,
  String? feedbackSummary,
  double? userRating,
  DateTime? completedAt,
}) {
  return AgentDomainEntity.evolutionSession(
        id: id,
        agentId: agentId,
        templateId: templateId,
        sessionNumber: sessionNumber,
        status: status,
        createdAt: createdAt ?? kAgentTestDate,
        updatedAt: updatedAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        proposedVersionId: proposedVersionId,
        feedbackSummary: feedbackSummary,
        userRating: userRating,
        completedAt: completedAt,
      )
      as EvolutionSessionEntity;
}

EvolutionNoteEntity makeTestEvolutionNote({
  String id = 'evo-note-001',
  String agentId = kTestTemplateId,
  String sessionId = 'evo-session-001',
  EvolutionNoteKind kind = EvolutionNoteKind.reflection,
  DateTime? createdAt,
  VectorClock? vectorClock,
  String content = 'Test evolution note.',
}) {
  return AgentDomainEntity.evolutionNote(
        id: id,
        agentId: agentId,
        sessionId: sessionId,
        kind: kind,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        content: content,
      )
      as EvolutionNoteEntity;
}

EvolutionSessionRecapEntity makeTestEvolutionSessionRecap({
  String id = 'evo-recap-001',
  String agentId = kTestTemplateId,
  String sessionId = 'evo-session-001',
  DateTime? createdAt,
  VectorClock? vectorClock,
  String tldr = 'Short recap',
  String recapMarkdown = '## Recap\n\n- Updated directive tone',
  Map<String, int> categoryRatings = const {
    'language': 4,
  },
  List<Map<String, String>> transcript = const [
    {
      'role': 'assistant',
      'text': 'What bothered you most?',
    },
  ],
  String? approvedChangeSummary = '- Rewrote the opening prompt',
}) {
  return AgentDomainEntity.evolutionSessionRecap(
        id: id,
        agentId: agentId,
        sessionId: sessionId,
        createdAt: createdAt ?? kAgentTestDate,
        vectorClock: vectorClock,
        tldr: tldr,
        recapMarkdown: recapMarkdown,
        categoryRatings: categoryRatings,
        transcript: transcript,
        approvedChangeSummary: approvedChangeSummary,
      )
      as EvolutionSessionRecapEntity;
}

// ── Evolution data bundle factory ───────────────────────────────────────────

EvolutionDataBundle makeTestEvolutionDataBundle({
  TemplatePerformanceMetrics? metrics,
  List<AgentTemplateVersionEntity>? recentVersions,
  List<AgentReportEntity>? instanceReports,
  List<AgentMessageEntity>? instanceObservations,
  List<EvolutionNoteEntity>? pastNotes,
  List<EvolutionSessionEntity>? sessions,
  Map<String, AgentMessagePayloadEntity>? observationPayloads,
  int changesSinceLastSession = 0,
}) {
  return EvolutionDataBundle(
    metrics: metrics ?? makeTestMetrics(),
    recentVersions: recentVersions ?? [makeTestTemplateVersion()],
    instanceReports: instanceReports ?? [],
    instanceObservations: instanceObservations ?? [],
    pastNotes: pastNotes ?? [],
    sessions: sessions ?? [],
    observationPayloads: observationPayloads ?? {},
    changesSinceLastSession: changesSinceLastSession,
  );
}
