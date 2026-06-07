/// Glados generator scaffolding for `agent_repository_test.dart`.
///
/// Extracted from the test file so the ~1 900 lines of scenario classes,
/// enums, and `Any` extensions no longer dwarf the test logic. This is a
/// helper library, not a test file (no `main()`), so the
/// one-test-file-per-source rule is unaffected.
library;

import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

enum GeneratedIntervalEntityKind { agent, state }

enum GeneratedReportAgentSlot { target, other }

enum GeneratedReportScopeSlot { target, other }

enum GeneratedPrimaryProjectSlot { target, other }

enum GeneratedPrimaryTaskSlot { first, second, other }

enum GeneratedPrimaryReportState {
  noActiveHead,
  missingReport,
  deletedReport,
  emptyReport,
  usableReport,
}

enum GeneratedBatchLinkKind { agentTask, basic }

enum GeneratedBatchTaskSlot { first, second, other }

enum GeneratedBatchRequestedTaskSlot { first, second, other, missing }

enum GeneratedWakeTemplateShape { target, other, none }

enum GeneratedTemplateSlot { target, other }

class GeneratedIntervalEntitySpec {
  const GeneratedIntervalEntitySpec({
    required this.kind,
    required this.offsetDays,
    required this.deleted,
    required this.seed,
  });

  final GeneratedIntervalEntityKind kind;
  final int offsetDays;
  final bool deleted;
  final int seed;

  String get id => 'generated-interval-$seed-$offsetDays-${kind.name}';

  String idAt(int index) => '$id-$index';

  String get agentId => 'generated-agent-$seed';

  DateTime get updatedAt => DateTime(2026, 3).add(Duration(days: offsetDays));

  bool isInside(DateTime start, DateTime end) {
    return !updatedAt.isBefore(start) && updatedAt.isBefore(end);
  }

  @override
  String toString() {
    return 'GeneratedIntervalEntitySpec('
        'kind: $kind, offsetDays: $offsetDays, '
        'deleted: $deleted, seed: $seed)';
  }
}

class GeneratedIntervalQueryScenario {
  const GeneratedIntervalQueryScenario({
    required this.specs,
    required this.pageSize,
  });

  final List<GeneratedIntervalEntitySpec> specs;
  final int pageSize;

  List<String> expectedIds(DateTime start, DateTime end) {
    return [
      for (var index = 0; index < specs.length; index++)
        if (specs[index].isInside(start, end)) specs[index].idAt(index),
    ];
  }

  List<String> expectedDeletedIds(DateTime start, DateTime end) {
    return [
      for (var index = 0; index < specs.length; index++)
        if (specs[index].deleted && specs[index].isInside(start, end))
          specs[index].idAt(index),
    ];
  }

  @override
  String toString() {
    return 'GeneratedIntervalQueryScenario('
        'pageSize: $pageSize, specs: $specs)';
  }
}

const String generatedReportTargetAgentId = 'generated-report-agent-target';
const String generatedReportOtherAgentId = 'generated-report-agent-other';
const String generatedReportTargetScope = AgentReportScopes.current;
const String generatedReportOtherScope = 'generated-report-other-scope';

class GeneratedReportSpec {
  const GeneratedReportSpec({
    required this.agentSlot,
    required this.scopeSlot,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final GeneratedReportAgentSlot agentSlot;
  final GeneratedReportScopeSlot scopeSlot;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-report-$index-$seed';

  String get agentId => switch (agentSlot) {
    GeneratedReportAgentSlot.target => generatedReportTargetAgentId,
    GeneratedReportAgentSlot.other => generatedReportOtherAgentId,
  };

  String get scope => switch (scopeSlot) {
    GeneratedReportScopeSlot.target => generatedReportTargetScope,
    GeneratedReportScopeSlot.other => generatedReportOtherScope,
  };

  DateTime createdAt(int index) {
    return DateTime(2026, 5, 4).add(
      Duration(minutes: createdMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;
  }

  String contentAt(int index) => 'generated report $index from seed $seed';

  @override
  String toString() {
    return 'GeneratedReportSpec('
        'agentSlot: $agentSlot, scopeSlot: $scopeSlot, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset, '
        'seed: $seed)';
  }
}

class GeneratedReportHeadSpec {
  const GeneratedReportHeadSpec({
    required this.agentSlot,
    required this.scopeSlot,
    required this.pointsToExisting,
    required this.reportOrdinal,
    required this.deleted,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final GeneratedReportAgentSlot agentSlot;
  final GeneratedReportScopeSlot scopeSlot;
  final bool pointsToExisting;
  final int reportOrdinal;
  final bool deleted;
  final int updatedMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-report-head-$index-$seed';

  String get agentId => switch (agentSlot) {
    GeneratedReportAgentSlot.target => generatedReportTargetAgentId,
    GeneratedReportAgentSlot.other => generatedReportOtherAgentId,
  };

  String get scope => switch (scopeSlot) {
    GeneratedReportScopeSlot.target => generatedReportTargetScope,
    GeneratedReportScopeSlot.other => generatedReportOtherScope,
  };

  DateTime updatedAt(int index) {
    return DateTime(2026, 5, 5).add(
      Duration(minutes: updatedMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? updatedAt(index).add(const Duration(minutes: 1)) : null;
  }

  String reportIdFor(GeneratedReportResolutionScenario scenario) {
    final matchingIndexes = scenario
        .reportIndexesFor(
          agentSlot,
          scopeSlot,
        )
        .toList();
    if (!pointsToExisting || matchingIndexes.isEmpty) {
      return 'generated-missing-report-$seed';
    }

    final reportIndex = matchingIndexes[reportOrdinal % matchingIndexes.length];
    return scenario.reports[reportIndex].idAt(reportIndex);
  }

  @override
  String toString() {
    return 'GeneratedReportHeadSpec('
        'agentSlot: $agentSlot, scopeSlot: $scopeSlot, '
        'pointsToExisting: $pointsToExisting, '
        'reportOrdinal: $reportOrdinal, deleted: $deleted, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class GeneratedReportResolutionScenario {
  const GeneratedReportResolutionScenario({
    required this.reports,
    required this.heads,
  });

  final List<GeneratedReportSpec> reports;
  final List<GeneratedReportHeadSpec> heads;

  Iterable<int> reportIndexesFor(
    GeneratedReportAgentSlot agentSlot,
    GeneratedReportScopeSlot scopeSlot,
  ) sync* {
    for (var index = 0; index < reports.length; index++) {
      if (reports[index].agentSlot == agentSlot &&
          reports[index].scopeSlot == scopeSlot) {
        yield index;
      }
    }
  }

  Iterable<int> headIndexesFor(
    GeneratedReportAgentSlot agentSlot,
    GeneratedReportScopeSlot scopeSlot,
  ) sync* {
    for (var index = 0; index < heads.length; index++) {
      if (heads[index].agentSlot == agentSlot &&
          heads[index].scopeSlot == scopeSlot) {
        yield index;
      }
    }
  }

  int? expectedHeadIndexFor(
    GeneratedReportAgentSlot agentSlot,
    GeneratedReportScopeSlot scopeSlot,
  ) {
    final indexes =
        headIndexesFor(
          agentSlot,
          scopeSlot,
        ).where((index) => !heads[index].deleted).toList()..sort(
          (a, b) => heads[b].updatedAt(b).compareTo(heads[a].updatedAt(a)),
        );
    return indexes.isEmpty ? null : indexes.first;
  }

  String? expectedHeadIdFor(
    GeneratedReportAgentSlot agentSlot,
    GeneratedReportScopeSlot scopeSlot,
  ) {
    final index = expectedHeadIndexFor(agentSlot, scopeSlot);
    return index == null ? null : heads[index].idAt(index);
  }

  String? expectedHeadReportIdFor(
    GeneratedReportAgentSlot agentSlot,
    GeneratedReportScopeSlot scopeSlot,
  ) {
    final index = expectedHeadIndexFor(agentSlot, scopeSlot);
    return index == null ? null : heads[index].reportIdFor(this);
  }

  String? expectedLatestReportIdFor(
    GeneratedReportAgentSlot agentSlot,
    GeneratedReportScopeSlot scopeSlot,
  ) {
    final headReportId = expectedHeadReportIdFor(agentSlot, scopeSlot);
    if (headReportId == null) return null;

    for (final index in reportIndexesFor(agentSlot, scopeSlot)) {
      if (!reports[index].deleted &&
          reports[index].idAt(index) == headReportId) {
        return headReportId;
      }
    }
    return null;
  }

  Map<String, String> get expectedBatchReportIdsForTargetScope {
    final result = <String, String>{};
    for (final agentSlot in GeneratedReportAgentSlot.values) {
      final reportId = expectedLatestReportIdFor(
        agentSlot,
        GeneratedReportScopeSlot.target,
      );
      if (reportId != null) {
        result[_agentIdFor(agentSlot)] = reportId;
      }
    }
    return result;
  }

  String _agentIdFor(GeneratedReportAgentSlot agentSlot) {
    return switch (agentSlot) {
      GeneratedReportAgentSlot.target => generatedReportTargetAgentId,
      GeneratedReportAgentSlot.other => generatedReportOtherAgentId,
    };
  }

  @override
  String toString() {
    return 'GeneratedReportResolutionScenario('
        'reports: $reports, heads: $heads)';
  }
}

const String generatedPrimaryTargetProjectId =
    'generated-primary-project-target';
const String generatedPrimaryOtherProjectId = 'generated-primary-project-other';
const String generatedPrimaryFirstTaskId = 'generated-primary-task-first';
const String generatedPrimarySecondTaskId = 'generated-primary-task-second';
const String generatedPrimaryOtherTaskId = 'generated-primary-task-other';

String generatedPrimaryAgentId(int agentSlot) {
  return 'generated-primary-agent-$agentSlot';
}

class GeneratedPrimaryReportSpec {
  const GeneratedPrimaryReportSpec({
    required this.agentSlot,
    required this.scopeSlot,
    required this.state,
    required this.updatedMinuteOffset,
  });

  final int agentSlot;
  final GeneratedReportScopeSlot scopeSlot;
  final GeneratedPrimaryReportState state;
  final int updatedMinuteOffset;

  String get agentId => generatedPrimaryAgentId(agentSlot);

  String get scope => switch (scopeSlot) {
    GeneratedReportScopeSlot.target => AgentReportScopes.current,
    GeneratedReportScopeSlot.other => generatedReportOtherScope,
  };

  String get reportId =>
      'generated-primary-report-${scopeSlot.name}-$agentSlot';

  String get headId => 'generated-primary-head-${scopeSlot.name}-$agentSlot';

  String get missingReportId {
    return 'generated-primary-missing-report-${scopeSlot.name}-$agentSlot';
  }

  DateTime get updatedAt {
    return DateTime(2026, 5, 6).add(
      Duration(minutes: updatedMinuteOffset),
    );
  }

  DateTime? get headDeletedAt {
    return state == GeneratedPrimaryReportState.noActiveHead
        ? updatedAt.add(const Duration(minutes: 1))
        : null;
  }

  DateTime? get reportDeletedAt {
    return state == GeneratedPrimaryReportState.deletedReport
        ? updatedAt.add(const Duration(minutes: 1))
        : null;
  }

  String get headReportId {
    return state == GeneratedPrimaryReportState.missingReport
        ? missingReportId
        : reportId;
  }

  bool get writesReport {
    return state != GeneratedPrimaryReportState.missingReport;
  }

  String get content {
    return state == GeneratedPrimaryReportState.emptyReport
        ? '   '
        : 'generated usable report for $agentId';
  }

  bool get resolvesCurrentReport {
    return scopeSlot == GeneratedReportScopeSlot.target &&
        switch (state) {
          GeneratedPrimaryReportState.emptyReport ||
          GeneratedPrimaryReportState.usableReport => true,
          _ => false,
        };
  }

  bool get resolvesNonEmptyCurrentReport {
    return resolvesCurrentReport && content.trim().isNotEmpty;
  }

  @override
  String toString() {
    return 'GeneratedPrimaryReportSpec('
        'agentSlot: $agentSlot, scopeSlot: $scopeSlot, state: $state, '
        'updatedMinuteOffset: $updatedMinuteOffset)';
  }
}

class GeneratedPrimaryProjectLinkSpec {
  const GeneratedPrimaryProjectLinkSpec({
    required this.projectSlot,
    required this.agentSlot,
    required this.deleted,
    required this.createdMinuteOffset,
  });

  final GeneratedPrimaryProjectSlot projectSlot;
  final int agentSlot;
  final bool deleted;
  final int createdMinuteOffset;

  String get id =>
      'generated-primary-project-link-'
      '${projectSlot.name}-$agentSlot';

  String get agentId => generatedPrimaryAgentId(agentSlot);

  String get projectId => switch (projectSlot) {
    GeneratedPrimaryProjectSlot.target => generatedPrimaryTargetProjectId,
    GeneratedPrimaryProjectSlot.other => generatedPrimaryOtherProjectId,
  };

  DateTime get createdAt {
    return DateTime(2026, 5, 7).add(
      Duration(minutes: createdMinuteOffset),
    );
  }

  DateTime? get deletedAt {
    return deleted ? createdAt.add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return 'GeneratedPrimaryProjectLinkSpec('
        'projectSlot: $projectSlot, agentSlot: $agentSlot, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset)';
  }
}

class GeneratedPrimaryTaskLinkSpec {
  const GeneratedPrimaryTaskLinkSpec({
    required this.taskSlot,
    required this.agentSlot,
    required this.deleted,
    required this.createdMinuteOffset,
  });

  final GeneratedPrimaryTaskSlot taskSlot;
  final int agentSlot;
  final bool deleted;
  final int createdMinuteOffset;

  String get id => 'generated-primary-task-link-${taskSlot.name}-$agentSlot';

  String get agentId => generatedPrimaryAgentId(agentSlot);

  String get taskId => switch (taskSlot) {
    GeneratedPrimaryTaskSlot.first => generatedPrimaryFirstTaskId,
    GeneratedPrimaryTaskSlot.second => generatedPrimarySecondTaskId,
    GeneratedPrimaryTaskSlot.other => generatedPrimaryOtherTaskId,
  };

  DateTime get createdAt {
    return DateTime(2026, 5, 8).add(
      Duration(minutes: createdMinuteOffset),
    );
  }

  DateTime? get deletedAt {
    return deleted ? createdAt.add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return 'GeneratedPrimaryTaskLinkSpec('
        'taskSlot: $taskSlot, agentSlot: $agentSlot, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset)';
  }
}

class GeneratedPrimaryLinkSelectionScenario {
  const GeneratedPrimaryLinkSelectionScenario({
    required this.reports,
    required this.projectLinks,
    required this.taskLinks,
  });

  final List<GeneratedPrimaryReportSpec> reports;
  final List<GeneratedPrimaryProjectLinkSpec> projectLinks;
  final List<GeneratedPrimaryTaskLinkSpec> taskLinks;

  Map<String, GeneratedPrimaryReportSpec> get _finalReportsByAgentAndScope {
    final result = <String, GeneratedPrimaryReportSpec>{};
    for (final report in reports) {
      result['${report.agentSlot}:${report.scopeSlot.name}'] = report;
    }
    return result;
  }

  GeneratedPrimaryReportSpec? _currentReportForAgent(int agentSlot) {
    return _finalReportsByAgentAndScope['$agentSlot:${GeneratedReportScopeSlot.target.name}'];
  }

  List<GeneratedPrimaryProjectLinkSpec> get _activeTargetProjectLinks {
    final finalLinksByAgent = <int, GeneratedPrimaryProjectLinkSpec>{};
    for (final link in projectLinks) {
      if (link.projectSlot == GeneratedPrimaryProjectSlot.target) {
        finalLinksByAgent[link.agentSlot] = link;
      }
    }

    return finalLinksByAgent.values.where((link) => !link.deleted).toList()
      ..sort((a, b) {
        final byCreatedAt = b.createdAt.compareTo(a.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return b.id.compareTo(a.id);
      });
  }

  List<GeneratedPrimaryTaskLinkSpec> _activeTaskLinksFor(
    GeneratedPrimaryTaskSlot taskSlot,
  ) {
    final finalLinksByAgent = <int, GeneratedPrimaryTaskLinkSpec>{};
    for (final link in taskLinks) {
      if (link.taskSlot == taskSlot) {
        finalLinksByAgent[link.agentSlot] = link;
      }
    }

    return finalLinksByAgent.values.where((link) => !link.deleted).toList()
      ..sort((a, b) {
        final byCreatedAt = b.createdAt.compareTo(a.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return b.id.compareTo(a.id);
      });
  }

  String? get expectedProjectReportId {
    for (final link in _activeTargetProjectLinks) {
      final report = _currentReportForAgent(link.agentSlot);
      if (report != null && report.resolvesNonEmptyCurrentReport) {
        return report.reportId;
      }
    }
    return null;
  }

  Map<String, String> get expectedTaskReportIds {
    final result = <String, String>{};
    for (final taskSlot in [
      GeneratedPrimaryTaskSlot.first,
      GeneratedPrimaryTaskSlot.second,
    ]) {
      final links = _activeTaskLinksFor(taskSlot);
      if (links.isEmpty) continue;

      final primaryLink = links.first;
      final report = _currentReportForAgent(primaryLink.agentSlot);
      if (report != null && report.resolvesCurrentReport) {
        result[primaryLink.taskId] = report.reportId;
      }
    }
    return result;
  }

  @override
  String toString() {
    return 'GeneratedPrimaryLinkSelectionScenario('
        'reports: $reports, projectLinks: $projectLinks, '
        'taskLinks: $taskLinks)';
  }
}

const String generatedBatchFirstTaskId = 'generated-batch-task-first';
const String generatedBatchSecondTaskId = 'generated-batch-task-second';
const String generatedBatchOtherTaskId = 'generated-batch-task-other';
const String generatedBatchMissingTaskId = 'generated-batch-task-missing';

String generatedBatchAgentId(int agentSlot) {
  return 'generated-batch-agent-$agentSlot';
}

String generatedBatchTaskId(GeneratedBatchTaskSlot taskSlot) {
  return switch (taskSlot) {
    GeneratedBatchTaskSlot.first => generatedBatchFirstTaskId,
    GeneratedBatchTaskSlot.second => generatedBatchSecondTaskId,
    GeneratedBatchTaskSlot.other => generatedBatchOtherTaskId,
  };
}

String generatedBatchRequestedTaskId(
  GeneratedBatchRequestedTaskSlot taskSlot,
) {
  return switch (taskSlot) {
    GeneratedBatchRequestedTaskSlot.first => generatedBatchFirstTaskId,
    GeneratedBatchRequestedTaskSlot.second => generatedBatchSecondTaskId,
    GeneratedBatchRequestedTaskSlot.other => generatedBatchOtherTaskId,
    GeneratedBatchRequestedTaskSlot.missing => generatedBatchMissingTaskId,
  };
}

class GeneratedBatchTaskLinkSpec {
  const GeneratedBatchTaskLinkSpec({
    required this.kind,
    required this.taskSlot,
    required this.agentSlot,
    required this.deleted,
    required this.createdMinuteOffset,
  });

  final GeneratedBatchLinkKind kind;
  final GeneratedBatchTaskSlot taskSlot;
  final int agentSlot;
  final bool deleted;
  final int createdMinuteOffset;

  String get id =>
      'generated-batch-link-'
      '${kind.name}-${taskSlot.name}-$agentSlot';

  String get agentId => generatedBatchAgentId(agentSlot);

  String get taskId => generatedBatchTaskId(taskSlot);

  DateTime get createdAt {
    return DateTime(2026, 5, 9).add(
      Duration(minutes: createdMinuteOffset),
    );
  }

  DateTime? get deletedAt {
    return deleted ? createdAt.add(const Duration(minutes: 1)) : null;
  }

  String get naturalKey => '${kind.name}:$taskId:$agentId';

  @override
  String toString() {
    return 'GeneratedBatchTaskLinkSpec('
        'kind: $kind, taskSlot: $taskSlot, agentSlot: $agentSlot, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset)';
  }
}

class GeneratedBatchTaskLinkQueryScenario {
  const GeneratedBatchTaskLinkQueryScenario({
    required this.links,
    required this.requestedTaskSlots,
  });

  final List<GeneratedBatchTaskLinkSpec> links;
  final List<GeneratedBatchRequestedTaskSlot> requestedTaskSlots;

  Map<String, GeneratedBatchTaskLinkSpec> get _finalLinksByNaturalKey {
    final result = <String, GeneratedBatchTaskLinkSpec>{};
    for (final link in links) {
      result[link.naturalKey] = link;
    }
    return result;
  }

  Iterable<GeneratedBatchTaskLinkSpec> get _activeAgentTaskLinks {
    return _finalLinksByNaturalKey.values.where(
      (link) => link.kind == GeneratedBatchLinkKind.agentTask && !link.deleted,
    );
  }

  List<String> get requestedTaskIds {
    return requestedTaskSlots.map(generatedBatchRequestedTaskId).toList();
  }

  Map<String, Set<String>> get expectedLinksToMultipleIds {
    final requestedIds = requestedTaskIds.toSet();
    final result = <String, Set<String>>{};
    for (final link in _activeAgentTaskLinks) {
      if (requestedIds.contains(link.taskId)) {
        (result[link.taskId] ??= <String>{}).add(link.id);
      }
    }
    return result;
  }

  Set<String> get expectedTaskIdsWithAgentLink {
    return _activeAgentTaskLinks.map((link) => link.taskId).toSet();
  }

  @override
  String toString() {
    return 'GeneratedBatchTaskLinkQueryScenario('
        'requestedTaskSlots: $requestedTaskSlots, links: $links)';
  }
}

final generatedTemplateInstanceBase = DateTime(2026, 5, 10, 12);
final generatedTemplateInstanceSince = DateTime(2026, 5, 10, 12);

const String generatedInstanceTargetTemplateId =
    'generated-instance-template-target';
const String generatedInstanceOtherTemplateId =
    'generated-instance-template-other';

String generatedInstanceAgentId(int agentSlot) {
  return 'generated-instance-agent-$agentSlot';
}

class GeneratedTemplateInstanceAssignmentSpec {
  const GeneratedTemplateInstanceAssignmentSpec({
    required this.slot,
    required this.agentSlot,
    required this.deleted,
    required this.createdMinuteOffset,
  });

  final GeneratedTemplateSlot slot;
  final int agentSlot;
  final bool deleted;
  final int createdMinuteOffset;

  String get id => 'generated-instance-assignment-${slot.name}-$agentSlot';

  String get templateId => switch (slot) {
    GeneratedTemplateSlot.target => generatedInstanceTargetTemplateId,
    GeneratedTemplateSlot.other => generatedInstanceOtherTemplateId,
  };

  String get agentId => generatedInstanceAgentId(agentSlot);

  DateTime get createdAt {
    return generatedTemplateInstanceBase.add(
      Duration(minutes: createdMinuteOffset),
    );
  }

  DateTime? get deletedAt {
    return deleted ? createdAt.add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return 'GeneratedTemplateInstanceAssignmentSpec('
        'slot: $slot, agentSlot: $agentSlot, deleted: $deleted, '
        'createdMinuteOffset: $createdMinuteOffset)';
  }
}

class GeneratedTemplateInstanceTokenUsageSpec {
  const GeneratedTemplateInstanceTokenUsageSpec({
    required this.agentSlot,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final int agentSlot;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-instance-token-$index-$seed';

  String get agentId => generatedInstanceAgentId(agentSlot);

  String runKeyAt(int index) => 'generated-instance-run-$index-$seed';

  String threadIdAt(int index) => 'generated-instance-thread-$index-$seed';

  String get modelId => 'generated-model-${seed % 4}';

  int? get inputTokens => seed % 4 == 0 ? null : seed % 17;

  int? get outputTokens => seed % 5 == 0 ? null : seed % 13;

  int? get thoughtsTokens => seed % 6 == 0 ? null : seed % 11;

  DateTime createdAt(int index) {
    return generatedTemplateInstanceBase.add(
      Duration(minutes: createdMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return 'GeneratedTemplateInstanceTokenUsageSpec('
        'agentSlot: $agentSlot, deleted: $deleted, '
        'createdMinuteOffset: $createdMinuteOffset, seed: $seed)';
  }
}

class GeneratedTemplateInstanceReportSpec {
  const GeneratedTemplateInstanceReportSpec({
    required this.agentSlot,
    required this.scopeSlot,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final int agentSlot;
  final GeneratedReportScopeSlot scopeSlot;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-instance-report-$index-$seed';

  String get agentId => generatedInstanceAgentId(agentSlot);

  String get scope => switch (scopeSlot) {
    GeneratedReportScopeSlot.target => AgentReportScopes.current,
    GeneratedReportScopeSlot.other => generatedReportOtherScope,
  };

  String contentAt(int index) => 'generated report $index seed $seed';

  DateTime createdAt(int index) {
    return generatedTemplateInstanceBase.add(
      Duration(minutes: createdMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return 'GeneratedTemplateInstanceReportSpec('
        'agentSlot: $agentSlot, scopeSlot: $scopeSlot, deleted: $deleted, '
        'createdMinuteOffset: $createdMinuteOffset, seed: $seed)';
  }
}

class GeneratedTemplateInstanceQueryScenario {
  const GeneratedTemplateInstanceQueryScenario({
    required this.assignments,
    required this.tokenUsages,
    required this.reports,
    required this.usageLimit,
    required this.reportLimit,
  });

  final List<GeneratedTemplateInstanceAssignmentSpec> assignments;
  final List<GeneratedTemplateInstanceTokenUsageSpec> tokenUsages;
  final List<GeneratedTemplateInstanceReportSpec> reports;
  final int usageLimit;
  final int reportLimit;

  Set<int> get _activeTargetAgentSlots {
    final finalAssignmentsByNaturalKey =
        <String, GeneratedTemplateInstanceAssignmentSpec>{};
    for (final assignment in assignments) {
      final key = '${assignment.slot.name}:${assignment.agentSlot}';
      finalAssignmentsByNaturalKey[key] = assignment;
    }

    return {
      for (final assignment in finalAssignmentsByNaturalKey.values)
        if (assignment.slot == GeneratedTemplateSlot.target &&
            !assignment.deleted)
          assignment.agentSlot,
    };
  }

  List<int> _matchingTokenIndexes({DateTime? since}) {
    return [
      for (var index = 0; index < tokenUsages.length; index++)
        if (_activeTargetAgentSlots.contains(tokenUsages[index].agentSlot) &&
            !tokenUsages[index].deleted &&
            (since == null ||
                !tokenUsages[index].createdAt(index).isBefore(since)))
          index,
    ]..sort(
      (a, b) => tokenUsages[b]
          .createdAt(b)
          .compareTo(
            tokenUsages[a].createdAt(a),
          ),
    );
  }

  List<int> get _matchingReportIndexes {
    return [
      for (var index = 0; index < reports.length; index++)
        if (_activeTargetAgentSlots.contains(reports[index].agentSlot) &&
            reports[index].scopeSlot == GeneratedReportScopeSlot.target &&
            !reports[index].deleted)
          index,
    ]..sort(
      (a, b) => reports[b]
          .createdAt(b)
          .compareTo(
            reports[a].createdAt(a),
          ),
    );
  }

  List<String> expectedTokenUsageIds({required int limit}) {
    return _matchingTokenIndexes()
        .take(limit)
        .map((index) => tokenUsages[index].idAt(index))
        .toList();
  }

  List<String> expectedTokenUsageIdsSince(DateTime since) {
    return _matchingTokenIndexes(
      since: since,
    ).map((index) => tokenUsages[index].idAt(index)).toList();
  }

  List<String> expectedReportIds({required int limit}) {
    return _matchingReportIndexes
        .take(limit)
        .map((index) => reports[index].idAt(index))
        .toList();
  }

  ({int input, int output, int thoughts}) expectedTokenSums({
    DateTime? since,
  }) {
    var input = 0;
    var output = 0;
    var thoughts = 0;
    for (final index in _matchingTokenIndexes(since: since)) {
      final usage = tokenUsages[index];
      input += usage.inputTokens ?? 0;
      output += usage.outputTokens ?? 0;
      thoughts += usage.thoughtsTokens ?? 0;
    }
    return (input: input, output: output, thoughts: thoughts);
  }

  @override
  String toString() {
    return 'GeneratedTemplateInstanceQueryScenario('
        'usageLimit: $usageLimit, reportLimit: $reportLimit, '
        'assignments: $assignments, tokenUsages: $tokenUsages, '
        'reports: $reports)';
  }
}

final generatedWakeBase = DateTime(2026, 4, 10, 12);
final generatedWakeWindowStart = DateTime(2026, 4, 10, 6);
final generatedWakeWindowEnd = DateTime(2026, 4, 10, 18);

const generatedWakeTargetAgentId = 'generated-wake-agent-0';
const generatedWakeTargetThreadId = 'generated-wake-thread-0';
const generatedWakeTargetTemplateId = 'generated-wake-template-target';

const generatedTemplateTargetId = 'generated-template-target';
const generatedTemplateOtherId = 'generated-template-other';

class GeneratedWakeLifecycleSpec {
  const GeneratedWakeLifecycleSpec({
    required this.status,
    required this.templateShape,
    required this.agentSlot,
    required this.threadSlot,
    required this.createdHourOffset,
    required this.durationMinutes,
    required this.seed,
  });

  final WakeRunStatus status;
  final GeneratedWakeTemplateShape templateShape;
  final int agentSlot;
  final int threadSlot;
  final int createdHourOffset;
  final int durationMinutes;
  final int seed;

  String runKeyAt(int index) => 'generated-wake-run-$index-$seed';

  String get agentId => 'generated-wake-agent-$agentSlot';

  String get threadId => 'generated-wake-thread-$threadSlot';

  String get reason => WakeReason.values[seed % WakeReason.values.length].name;

  DateTime createdAt(int index) => generatedWakeBase.add(
    Duration(hours: createdHourOffset, seconds: index),
  );

  DateTime startedAt(int index) => createdAt(index).add(
    Duration(minutes: seed % 4),
  );

  Duration get duration => Duration(minutes: durationMinutes);

  DateTime? completedAt(int index) {
    return switch (status) {
      WakeRunStatus.completed ||
      WakeRunStatus.failed ||
      WakeRunStatus.aborted => startedAt(index).add(duration),
      WakeRunStatus.running || WakeRunStatus.abandoned => null,
    };
  }

  String? get errorMessage {
    return status == WakeRunStatus.failed ? 'generated failure $seed' : null;
  }

  String? get templateId {
    return switch (templateShape) {
      GeneratedWakeTemplateShape.target => generatedWakeTargetTemplateId,
      GeneratedWakeTemplateShape.other => 'generated-wake-template-other',
      GeneratedWakeTemplateShape.none => null,
    };
  }

  String? get templateVersionId {
    final id = templateId;
    return id == null ? null : '$id-version-${seed % 3}';
  }

  bool get hasResolvedModel => seed.isEven;

  String? get resolvedModelId {
    return hasResolvedModel ? 'generated-model-${seed % 5}' : null;
  }

  bool get hasSoulProvenance => seed % 3 == 0;

  String? get soulId {
    return hasSoulProvenance ? 'generated-soul-${seed % 4}' : null;
  }

  String? get soulVersionId {
    return hasSoulProvenance ? 'generated-soul-version-${seed % 6}' : null;
  }

  bool get hasRating => seed.isEven;

  double get rating => (seed % 11) / 2;

  DateTime ratedAt(int index) => createdAt(index).add(
    Duration(hours: 3, minutes: seed % 7),
  );

  bool isInWindow(int index, DateTime since, DateTime until) {
    final created = createdAt(index);
    return !created.isBefore(since) && !created.isAfter(until);
  }

  bool hasPositiveDuration(int index) {
    final completed = completedAt(index);
    if (completed == null) return false;
    return completed.difference(startedAt(index)).inMilliseconds > 0;
  }

  int positiveDurationMs(int index) {
    return hasPositiveDuration(index)
        ? completedAt(index)!.difference(startedAt(index)).inMilliseconds
        : 0;
  }

  @override
  String toString() {
    return 'GeneratedWakeLifecycleSpec('
        'status: $status, templateShape: $templateShape, '
        'agentSlot: $agentSlot, threadSlot: $threadSlot, '
        'createdHourOffset: $createdHourOffset, '
        'durationMinutes: $durationMinutes, seed: $seed)';
  }
}

class GeneratedWakeLifecycleScenario {
  const GeneratedWakeLifecycleScenario({
    required this.specs,
    required this.templateLimit,
  });

  final List<GeneratedWakeLifecycleSpec> specs;
  final int templateLimit;

  List<int> _sortedIndexes(Iterable<int> indexes) {
    return indexes.toList()
      ..sort((a, b) => specs[b].createdAt(b).compareTo(specs[a].createdAt(a)));
  }

  Iterable<int> get _targetTemplateIndexes sync* {
    for (var index = 0; index < specs.length; index++) {
      if (specs[index].templateId == generatedWakeTargetTemplateId) {
        yield index;
      }
    }
  }

  List<String> expectedTemplateRunKeys({required int limit}) {
    return _sortedIndexes(
      _targetTemplateIndexes,
    ).take(limit).map((index) => specs[index].runKeyAt(index)).toList();
  }

  List<String> expectedTargetTemplateWindowRunKeys(
    DateTime since,
    DateTime until,
  ) {
    return _sortedIndexes(
      _targetTemplateIndexes.where(
        (index) => specs[index].isInWindow(index, since, until),
      ),
    ).map((index) => specs[index].runKeyAt(index)).toList();
  }

  List<String> expectedGlobalWindowRunKeys(DateTime since, DateTime until) {
    return _sortedIndexes(
      Iterable<int>.generate(specs.length).where(
        (index) => specs[index].isInWindow(index, since, until),
      ),
    ).map((index) => specs[index].runKeyAt(index)).toList();
  }

  String? latestRunKeyForThread(String agentId, String threadId) {
    final indexes = _sortedIndexes(
      Iterable<int>.generate(specs.length).where(
        (index) =>
            specs[index].agentId == agentId &&
            specs[index].threadId == threadId,
      ),
    );
    return indexes.isEmpty
        ? null
        : specs[indexes.first].runKeyAt(indexes.first);
  }

  int get targetTemplateCount => _targetTemplateIndexes.length;

  int get targetTemplateSuccessCount {
    return _targetTemplateIndexes
        .where((index) => specs[index].status == WakeRunStatus.completed)
        .length;
  }

  int get targetTemplateFailureCount {
    return _targetTemplateIndexes
        .where((index) => specs[index].status == WakeRunStatus.failed)
        .length;
  }

  int get targetTemplateDurationCount {
    return _targetTemplateIndexes
        .where((index) => specs[index].hasPositiveDuration(index))
        .length;
  }

  int? get targetTemplateDurationSumMs {
    if (targetTemplateCount == 0) return null;
    return _targetTemplateIndexes.fold<int>(
      0,
      (sum, index) => sum + specs[index].positiveDurationMs(index),
    );
  }

  DateTime? get firstWakeAt {
    if (targetTemplateCount == 0) return null;
    final dates =
        _targetTemplateIndexes
            .map((index) => specs[index].createdAt(index))
            .toList()
          ..sort();
    return dates.first;
  }

  DateTime? get lastWakeAt {
    if (targetTemplateCount == 0) return null;
    final dates =
        _targetTemplateIndexes
            .map((index) => specs[index].createdAt(index))
            .toList()
          ..sort();
    return dates.last;
  }

  int get runningCount {
    return specs.where((spec) => spec.status == WakeRunStatus.running).length;
  }

  @override
  String toString() {
    return 'GeneratedWakeLifecycleScenario('
        'templateLimit: $templateLimit, specs: $specs)';
  }
}

class GeneratedTemplateVersionSpec {
  const GeneratedTemplateVersionSpec({
    required this.slot,
    required this.version,
    required this.status,
    required this.deleted,
    required this.seed,
  });

  final GeneratedTemplateSlot slot;
  final int version;
  final AgentTemplateVersionStatus status;
  final bool deleted;
  final int seed;

  String idAt(int index) => 'generated-template-version-$index-$seed';

  String get templateId => switch (slot) {
    GeneratedTemplateSlot.target => generatedTemplateTargetId,
    GeneratedTemplateSlot.other => generatedTemplateOtherId,
  };

  DateTime createdAt(int index) {
    return DateTime(2026, 5).add(Duration(minutes: index, seconds: seed % 30));
  }

  DateTime? deletedAt(int index) {
    return deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return 'GeneratedTemplateVersionSpec('
        'slot: $slot, version: $version, status: $status, '
        'deleted: $deleted, seed: $seed)';
  }
}

class GeneratedTemplateHeadSpec {
  const GeneratedTemplateHeadSpec({
    required this.slot,
    required this.pointsToExisting,
    required this.versionOrdinal,
    required this.deleted,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final GeneratedTemplateSlot slot;
  final bool pointsToExisting;
  final int versionOrdinal;
  final bool deleted;
  final int updatedMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-template-head-$index-$seed';

  String get templateId => switch (slot) {
    GeneratedTemplateSlot.target => generatedTemplateTargetId,
    GeneratedTemplateSlot.other => generatedTemplateOtherId,
  };

  DateTime updatedAt(int index) {
    return DateTime(
      2026,
      5,
      2,
    ).add(Duration(minutes: updatedMinuteOffset, seconds: index));
  }

  DateTime? deletedAt(int index) {
    return deleted ? updatedAt(index).add(const Duration(minutes: 1)) : null;
  }

  String versionIdFor(GeneratedTemplateResolutionScenario scenario) {
    final targetIndexes = scenario.targetVersionIndexes.toList();
    if (!pointsToExisting || targetIndexes.isEmpty) {
      return 'generated-missing-version-$seed';
    }
    final versionIndex = targetIndexes[versionOrdinal % targetIndexes.length];
    return scenario.versions[versionIndex].idAt(versionIndex);
  }

  @override
  String toString() {
    return 'GeneratedTemplateHeadSpec('
        'slot: $slot, pointsToExisting: $pointsToExisting, '
        'versionOrdinal: $versionOrdinal, deleted: $deleted, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class GeneratedTemplateAssignmentSpec {
  const GeneratedTemplateAssignmentSpec({
    required this.slot,
    required this.agentSlot,
    required this.deleted,
    required this.seed,
  });

  final GeneratedTemplateSlot slot;
  final int agentSlot;
  final bool deleted;
  final int seed;

  String idAt(int _) => 'generated-template-assignment-${slot.name}-$agentSlot';

  String get templateId => switch (slot) {
    GeneratedTemplateSlot.target => generatedTemplateTargetId,
    GeneratedTemplateSlot.other => generatedTemplateOtherId,
  };

  String get agentId => 'generated-template-agent-$agentSlot';

  DateTime createdAt(int index) {
    return DateTime(2026, 5, 3).add(Duration(minutes: index));
  }

  DateTime? deletedAt(int index) {
    return deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return 'GeneratedTemplateAssignmentSpec('
        'slot: $slot, agentSlot: $agentSlot, deleted: $deleted, seed: $seed)';
  }
}

class GeneratedTemplateResolutionScenario {
  const GeneratedTemplateResolutionScenario({
    required this.versions,
    required this.heads,
    required this.assignments,
  });

  final List<GeneratedTemplateVersionSpec> versions;
  final List<GeneratedTemplateHeadSpec> heads;
  final List<GeneratedTemplateAssignmentSpec> assignments;

  Iterable<int> get targetVersionIndexes sync* {
    for (var index = 0; index < versions.length; index++) {
      if (versions[index].slot == GeneratedTemplateSlot.target) {
        yield index;
      }
    }
  }

  Iterable<int> get nonDeletedTargetVersionIndexes {
    return targetVersionIndexes.where((index) => !versions[index].deleted);
  }

  Iterable<int> get targetHeadIndexes sync* {
    for (var index = 0; index < heads.length; index++) {
      if (heads[index].slot == GeneratedTemplateSlot.target) {
        yield index;
      }
    }
  }

  int? get expectedHeadIndex {
    final indexes =
        targetHeadIndexes.where((index) => !heads[index].deleted).toList()
          ..sort(
            (a, b) => heads[b].updatedAt(b).compareTo(heads[a].updatedAt(a)),
          );
    return indexes.isEmpty ? null : indexes.first;
  }

  String? get expectedHeadId {
    final index = expectedHeadIndex;
    return index == null ? null : heads[index].idAt(index);
  }

  String? get expectedHeadVersionId {
    final index = expectedHeadIndex;
    return index == null ? null : heads[index].versionIdFor(this);
  }

  String? get expectedActiveVersionId {
    final headVersionId = expectedHeadVersionId;
    if (headVersionId == null) return null;
    for (final index in nonDeletedTargetVersionIndexes) {
      if (versions[index].idAt(index) == headVersionId) {
        return headVersionId;
      }
    }
    return null;
  }

  AgentTemplateVersionStatus? get expectedActiveVersionStatus {
    final activeVersionId = expectedActiveVersionId;
    if (activeVersionId == null) return null;
    for (final index in nonDeletedTargetVersionIndexes) {
      if (versions[index].idAt(index) == activeVersionId) {
        return versions[index].status;
      }
    }
    return null;
  }

  int get expectedNextVersionNumber {
    final versionNumbers = nonDeletedTargetVersionIndexes
        .map((index) => versions[index].version)
        .toList();
    if (versionNumbers.isEmpty) return 1;
    return versionNumbers.reduce((a, b) => a > b ? a : b) + 1;
  }

  Set<String> get expectedTargetAssignmentIds {
    final finalAssignmentsBySlot = <String, GeneratedTemplateAssignmentSpec>{};
    for (final assignment in assignments) {
      final key = '${assignment.slot.name}:${assignment.agentSlot}';
      finalAssignmentsBySlot[key] = assignment;
    }
    return {
      for (final assignment in finalAssignmentsBySlot.values)
        if (assignment.slot == GeneratedTemplateSlot.target &&
            !assignment.deleted)
          assignment.idAt(0),
    };
  }

  Set<String> get expectedTargetAssignmentAgentIds {
    final finalAssignmentsBySlot = <String, GeneratedTemplateAssignmentSpec>{};
    for (final assignment in assignments) {
      final key = '${assignment.slot.name}:${assignment.agentSlot}';
      finalAssignmentsBySlot[key] = assignment;
    }
    return {
      for (final assignment in finalAssignmentsBySlot.values)
        if (assignment.slot == GeneratedTemplateSlot.target &&
            !assignment.deleted)
          assignment.agentId,
    };
  }

  @override
  String toString() {
    return 'GeneratedTemplateResolutionScenario('
        'versions: $versions, heads: $heads, assignments: $assignments)';
  }
}

extension AnyGeneratedIntervalQueryScenario on glados.Any {
  glados.Generator<GeneratedIntervalEntityKind> get intervalEntityKind =>
      glados.AnyUtils(this).choose(GeneratedIntervalEntityKind.values);

  glados.Generator<GeneratedIntervalEntitySpec> get intervalEntitySpec =>
      glados.CombinableAny(this).combine4(
        intervalEntityKind,
        glados.IntAnys(this).intInRange(-2, 7),
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedIntervalEntityKind kind,
          int offsetDays,
          bool deleted,
          int seed,
        ) => GeneratedIntervalEntitySpec(
          kind: kind,
          offsetDays: offsetDays,
          deleted: deleted,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedIntervalQueryScenario> get intervalQueryScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 10, intervalEntitySpec),
        glados.IntAnys(this).intInRange(1, 4),
        (
          List<GeneratedIntervalEntitySpec> specs,
          int pageSize,
        ) => GeneratedIntervalQueryScenario(
          specs: specs,
          pageSize: pageSize,
        ),
      );

  glados.Generator<GeneratedReportAgentSlot> get reportAgentSlot =>
      glados.AnyUtils(this).choose(GeneratedReportAgentSlot.values);

  glados.Generator<GeneratedReportScopeSlot> get reportScopeSlot =>
      glados.AnyUtils(this).choose(GeneratedReportScopeSlot.values);

  glados.Generator<GeneratedReportSpec> get reportSpec =>
      glados.CombinableAny(this).combine5(
        reportAgentSlot,
        reportScopeSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedReportAgentSlot agentSlot,
          GeneratedReportScopeSlot scopeSlot,
          bool deleted,
          int createdMinuteOffset,
          int seed,
        ) => GeneratedReportSpec(
          agentSlot: agentSlot,
          scopeSlot: scopeSlot,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedReportHeadSpec> get reportHeadSpec =>
      glados.CombinableAny(this).combine7(
        reportAgentSlot,
        reportScopeSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(0, 8),
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedReportAgentSlot agentSlot,
          GeneratedReportScopeSlot scopeSlot,
          bool pointsToExisting,
          int reportOrdinal,
          bool deleted,
          int updatedMinuteOffset,
          int seed,
        ) => GeneratedReportHeadSpec(
          agentSlot: agentSlot,
          scopeSlot: scopeSlot,
          pointsToExisting: pointsToExisting,
          reportOrdinal: reportOrdinal,
          deleted: deleted,
          updatedMinuteOffset: updatedMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedReportResolutionScenario>
  get reportResolutionScenario => glados.CombinableAny(this).combine2(
    glados.ListAnys(this).listWithLengthInRange(0, 8, reportSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 6, reportHeadSpec),
    (
      List<GeneratedReportSpec> reports,
      List<GeneratedReportHeadSpec> heads,
    ) => GeneratedReportResolutionScenario(
      reports: reports,
      heads: heads,
    ),
  );

  glados.Generator<GeneratedPrimaryReportState> get primaryReportState =>
      glados.AnyUtils(this).choose(GeneratedPrimaryReportState.values);

  glados.Generator<GeneratedPrimaryProjectSlot> get primaryProjectSlot =>
      glados.AnyUtils(this).choose(GeneratedPrimaryProjectSlot.values);

  glados.Generator<GeneratedPrimaryTaskSlot> get primaryTaskSlot =>
      glados.AnyUtils(this).choose(GeneratedPrimaryTaskSlot.values);

  glados.Generator<GeneratedPrimaryReportSpec> get primaryReportSpec =>
      glados.CombinableAny(this).combine4(
        glados.AnyUtils(this).choose([0, 1, 2, 3]),
        reportScopeSlot,
        primaryReportState,
        glados.IntAnys(this).intInRange(-4, 4),
        (
          int agentSlot,
          GeneratedReportScopeSlot scopeSlot,
          GeneratedPrimaryReportState state,
          int updatedMinuteOffset,
        ) => GeneratedPrimaryReportSpec(
          agentSlot: agentSlot,
          scopeSlot: scopeSlot,
          state: state,
          updatedMinuteOffset: updatedMinuteOffset,
        ),
      );

  glados.Generator<GeneratedPrimaryProjectLinkSpec>
  get primaryProjectLinkSpec => glados.CombinableAny(this).combine4(
    primaryProjectSlot,
    glados.AnyUtils(this).choose([0, 1, 2, 3]),
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(-4, 4),
    (
      GeneratedPrimaryProjectSlot projectSlot,
      int agentSlot,
      bool deleted,
      int createdMinuteOffset,
    ) => GeneratedPrimaryProjectLinkSpec(
      projectSlot: projectSlot,
      agentSlot: agentSlot,
      deleted: deleted,
      createdMinuteOffset: createdMinuteOffset,
    ),
  );

  glados.Generator<GeneratedPrimaryTaskLinkSpec> get primaryTaskLinkSpec =>
      glados.CombinableAny(this).combine4(
        primaryTaskSlot,
        glados.AnyUtils(this).choose([0, 1, 2, 3]),
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        (
          GeneratedPrimaryTaskSlot taskSlot,
          int agentSlot,
          bool deleted,
          int createdMinuteOffset,
        ) => GeneratedPrimaryTaskLinkSpec(
          taskSlot: taskSlot,
          agentSlot: agentSlot,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
        ),
      );

  glados.Generator<GeneratedPrimaryLinkSelectionScenario>
  get primaryLinkSelectionScenario => glados.CombinableAny(this).combine3(
    glados.ListAnys(this).listWithLengthInRange(0, 8, primaryReportSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 8, primaryProjectLinkSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 8, primaryTaskLinkSpec),
    (
      List<GeneratedPrimaryReportSpec> reports,
      List<GeneratedPrimaryProjectLinkSpec> projectLinks,
      List<GeneratedPrimaryTaskLinkSpec> taskLinks,
    ) => GeneratedPrimaryLinkSelectionScenario(
      reports: reports,
      projectLinks: projectLinks,
      taskLinks: taskLinks,
    ),
  );

  glados.Generator<GeneratedBatchLinkKind> get batchLinkKind =>
      glados.AnyUtils(this).choose(GeneratedBatchLinkKind.values);

  glados.Generator<GeneratedBatchTaskSlot> get batchTaskSlot =>
      glados.AnyUtils(this).choose(GeneratedBatchTaskSlot.values);

  glados.Generator<GeneratedBatchRequestedTaskSlot>
  get batchRequestedTaskSlot =>
      glados.AnyUtils(this).choose(GeneratedBatchRequestedTaskSlot.values);

  glados.Generator<GeneratedBatchTaskLinkSpec> get batchTaskLinkSpec =>
      glados.CombinableAny(this).combine5(
        batchLinkKind,
        batchTaskSlot,
        glados.AnyUtils(this).choose([0, 1, 2, 3]),
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        (
          GeneratedBatchLinkKind kind,
          GeneratedBatchTaskSlot taskSlot,
          int agentSlot,
          bool deleted,
          int createdMinuteOffset,
        ) => GeneratedBatchTaskLinkSpec(
          kind: kind,
          taskSlot: taskSlot,
          agentSlot: agentSlot,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
        ),
      );

  glados.Generator<GeneratedBatchTaskLinkQueryScenario>
  get batchTaskLinkQueryScenario => glados.CombinableAny(this).combine2(
    glados.ListAnys(this).listWithLengthInRange(0, 9, batchTaskLinkSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 6, batchRequestedTaskSlot),
    (
      List<GeneratedBatchTaskLinkSpec> links,
      List<GeneratedBatchRequestedTaskSlot> requestedTaskSlots,
    ) => GeneratedBatchTaskLinkQueryScenario(
      links: links,
      requestedTaskSlots: requestedTaskSlots,
    ),
  );

  glados.Generator<GeneratedTemplateInstanceAssignmentSpec>
  get templateInstanceAssignmentSpec => glados.CombinableAny(this).combine4(
    templateSlot,
    glados.AnyUtils(this).choose([0, 1, 2, 3]),
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(-4, 4),
    (
      GeneratedTemplateSlot slot,
      int agentSlot,
      bool deleted,
      int createdMinuteOffset,
    ) => GeneratedTemplateInstanceAssignmentSpec(
      slot: slot,
      agentSlot: agentSlot,
      deleted: deleted,
      createdMinuteOffset: createdMinuteOffset,
    ),
  );

  glados.Generator<GeneratedTemplateInstanceTokenUsageSpec>
  get templateInstanceTokenUsageSpec => glados.CombinableAny(this).combine4(
    glados.AnyUtils(this).choose([0, 1, 2, 3]),
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(-4, 4),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      int agentSlot,
      bool deleted,
      int createdMinuteOffset,
      int seed,
    ) => GeneratedTemplateInstanceTokenUsageSpec(
      agentSlot: agentSlot,
      deleted: deleted,
      createdMinuteOffset: createdMinuteOffset,
      seed: seed,
    ),
  );

  glados.Generator<GeneratedTemplateInstanceReportSpec>
  get templateInstanceReportSpec => glados.CombinableAny(this).combine5(
    glados.AnyUtils(this).choose([0, 1, 2, 3]),
    reportScopeSlot,
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(-4, 4),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      int agentSlot,
      GeneratedReportScopeSlot scopeSlot,
      bool deleted,
      int createdMinuteOffset,
      int seed,
    ) => GeneratedTemplateInstanceReportSpec(
      agentSlot: agentSlot,
      scopeSlot: scopeSlot,
      deleted: deleted,
      createdMinuteOffset: createdMinuteOffset,
      seed: seed,
    ),
  );

  glados.Generator<GeneratedTemplateInstanceQueryScenario>
  get templateInstanceQueryScenario => glados.CombinableAny(this).combine5(
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 8, templateInstanceAssignmentSpec),
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 8, templateInstanceTokenUsageSpec),
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 8, templateInstanceReportSpec),
    glados.IntAnys(this).intInRange(1, 4),
    glados.IntAnys(this).intInRange(1, 4),
    (
      List<GeneratedTemplateInstanceAssignmentSpec> assignments,
      List<GeneratedTemplateInstanceTokenUsageSpec> tokenUsages,
      List<GeneratedTemplateInstanceReportSpec> reports,
      int usageLimit,
      int reportLimit,
    ) => GeneratedTemplateInstanceQueryScenario(
      assignments: assignments,
      tokenUsages: tokenUsages,
      reports: reports,
      usageLimit: usageLimit,
      reportLimit: reportLimit,
    ),
  );

  glados.Generator<GeneratedWakeTemplateShape> get wakeTemplateShape =>
      glados.AnyUtils(this).choose(GeneratedWakeTemplateShape.values);

  glados.Generator<GeneratedTemplateSlot> get templateSlot =>
      glados.AnyUtils(this).choose(GeneratedTemplateSlot.values);

  glados.Generator<AgentTemplateVersionStatus> get templateVersionStatus =>
      glados.AnyUtils(this).choose(AgentTemplateVersionStatus.values);

  glados.Generator<GeneratedTemplateVersionSpec> get templateVersionSpec =>
      glados.CombinableAny(this).combine5(
        templateSlot,
        glados.IntAnys(this).intInRange(1, 8),
        templateVersionStatus,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedTemplateSlot slot,
          int version,
          AgentTemplateVersionStatus status,
          bool deleted,
          int seed,
        ) => GeneratedTemplateVersionSpec(
          slot: slot,
          version: version,
          status: status,
          deleted: deleted,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedTemplateHeadSpec> get templateHeadSpec =>
      glados.CombinableAny(this).combine6(
        templateSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(0, 8),
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedTemplateSlot slot,
          bool pointsToExisting,
          int versionOrdinal,
          bool deleted,
          int updatedMinuteOffset,
          int seed,
        ) => GeneratedTemplateHeadSpec(
          slot: slot,
          pointsToExisting: pointsToExisting,
          versionOrdinal: versionOrdinal,
          deleted: deleted,
          updatedMinuteOffset: updatedMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedTemplateAssignmentSpec>
  get templateAssignmentSpec => glados.CombinableAny(this).combine4(
    templateSlot,
    glados.AnyUtils(this).choose([0, 1, 2]),
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      GeneratedTemplateSlot slot,
      int agentSlot,
      bool deleted,
      int seed,
    ) => GeneratedTemplateAssignmentSpec(
      slot: slot,
      agentSlot: agentSlot,
      deleted: deleted,
      seed: seed,
    ),
  );

  glados.Generator<GeneratedTemplateResolutionScenario>
  get templateResolutionScenario => glados.CombinableAny(this).combine3(
    glados.ListAnys(this).listWithLengthInRange(0, 8, templateVersionSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 5, templateHeadSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 6, templateAssignmentSpec),
    (
      List<GeneratedTemplateVersionSpec> versions,
      List<GeneratedTemplateHeadSpec> heads,
      List<GeneratedTemplateAssignmentSpec> assignments,
    ) => GeneratedTemplateResolutionScenario(
      versions: versions,
      heads: heads,
      assignments: assignments,
    ),
  );

  glados.Generator<WakeRunStatus> get wakeRunStatus =>
      glados.AnyUtils(this).choose(WakeRunStatus.values);

  glados.Generator<GeneratedWakeLifecycleSpec> get wakeLifecycleSpec =>
      glados.CombinableAny(this).combine7(
        wakeRunStatus,
        wakeTemplateShape,
        glados.AnyUtils(this).choose([0, 1]),
        glados.AnyUtils(this).choose([0, 1]),
        glados.IntAnys(this).intInRange(-8, 8),
        glados.IntAnys(this).intInRange(-1, 5),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          WakeRunStatus status,
          GeneratedWakeTemplateShape templateShape,
          int agentSlot,
          int threadSlot,
          int createdHourOffset,
          int durationMinutes,
          int seed,
        ) => GeneratedWakeLifecycleSpec(
          status: status,
          templateShape: templateShape,
          agentSlot: agentSlot,
          threadSlot: threadSlot,
          createdHourOffset: createdHourOffset,
          durationMinutes: durationMinutes,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedWakeLifecycleScenario> get wakeLifecycleScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(1, 8, wakeLifecycleSpec),
        glados.IntAnys(this).intInRange(1, 4),
        (
          List<GeneratedWakeLifecycleSpec> specs,
          int templateLimit,
        ) => GeneratedWakeLifecycleScenario(
          specs: specs,
          templateLimit: templateLimit,
        ),
      );
}
