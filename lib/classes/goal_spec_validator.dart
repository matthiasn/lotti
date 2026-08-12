import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_window.dart';

/// Validates goal criteria before persistence and before evaluation
/// (ADR 0053; the PR-1 validator promised by the design doc).
///
/// Two layers, because they catch different corruption:
///
/// - [criterionJsonIssues] runs on the RAW decoded JSON, before
///   `GoalCriterion.fromJson`: json_serializable coerces numbers with
///   `.toInt()`, so a malformed payload like `{"targetCount": 1.9}` would
///   silently truncate to 1 — the value must be rejected while it is still
///   visible.
/// - [criterionIssues] runs on the decoded tree: empty composites,
///   impossible quotas (`successes > criteria.length`), non-positive
///   counts, non-finite targets.
///
/// [decodeValidated] is the persistence-path entry: it applies both layers
/// and throws a [FormatException] naming every issue instead of storing or
/// evaluating a lie.
abstract final class GoalSpecValidator {
  /// Issues visible only in the raw JSON (lost after decoding).
  static List<String> criterionJsonIssues(
    Map<String, dynamic> json, {
    String path = 'criteria',
  }) {
    final issues = <String>[];

    void requireIntegral(String key) {
      final value = json[key];
      if (value is num && value % 1 != 0) {
        issues.add(
          '$path.$key: $value is fractional and would be silently '
          'truncated to ${value.toInt()}',
        );
      }
    }

    switch (json['runtimeType']) {
      case 'habit':
        requireIntegral('targetCount');
        _windowJsonIssues(json['window'], '$path.window', issues);
      case 'metric' || 'measurable':
        _windowJsonIssues(json['window'], '$path.window', issues);
      case 'categoryTime':
        _windowJsonIssues(json['window'], '$path.window', issues);
        final dailyTimeRange = json['dailyTimeRange'];
        if (dailyTimeRange is Map<String, dynamic>) {
          for (final key in ['startMinute', 'endMinute']) {
            final value = dailyTimeRange[key];
            if (value is num && value % 1 != 0) {
              issues.add(
                '$path.dailyTimeRange.$key: $value is fractional and would '
                'be silently truncated to ${value.toInt()}',
              );
            }
          }
        }
      case 'atLeastCount':
        requireIntegral('successes');
        _recurse(json, path, issues);
      case 'allOf' || 'anyOf':
        _recurse(json, path, issues);
    }
    return issues;
  }

  static void _recurse(
    Map<String, dynamic> json,
    String path,
    List<String> issues,
  ) {
    final criteria = json['criteria'];
    if (criteria is! List) return;
    for (var i = 0; i < criteria.length; i++) {
      final child = criteria[i];
      if (child is Map<String, dynamic>) {
        issues.addAll(criterionJsonIssues(child, path: '$path[$i]'));
      }
    }
  }

  static void _windowJsonIssues(
    Object? window,
    String path,
    List<String> issues,
  ) {
    if (window is! Map<String, dynamic>) return;
    if (window['runtimeType'] != 'rollingDays') return;
    final count = window['count'];
    if (count is num && count % 1 != 0) {
      issues.add(
        '$path.count: $count is fractional and would be silently '
        'truncated to ${count.toInt()}',
      );
    }
  }

  /// Structural issues in a decoded tree.
  static List<String> criterionIssues(GoalCriterion criterion) {
    final issues = <String>[];
    final seenIds = <String>{};
    _structuralIssues(criterion, issues, seenIds);
    return issues;
  }

  static void _structuralIssues(
    GoalCriterion criterion,
    List<String> issues,
    Set<String> seenIds,
  ) {
    final id = criterion.criterionId;
    // Per-criterion results are keyed by criterionId (evaluator results
    // map, goalProgress rows): a duplicate would silently overwrite one
    // leg's history with another's.
    if (!seenIds.add(id)) {
      issues.add('$id: duplicate criterionId');
    }
    switch (criterion) {
      case GoalCriterionMetric(:final dataType, :final target, :final window):
        _requireIdentifier(id, 'dataType', dataType, issues);
        _requireFiniteTarget(id, target, issues);
        _requirePositiveRollingCount(id, window, issues);
      case GoalCriterionMeasurable(
        :final dataTypeId,
        :final target,
        :final window,
      ):
        _requireIdentifier(id, 'dataTypeId', dataTypeId, issues);
        _requireFiniteTarget(id, target, issues);
        _requirePositiveRollingCount(id, window, issues);
      case GoalCriterionHabit(
        :final habitId,
        :final targetCount,
        :final window,
      ):
        _requireIdentifier(id, 'habitId', habitId, issues);
        if (targetCount < 1) {
          issues.add('$id: targetCount must be at least 1, was $targetCount');
        }
        _requirePositiveRollingCount(id, window, issues);
      case GoalCriterionCategoryTime(
        :final categoryId,
        :final targetHours,
        :final window,
        :final dailyTimeRange,
      ):
        _requireIdentifier(id, 'categoryId', categoryId, issues);
        _requireFiniteTarget(id, targetHours, issues);
        if (targetHours < 0) {
          issues.add(
            '$id: targetHours must not be negative, was $targetHours',
          );
        }
        _requirePositiveRollingCount(id, window, issues);
        if (dailyTimeRange case final range?) {
          _requireMinuteOfDay(id, 'startMinute', range.startMinute, issues);
          _requireMinuteOfDay(id, 'endMinute', range.endMinute, issues);
          if (range.startMinute == range.endMinute &&
              range.startMinute >= 0 &&
              range.startMinute < Duration.minutesPerDay) {
            issues.add(
              '$id: daily time range endpoints must differ; omit the range '
              'to measure the full day',
            );
          }
        }
      case GoalCriterionAllOf(:final criteria) ||
          GoalCriterionAnyOf(:final criteria):
        if (criteria.isEmpty) {
          issues.add('$id: composite has no children');
        }
        for (final child in criteria) {
          _structuralIssues(child, issues, seenIds);
        }
      case GoalCriterionAtLeastCount(:final criteria, :final successes):
        if (criteria.isEmpty) {
          issues.add('$id: composite has no children');
        }
        if (successes < 1) {
          issues.add('$id: successes must be at least 1, was $successes');
        } else if (criteria.isNotEmpty && successes > criteria.length) {
          issues.add(
            '$id: requires $successes of ${criteria.length} children — '
            'unsatisfiable',
          );
        }
        for (final child in criteria) {
          _structuralIssues(child, issues, seenIds);
        }
    }
  }

  /// A blank signal identifier queries an empty namespace and evaluates a
  /// habit as "zero completions with full coverage" — corrupt config must
  /// be rejected, not scored.
  static void _requireIdentifier(
    String id,
    String field,
    String value,
    List<String> issues,
  ) {
    if (value.trim().isEmpty) {
      issues.add('$id: $field must not be blank');
    }
  }

  static void _requireFiniteTarget(
    String id,
    num target,
    List<String> issues,
  ) {
    if (target is double && !target.isFinite) {
      issues.add('$id: target must be finite, was $target');
    }
  }

  static void _requireMinuteOfDay(
    String id,
    String field,
    int minute,
    List<String> issues,
  ) {
    if (minute < 0 || minute >= Duration.minutesPerDay) {
      issues.add(
        '$id: $field must be between 0 and 1439, was $minute',
      );
    }
  }

  static void _requirePositiveRollingCount(
    String id,
    GoalWindow window,
    List<String> issues,
  ) {
    if (window case GoalWindowRollingDays(:final count) when count < 1) {
      issues.add('$id: rolling window needs at least one day, had $count');
    }
  }

  /// Decodes and fully validates a criteria tree; throws [FormatException]
  /// naming every issue rather than persisting or evaluating a lie.
  static GoalCriterion decodeValidated(Map<String, dynamic> json) {
    final rawIssues = criterionJsonIssues(json);
    if (rawIssues.isNotEmpty) {
      throw FormatException('Invalid goal criteria: ${rawIssues.join('; ')}');
    }
    final criterion = GoalCriterion.fromJson(json);
    final issues = criterionIssues(criterion);
    if (issues.isNotEmpty) {
      throw FormatException('Invalid goal criteria: ${issues.join('; ')}');
    }
    return criterion;
  }
}
