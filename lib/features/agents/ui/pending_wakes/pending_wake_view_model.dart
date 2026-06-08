import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Domain view-model for a Settings → Agents → Pending Wakes row.
///
/// Hydrated up-front in [agentPendingWakeRowVmsProvider] so the page
/// can filter / sort / group on plain values without per-row async
/// lookups. The original [PendingWakeRecord] is kept on the VM so the
/// adapter can pull `agentId` for navigation and `dueAt` for the
/// page-scoped countdown ticker without re-walking the record list.
class PendingWakeVm {
  const PendingWakeVm({
    required this.id,
    required this.agentId,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.lifecycle,
    required this.type,
    required this.dueAt,
  });

  /// Stable id, mirrors [PendingWakeRecord.id].
  final String id;

  /// `AgentIdentityEntity.agentId` — used for navigation + for
  /// service-call targeting (delete).
  final String agentId;

  /// Primary line on the row: either the linked subject's title
  /// (task / project) or the agent's display name when there's no
  /// linked subject.
  final String title;

  /// Secondary line — the agent display name when [title] is the
  /// subject. `null` when there's no separate subject (no duplicate
  /// row).
  final String? subtitle;

  final String kind;
  final AgentLifecycle lifecycle;
  final PendingWakeType type;
  final DateTime dueAt;
}

/// All pending wake records joined with their resolved subject titles.
/// One [Future.wait] per fetch keeps the per-record title lookups
/// parallel.
final FutureProvider<List<PendingWakeVm>> agentPendingWakeRowVmsProvider =
    FutureProvider.autoDispose<List<PendingWakeVm>>((ref) async {
      final records = await ref.watch(pendingWakeRecordsProvider.future);

      final titles = await Future.wait(
        records.map(
          (r) => ref.watch(
            pendingWakeTargetTitleProvider(_subjectEntryId(r)).future,
          ),
        ),
      );

      return [
        for (var i = 0; i < records.length; i++) _toVm(records[i], titles[i]),
      ];
    });

PendingWakeVm _toVm(PendingWakeRecord record, String? rawSubjectTitle) {
  final agentName = record.agent.displayName;
  // A workspace-scoped wake (planner day pre-warm) carries its subject on the
  // record; otherwise fall back to the resolved linked-entry title.
  final subjectTitle = (record.subjectLabel?.trim().isNotEmpty ?? false)
      ? record.subjectLabel!.trim()
      : rawSubjectTitle?.trim();
  final hasSubject =
      subjectTitle != null &&
      subjectTitle.isNotEmpty &&
      subjectTitle != agentName;
  return PendingWakeVm(
    id: record.id,
    agentId: record.agent.agentId,
    title: hasSubject ? subjectTitle : agentName,
    subtitle: hasSubject ? agentName : null,
    kind: record.agent.kind,
    lifecycle: record.agent.lifecycle,
    type: record.type,
    dueAt: record.dueAt,
  );
}

String? _subjectEntryId(PendingWakeRecord record) {
  // The day planner no longer pins an `activeDayId` slot — its day-scoped
  // wakes carry their subject as a workspace label on the record instead
  // (see [PendingWakeRecord.subjectLabel]). Only task/project agents resolve
  // their subject from a linked journal entry here.
  if (record.subjectLabel != null) return null;
  return record.state.slots.activeTaskId ?? record.state.slots.activeProjectId;
}

/// Localized label for a [PendingWakeType]. Same copy the legacy
/// `_PendingWakeCard` rendered as a wake-type badge.
String pendingWakeTypeLabel(AppLocalizations messages, PendingWakeType type) {
  return switch (type) {
    PendingWakeType.pending => messages.agentPendingWakesPendingLabel,
    PendingWakeType.scheduled => messages.agentPendingWakesScheduledLabel,
  };
}

/// Localized label for an agent kind id (matches what the legacy
/// pending-wake card showed). Falls back to the raw kind so unknown
/// kinds still render something readable.
String pendingWakeKindLabel(AppLocalizations messages, String kind) {
  return switch (kind) {
    AgentKinds.taskAgent => messages.agentInstancesKindTaskAgent,
    AgentKinds.dayAgent => messages.agentTemplateKindDayAgent,
    AgentKinds.projectAgent => messages.agentTemplateKindProjectAgent,
    AgentKinds.templateImprover => messages.agentTemplateKindImprover,
    _ => kind,
  };
}
