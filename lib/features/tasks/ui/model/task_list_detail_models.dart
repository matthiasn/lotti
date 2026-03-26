import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';

enum TaskShowcaseDetailSection {
  timer,
  todo,
  audio,
  images,
  linked,
}

class TaskShowcaseLabel {
  const TaskShowcaseLabel({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;
}

class TaskShowcaseTimeEntry {
  const TaskShowcaseTimeEntry({
    required this.title,
    required this.subtitle,
    required this.durationLabel,
    required this.note,
    this.active = false,
  });

  final String title;
  final String subtitle;
  final String durationLabel;
  final String note;
  final bool active;
}

class TaskShowcaseChecklistItem {
  const TaskShowcaseChecklistItem({
    required this.title,
    required this.done,
  });

  final String title;
  final bool done;
}

class TaskShowcaseAudioEntry {
  const TaskShowcaseAudioEntry({
    required this.title,
    required this.subtitle,
    required this.durationLabel,
    required this.transcriptPreview,
    required this.waveform,
  });

  final String title;
  final String subtitle;
  final String durationLabel;
  final String transcriptPreview;
  final List<double> waveform;
}

class TaskRecord {
  const TaskRecord({
    required this.task,
    required this.category,
    required this.sectionTitle,
    required this.sectionDate,
    required this.projectTitle,
    required this.timeRange,
    required this.labels,
    required this.aiSummary,
    required this.description,
    required this.trackedDurationLabel,
    required this.trackerEntries,
    required this.checklistItems,
    required this.audioEntries,
  });

  final Task task;
  final CategoryDefinition category;
  final String sectionTitle;
  final DateTime sectionDate;
  final String projectTitle;
  final String timeRange;
  final List<TaskShowcaseLabel> labels;
  final String aiSummary;
  final String description;
  final String trackedDurationLabel;
  final List<TaskShowcaseTimeEntry> trackerEntries;
  final List<TaskShowcaseChecklistItem> checklistItems;
  final List<TaskShowcaseAudioEntry> audioEntries;
}

class TaskListSection {
  const TaskListSection({
    required this.title,
    required this.sectionDate,
    required this.tasks,
  });

  final String title;
  final DateTime sectionDate;
  final List<TaskRecord> tasks;
}

class TaskListData {
  const TaskListData({
    required this.categories,
    required this.tasks,
    required this.currentTime,
  });

  final List<CategoryDefinition> categories;
  final List<TaskRecord> tasks;
  final DateTime currentTime;
}
