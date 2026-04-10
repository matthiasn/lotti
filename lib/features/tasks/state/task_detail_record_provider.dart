import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_detail_record_provider.g.dart';

final _dateFormat = DateFormat('d MMM yy, HH:mm');

// TODO(mn): Replace with real waveform data from AudioWaveformService
// once the detail view supports lazy-loading per audio entry.
const _placeholderWaveform = [
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
];

/// Builds a [TaskRecord] from real data for display in the desktop detail view.
///
/// Bridges the showcase data model with live providers, enabling reuse
/// of the existing showcase detail widgets with real task data.
@riverpod
Future<TaskRecord?> taskDetailRecord(Ref ref, String taskId) async {
  final entryAsync = ref.watch(entryControllerProvider(id: taskId));
  final entry = entryAsync.value?.entry;
  if (entry is! Task) return null;

  final cache = getIt<EntitiesCacheService>();
  final category = cache.getCategoryById(entry.meta.categoryId);
  if (category == null) return null;

  final project = await ref.watch(projectForTaskProvider(taskId).future);

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

  final linkedEntities = ref.watch(
    resolvedOutgoingLinkedEntriesProvider(taskId),
  );

  final trackerEntries = <TaskShowcaseTimeEntry>[];
  final checklistItems = <TaskShowcaseChecklistItem>[];
  final audioEntries = <TaskShowcaseAudioEntry>[];
  var totalTrackedDuration = Duration.zero;

  for (final linked in linkedEntities) {
    switch (linked) {
      case JournalEntry():
        final duration = linked.meta.dateTo.difference(linked.meta.dateFrom);
        totalTrackedDuration += duration;
        final text = linked.entryText?.plainText.trim() ?? '';
        trackerEntries.add(
          TaskShowcaseTimeEntry(
            title: text,
            subtitle: _dateFormat.format(linked.meta.dateFrom),
            durationLabel: showcaseFormatDuration(duration),
            note: text,
          ),
        );
      case ChecklistItem():
        checklistItems.add(
          TaskShowcaseChecklistItem(
            title: linked.data.title,
            done: linked.data.isChecked,
          ),
        );
      case JournalAudio():
        final duration = linked.meta.dateTo.difference(linked.meta.dateFrom);
        audioEntries.add(
          TaskShowcaseAudioEntry(
            title: linked.data.audioFile.split('/').last,
            subtitle: _dateFormat.format(linked.meta.dateFrom),
            durationLabel: showcaseFormatDuration(duration),
            transcriptPreview: linked.entryText?.plainText.trim() ?? '',
            waveform: _placeholderWaveform,
          ),
        );
      default:
        break;
    }
  }

  final agentRepository = ref.watch(agentRepositoryProvider);
  final reports = await agentRepository.getLatestTaskReportsForTaskIds(
    [taskId],
  );
  final report = reports[taskId];
  final aiSummary = report?.tldr?.trim() ?? report?.oneLiner?.trim() ?? '';

  return TaskRecord(
    task: entry,
    category: category,
    // Not used by the detail view — required by the shared TaskRecord model.
    sectionTitle: '',
    sectionDate: entry.meta.dateFrom,
    projectTitle: project?.data.title ?? '',
    timeRange: '',
    labels: labels,
    aiSummary: aiSummary,
    description: entry.entryText?.plainText.trim() ?? '',
    trackedDurationLabel: showcaseFormatDuration(totalTrackedDuration),
    trackerEntries: trackerEntries,
    checklistItems: checklistItems,
    audioEntries: audioEntries,
  );
}
