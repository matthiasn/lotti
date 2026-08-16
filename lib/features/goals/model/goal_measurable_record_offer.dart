import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';

@immutable
class GoalMeasurableRecordItem {
  const GoalMeasurableRecordItem({
    required this.day,
    required this.value,
    required this.estimated,
  });

  final DateTime day;
  final num value;
  final bool estimated;

  GoalMeasurableRecordItem copyWith({num? value}) => GoalMeasurableRecordItem(
    day: day,
    value: value ?? this.value,
    estimated: estimated,
  );
}

@immutable
class GoalMeasurableRecordOffer {
  const GoalMeasurableRecordOffer({
    required this.sourceMessageId,
    required this.dataTypeId,
    required this.measurableName,
    required this.unitName,
    required this.items,
  });

  final String sourceMessageId;
  final String dataTypeId;
  final String measurableName;
  final String unitName;
  final List<GoalMeasurableRecordItem> items;
}

/// Finds an explicit quantity/unit mention for a measurable that is already
/// linked to the active goal. Silence and unlinked measurables never produce
/// an offer.
GoalMeasurableRecordOffer? parseGoalMeasurableRecordOffer({
  required AgentChatMessage message,
  required GoalCriterion criteria,
  required List<MeasurableDataType> measurables,
  required DateTime reference,
  required Map<DateTime, List<String>> recentDayLabels,
}) {
  if (message.role != AgentChatRole.user) return null;
  final linkedIds = <String>{};
  void collect(GoalCriterion criterion) {
    switch (criterion) {
      case GoalCriterionMeasurable(:final dataTypeId):
        linkedIds.add(dataTypeId);
      case GoalCriterionMetric() ||
          GoalCriterionHabit() ||
          GoalCriterionCategoryTime() ||
          GoalCriterionLabelTime():
        return;
      case GoalCriterionAllOf(criteria: final children):
        children.forEach(collect);
      case GoalCriterionAnyOf(criteria: final children):
        children.forEach(collect);
      case GoalCriterionAtLeastCount(criteria: final children):
        children.forEach(collect);
    }
  }

  collect(criteria);
  if (linkedIds.isEmpty) return null;
  final text = message.text.toLowerCase();
  final candidates = <({MeasurableDataType measurable, RegExpMatch match})>[];
  for (final measurable in measurables) {
    if (!linkedIds.contains(measurable.id)) continue;
    final unit = measurable.unitName.trim();
    if (unit.isEmpty) continue;
    final unitPattern = _unitPattern(unit);
    final matches = RegExp(
      r'(?<![\p{L}\p{N}])([0-9]+(?:[.,][0-9]+)?)\s*' +
          unitPattern +
          r'(?![\p{L}\p{N}])',
      caseSensitive: false,
      unicode: true,
    ).allMatches(text).toList();
    if (matches.length == 1) {
      candidates.add((measurable: measurable, match: matches.single));
    } else if (matches.length > 1) {
      return null;
    }
  }
  if (candidates.isEmpty) return null;
  final selected = switch (candidates) {
    [final only] => only,
    _ =>
      candidates
          .where(
            (candidate) => _containsWord(
              text,
              candidate.measurable.displayName,
            ),
          )
          .singleOrNull,
  };
  if (selected == null) return null;
  final value = num.tryParse(
    selected.match.group(1)!.replaceAll(',', '.'),
  );
  if (value == null || value <= 0) return null;
  final mentionedDays = <DateTime>[];
  for (final entry in recentDayLabels.entries) {
    if (entry.value.any((label) => _containsWord(text, label))) {
      mentionedDays.add(GoalWindow.dayUtc(entry.key));
    }
  }
  mentionedDays.sort();
  final days = mentionedDays.isEmpty
      ? [GoalWindow.dayUtc(reference)]
      : mentionedDays;
  final estimated = days.length > 1;
  final perDay = estimated ? value / days.length : value;
  return GoalMeasurableRecordOffer(
    sourceMessageId: message.id,
    dataTypeId: selected.measurable.id,
    measurableName: selected.measurable.displayName,
    unitName: selected.measurable.unitName.trim(),
    items: [
      for (final day in days)
        GoalMeasurableRecordItem(
          day: day,
          value: perDay,
          estimated: estimated,
        ),
    ],
  );
}

String _unitPattern(String unit) {
  final escaped = RegExp.escape(unit.toLowerCase());
  if (unit.length > 1 && unit.toLowerCase().endsWith('s')) {
    return '${escaped.substring(0, escaped.length - 1)}s?';
  }
  return '$escaped(?:s)?';
}

bool _containsWord(String text, String rawLabel) {
  final label = rawLabel.trim().toLowerCase();
  if (label.isEmpty) return false;
  return RegExp(
    '(?<![\\p{L}\\p{N}])${RegExp.escape(label)}(?![\\p{L}\\p{N}])',
    unicode: true,
  ).hasMatch(text);
}
