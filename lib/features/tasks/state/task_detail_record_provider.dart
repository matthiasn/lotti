import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_detail_record_provider.g.dart';

/// Builds a [TaskRecord] from real data for display in the desktop detail view.
///
/// Bridges the showcase data model with live providers, enabling reuse
/// of the existing showcase detail widgets with real task data.
@riverpod
Future<TaskRecord?> taskDetailRecord(Ref ref, String taskId) async {
  final entryAsync = ref.watch(entryControllerProvider(id: taskId));
  final entryState = entryAsync.value;
  final entry = entryState?.entry;
  if (entry is! Task) return null;

  final cache = getIt<EntitiesCacheService>();
  final category = cache.getCategoryById(entry.meta.categoryId);
  if (category == null) return null;

  // Resolve project
  final project = await ref.watch(projectForTaskProvider(taskId).future);
  final projectTitle = project?.data.title ?? '';

  // Resolve labels
  final labelIds = entry.meta.labelIds ?? <String>[];
  final labels = <TaskShowcaseLabel>[];
  for (final labelId in labelIds) {
    final label = cache.getLabelById(labelId);
    if (label != null) {
      labels.add(
        TaskShowcaseLabel(
          id: label.id,
          label: label.name,
          color: colorFromCssHex(label.color),
        ),
      );
    }
  }

  // Resolve linked entries
  final linkedEntities = ref.watch(
    resolvedOutgoingLinkedEntriesProvider(taskId),
  );

  // Build time entries from linked JournalEntry items
  final trackerEntries = <TaskShowcaseTimeEntry>[];
  var totalTrackedDuration = Duration.zero;
  for (final linked in linkedEntities) {
    if (linked is JournalEntry) {
      final duration = linked.meta.dateTo.difference(linked.meta.dateFrom);
      totalTrackedDuration += duration;
      trackerEntries.add(
        TaskShowcaseTimeEntry(
          title: linked.entryText?.plainText.trim() ?? '',
          subtitle: formatDateForDetail(linked.meta.dateFrom),
          durationLabel: formatDurationForDetail(duration),
          note: linked.entryText?.plainText.trim() ?? '',
        ),
      );
    }
  }

  // Build checklist items from linked Checklist entries
  final checklistItems = <TaskShowcaseChecklistItem>[];
  for (final linked in linkedEntities) {
    if (linked is ChecklistItem) {
      checklistItems.add(
        TaskShowcaseChecklistItem(
          title: linked.data.title,
          done: linked.data.isChecked,
        ),
      );
    }
  }

  // Build audio entries from linked JournalAudio items
  final audioEntries = <TaskShowcaseAudioEntry>[];
  for (final linked in linkedEntities) {
    if (linked is JournalAudio) {
      final duration = linked.meta.dateTo.difference(linked.meta.dateFrom);
      audioEntries.add(
        TaskShowcaseAudioEntry(
          title: linked.data.audioFile.split('/').last,
          subtitle: formatDateForDetail(linked.meta.dateFrom),
          durationLabel: formatDurationForDetail(duration),
          transcriptPreview: linked.entryText?.plainText.trim() ?? '',
          waveform: const [
            0.3,
            0.5,
            0.7,
            0.4,
            0.8,
            0.6,
            0.3,
            0.5,
            0.7,
            0.4,
            0.6,
          ],
        ),
      );
    }
  }

  // Resolve AI summary via agent report
  final agentRepository = ref.watch(agentRepositoryProvider);
  final reports = await agentRepository.getLatestTaskReportsForTaskIds(
    [taskId],
  );
  final report = reports[taskId];
  final aiSummary = report?.tldr?.trim() ?? report?.oneLiner?.trim() ?? '';

  return TaskRecord(
    task: entry,
    category: category,
    sectionTitle: '',
    sectionDate: entry.meta.dateFrom,
    projectTitle: projectTitle,
    timeRange: '',
    labels: labels,
    aiSummary: aiSummary,
    description: entry.entryText?.plainText.trim() ?? '',
    trackedDurationLabel: formatDurationForDetail(totalTrackedDuration),
    trackerEntries: trackerEntries,
    checklistItems: checklistItems,
    audioEntries: audioEntries,
  );
}

@visibleForTesting
String formatDurationForDetail(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}

@visibleForTesting
String formatDateForDetail(DateTime date) {
  final day = date.day;
  const monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = monthNames[date.month - 1];
  final year = date.year % 100;
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day $month $year, $hour:$minute';
}
