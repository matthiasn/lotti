import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';

/// What kind of journal series a signal row watches.
enum HabitSignalKind { measurable, health, workout }

/// How a signal's day value satisfies its rule.
enum HabitSignalMode {
  /// Any entry / reading / workout that day.
  any,

  /// The day's value must reach [HabitSignalForm.threshold].
  atLeast,

  /// The day's value must stay at or under [HabitSignalForm.threshold].
  atMost,
}

/// How several signals combine into "done".
enum HabitCompositeRule { any, all, atLeast }

/// One row of the editor's signal card.
@immutable
class HabitSignalForm {
  const HabitSignalForm({
    required this.kind,
    required this.id,
    this.mode = HabitSignalMode.any,
    this.threshold,
    this.workoutValueType,
    this.title,
  });

  final HabitSignalKind kind;

  /// Measurable id, health data type or raw workout type.
  final String id;
  final HabitSignalMode mode;
  final num? threshold;

  /// For workouts: which dimension the threshold applies to; `null` with
  /// [HabitSignalMode.any] means any workout of the type.
  final WorkoutValueType? workoutValueType;
  final String? title;

  HabitSignalForm copyWith({
    HabitSignalMode? mode,
    num? threshold,
    WorkoutValueType? workoutValueType,
    bool clearThreshold = false,
    bool clearWorkoutValueType = false,
  }) => HabitSignalForm(
    kind: kind,
    id: id,
    mode: mode ?? this.mode,
    threshold: clearThreshold ? null : (threshold ?? this.threshold),
    workoutValueType: clearWorkoutValueType
        ? null
        : (workoutValueType ?? this.workoutValueType),
    title: title,
  );

  @override
  bool operator ==(Object other) =>
      other is HabitSignalForm &&
      other.kind == kind &&
      other.id == id &&
      other.mode == mode &&
      other.threshold == threshold &&
      other.workoutValueType == workoutValueType &&
      other.title == title;

  @override
  int get hashCode =>
      Object.hash(kind, id, mode, threshold, workoutValueType, title);

  @override
  String toString() =>
      'HabitSignalForm($kind $id $mode ${threshold ?? ''} '
      '${workoutValueType?.name ?? ''})';
}

/// The editor's whole signal card: the rows and how they combine.
@immutable
class HabitSignalsForm {
  const HabitSignalsForm({
    this.signals = const [],
    this.composite = HabitCompositeRule.any,
    this.requiredCount = 1,
  });

  final List<HabitSignalForm> signals;
  final HabitCompositeRule composite;

  /// For [HabitCompositeRule.atLeast]: how many signals must fire.
  final int requiredCount;

  bool get isEmpty => signals.isEmpty;

  /// Whether every bounded signal has the threshold it needs; a bounded
  /// mode without one would serialize as "any entry".
  bool get isComplete => signals.every(
    (s) =>
        s.mode == HabitSignalMode.any ||
        (s.threshold != null &&
            (s.kind != HabitSignalKind.workout || s.workoutValueType != null)),
  );

  HabitSignalsForm copyWith({
    List<HabitSignalForm>? signals,
    HabitCompositeRule? composite,
    int? requiredCount,
  }) => HabitSignalsForm(
    signals: signals ?? this.signals,
    composite: composite ?? this.composite,
    requiredCount: requiredCount ?? this.requiredCount,
  );

  /// The form with every signal on a choice measurable reduced to *any
  /// entry*, or this very instance when none needed it.
  ///
  /// A choice measurable's day value is an occurrence count, so a bound set
  /// while it was numeric — or on a device that has not yet learnt the kind —
  /// would compare that count against a quantity and never fire, while the
  /// editor, which offers no threshold for such a signal, says "any entry".
  /// The saved rule must be the one on screen.
  HabitSignalsForm unboundedForChoices(
    Map<String, MeasurableDataType> measurablesById,
  ) {
    var changed = false;
    final unbounded = [
      for (final signal in signals)
        if (signal.kind == HabitSignalKind.measurable &&
            signal.mode != HabitSignalMode.any &&
            (measurablesById[signal.id]?.isChoice ?? false))
          () {
            changed = true;
            return signal.copyWith(
              mode: HabitSignalMode.any,
              clearThreshold: true,
            );
          }()
        else
          signal,
    ];
    return changed ? copyWith(signals: unbounded) : this;
  }

  /// The form as the rule tree would give it back: a single signal has no
  /// composite, and an at-least count is clamped to what exists.
  HabitSignalsForm normalized() {
    if (signals.length < 2) return HabitSignalsForm(signals: signals);
    final count = requiredCount.clamp(1, signals.length);
    return HabitSignalsForm(
      signals: signals,
      composite: composite,
      requiredCount: composite == HabitCompositeRule.atLeast ? count : 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HabitSignalsForm &&
      const ListEquality<HabitSignalForm>().equals(other.signals, signals) &&
      other.composite == composite &&
      other.requiredCount == requiredCount;

  @override
  int get hashCode => Object.hash(
    const ListEquality<HabitSignalForm>().hash(signals),
    composite,
    requiredCount,
  );

  @override
  String toString() => 'HabitSignalsForm($signals, $composite, $requiredCount)';
}

/// Lossless bridge between a habit's `autoCompleteRule` tree and the
/// editor's signal card.
///
/// The editor produces flat trees: a leaf, or one `and` / `or` / `multiple`
/// over leaves. Those round-trip exactly. Anything else — nested composites,
/// a leaf carrying both bounds, a `habit` leaf (the editor does not offer
/// "another habit" as a signal) — is read as faithfully as the card can
/// show it: leaves are flattened under the root's composite, a two-bounded
/// leaf keeps its minimum, and habit leaves are dropped. Saving such a
/// habit rewrites the tree to what the card shows.
class HabitFormMapping {
  const HabitFormMapping._();

  static HabitSignalsForm fromRule(AutoCompleteRule? rule) {
    if (rule == null) return const HabitSignalsForm();
    final leaves = <HabitSignalForm>[];
    void collect(AutoCompleteRule node) {
      switch (node) {
        case AutoCompleteRuleMeasurable(
          :final dataTypeId,
          :final minimum,
          :final maximum,
          :final title,
        ):
          leaves.add(
            _leaf(
              HabitSignalKind.measurable,
              dataTypeId,
              minimum,
              maximum,
              title,
            ),
          );
        case AutoCompleteRuleHealth(
          :final dataType,
          :final minimum,
          :final maximum,
          :final title,
        ):
          leaves.add(
            _leaf(HabitSignalKind.health, dataType, minimum, maximum, title),
          );
        case AutoCompleteRuleWorkout(
          :final dataType,
          :final minimum,
          :final maximum,
          :final valueType,
          :final title,
        ):
          final base = _leaf(
            HabitSignalKind.workout,
            dataType,
            minimum,
            maximum,
            title,
          );
          leaves.add(
            HabitSignalForm(
              kind: base.kind,
              id: base.id,
              // A threshold without a dimension cannot be evaluated; it
              // reads as "any workout" so the card shows something honest.
              mode: valueType == null ? HabitSignalMode.any : base.mode,
              threshold: valueType == null ? null : base.threshold,
              workoutValueType: valueType,
              title: title,
            ),
          );
        case AutoCompleteRuleHabit():
          break;
        case AutoCompleteRuleAnd(:final rules) ||
            AutoCompleteRuleOr(:final rules) ||
            AutoCompleteRuleMultiple(:final rules):
          rules.forEach(collect);
      }
    }

    collect(rule);
    final (composite, required) = switch (rule) {
      AutoCompleteRuleAnd() => (HabitCompositeRule.all, 1),
      AutoCompleteRuleMultiple(:final successes) => (
        HabitCompositeRule.atLeast,
        successes,
      ),
      _ => (HabitCompositeRule.any, 1),
    };
    return HabitSignalsForm(
      signals: leaves,
      composite: composite,
      requiredCount: required,
    ).normalized();
  }

  static AutoCompleteRule? toRule(HabitSignalsForm form) {
    final leaves = form.signals.map(_toLeaf).toList(growable: false);
    if (leaves.isEmpty) return null;
    if (leaves.length == 1) return leaves.single;
    return switch (form.composite) {
      HabitCompositeRule.any => AutoCompleteRule.or(rules: leaves),
      HabitCompositeRule.all => AutoCompleteRule.and(rules: leaves),
      HabitCompositeRule.atLeast => AutoCompleteRule.multiple(
        rules: leaves,
        successes: form.requiredCount.clamp(1, leaves.length),
      ),
    };
  }

  static HabitSignalForm _leaf(
    HabitSignalKind kind,
    String id,
    num? minimum,
    num? maximum,
    String? title,
  ) => HabitSignalForm(
    kind: kind,
    id: id,
    mode: minimum != null
        ? HabitSignalMode.atLeast
        : maximum != null
        ? HabitSignalMode.atMost
        : HabitSignalMode.any,
    threshold: minimum ?? maximum,
    title: title,
  );

  static AutoCompleteRule _toLeaf(HabitSignalForm signal) {
    final minimum = signal.mode == HabitSignalMode.atLeast
        ? signal.threshold
        : null;
    final maximum = signal.mode == HabitSignalMode.atMost
        ? signal.threshold
        : null;
    return switch (signal.kind) {
      HabitSignalKind.measurable => AutoCompleteRule.measurable(
        dataTypeId: signal.id,
        minimum: minimum,
        maximum: maximum,
        title: signal.title,
      ),
      HabitSignalKind.health => AutoCompleteRule.health(
        dataType: signal.id,
        minimum: minimum,
        maximum: maximum,
        title: signal.title,
      ),
      HabitSignalKind.workout => AutoCompleteRule.workout(
        dataType: signal.id,
        minimum: minimum,
        maximum: maximum,
        valueType: signal.mode == HabitSignalMode.any
            ? null
            : signal.workoutValueType,
        title: signal.title,
      ),
    };
  }
}
