import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';

// Presentation models for the task list/detail "showcase" UI. They flatten the
// domain entities (Task, categories, linked entries) into pre-formatted,
// render-ready view models so the showcase widgets contain no business logic.
// Built from live data by the showcase controllers and from fixtures by the
// widgetbook mocks.

/// A label chip's display data: stable [id], rendered [label] text, and chip
/// [color].
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

/// One time-tracker row in the detail view: pre-formatted title/subtitle,
/// [durationLabel], free-text [note], and whether it is the currently [active]
/// (running) entry.
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

/// A checklist row in the detail view: its [title] and checked state [done].
class TaskShowcaseChecklistItem {
  const TaskShowcaseChecklistItem({
    required this.title,
    required this.done,
  });

  final String title;
  final bool done;
}

/// One audio recording in the detail view: title/subtitle, [durationLabel], a
/// short [transcriptPreview], and the [waveform] amplitude samples to plot.
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

/// The full, render-ready view model for a single task in the showcase: the
/// underlying [task] plus its category, section grouping (title/date), project,
/// labels, AI summary, description, and the pre-built lists of tracker, audio,
/// and checklist rows. Drives both the list row and the detail pane.
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

/// A group of [TaskRecord]s under one section header, ordered by [sectionDate]
/// (used to sort sections newest-first).
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

/// The raw input to `TaskListDetailState`: all known [categories], the full
/// [tasks] list (unfiltered/unsorted), and the [currentTime] used for relative
/// date formatting.
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
