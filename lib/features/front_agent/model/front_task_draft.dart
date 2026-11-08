import 'package:clock/clock.dart';
import 'package:lotti/classes/task.dart';

/// The longest title a draft keeps.
const int frontTaskTitleMaxLength = 200;

/// The longest instructions a draft keeps.
const int frontTaskInstructionsMaxLength = 4000;

/// The largest estimate a draft accepts, in minutes: a working fortnight.
const int frontTaskMaxEstimateMinutes = 80 * 60;

/// How far back a dictated timer may start, in minutes: one day.
const int frontTaskMaxStartedMinutesAgo = 24 * 60;

/// The task a `new` segment would become, as the router read it from the
/// user's words: every field the agent fills at creation. What the draft
/// leaves out — and the project, checklist and agent's proposals — stays
/// for the user to set on the task page.
///
/// [startedAt] is absolute: a dictated "started ten minutes ago" is
/// resolved against the routing turn's clock, so a tap hours later still
/// starts the timer when the user said the work began.
class FrontTaskDraft {
  const FrontTaskDraft({
    required this.title,
    this.instructions,
    this.categoryId,
    this.priority,
    this.due,
    this.estimate,
    this.startedAt,
  });

  final String title;

  /// What to do and how, from the user's words: the task's body.
  final String? instructions;
  final String? categoryId;
  final TaskPriority? priority;

  /// A local calendar day.
  final DateTime? due;
  final Duration? estimate;

  /// When the work began: set, the task is in progress and a timer runs
  /// from here.
  final DateTime? startedAt;

  /// Reads the model's `task` object. Null without a title; any other field
  /// the model got wrong is left out rather than failing the dispatch — a
  /// misheard due date must not lose the task. [categoryExists] decides
  /// which category ids stand.
  static FrontTaskDraft? fromModel(
    Map<String, dynamic> args, {
    required bool Function(String id) categoryExists,
  }) {
    final title = _text(args['title'], frontTaskTitleMaxLength);
    if (title == null) return null;
    final categoryId = _text(args['categoryId'], 200);
    final minutesAgo = _intIn(
      args['startedMinutesAgo'],
      0,
      frontTaskMaxStartedMinutesAgo,
    );
    final estimate = _intIn(
      args['estimateMinutes'],
      1,
      frontTaskMaxEstimateMinutes,
    );
    return FrontTaskDraft(
      title: title,
      instructions: _text(args['instructions'], frontTaskInstructionsMaxLength),
      categoryId: categoryId != null && categoryExists(categoryId)
          ? categoryId
          : null,
      priority: _priority(args['priority']),
      due: _day(args['due']),
      estimate: estimate == null ? null : Duration(minutes: estimate),
      startedAt: minutesAgo == null
          ? null
          : clock.now().subtract(Duration(minutes: minutesAgo)),
    );
  }

  Map<String, Object?> toJson() => {
    'title': title,
    if (instructions != null) 'instructions': instructions,
    if (categoryId != null) 'categoryId': categoryId,
    if (priority != null) 'priority': priority!.short,
    if (due != null) 'due': _isoDay(due!),
    if (estimate != null) 'estimateMinutes': estimate!.inMinutes,
    if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
  };

  /// Reads a stored draft; null when it is not one [toJson] wrote.
  static FrontTaskDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    final title = json['title'];
    if (title is! String || title.isEmpty) return null;
    final estimate = json['estimateMinutes'];
    return FrontTaskDraft(
      title: title,
      instructions: _string(json['instructions']),
      categoryId: _string(json['categoryId']),
      priority: _priority(json['priority']),
      due: _day(json['due']),
      estimate: estimate is int ? Duration(minutes: estimate) : null,
      startedAt: switch (json['startedAt']) {
        final String iso => DateTime.tryParse(iso)?.toLocal(),
        _ => null,
      },
    );
  }
}

String? _string(Object? value) => value is String ? value : null;

String? _text(Object? value, int maxLength) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length <= maxLength
      ? trimmed
      : trimmed.substring(0, maxLength);
}

int? _intIn(Object? value, int min, int max) {
  final number = value is num ? value.round() : null;
  return number != null && number >= min && number <= max ? number : null;
}

TaskPriority? _priority(Object? value) => value is String
    ? TaskPriority.values
          .where((p) => p.short == value.trim().toUpperCase())
          .firstOrNull
    : null;

final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

DateTime? _day(Object? value) {
  final match = value is String ? _isoDate.firstMatch(value.trim()) : null;
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime rolls 2026-02-30 over into March: such a day was never said.
  return date.month == month && date.day == day ? date : null;
}

String _isoDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
