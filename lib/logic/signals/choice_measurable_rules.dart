import 'package:lotti/classes/entity_definitions.dart';

/// Whether the measurable with this id is recorded as a choice.
typedef IsChoiceMeasurable = bool Function(String dataTypeId);

/// [rule] with every measurable leaf on a choice measurable stripped of its
/// bounds, or the very same instance when none carried any.
///
/// A choice measurable's day value is an occurrence count (`value: 1` per
/// recording), so a `minimum` or `maximum` on it — set while the measurable
/// was still numeric, or by a device that has not yet learnt the kind —
/// compares a count against a quantity and never fires, while the editor,
/// which offers no threshold for such a signal, says "any entry". Applied by
/// every evaluator before the `HabitRuleEvaluator` sees the rule, so the
/// verdict matches what the user is shown without waiting for the rule to
/// be re-saved.
AutoCompleteRule unboundChoiceMeasurables(
  AutoCompleteRule rule,
  IsChoiceMeasurable isChoice,
) {
  switch (rule) {
    case AutoCompleteRuleMeasurable(
      :final dataTypeId,
      :final minimum,
      :final maximum,
      :final title,
    ):
      if ((minimum == null && maximum == null) || !isChoice(dataTypeId)) {
        return rule;
      }
      return AutoCompleteRule.measurable(dataTypeId: dataTypeId, title: title);
    case AutoCompleteRuleAnd(:final rules, :final title):
      final unbound = _unboundAll(rules, isChoice);
      return identical(unbound, rules)
          ? rule
          : AutoCompleteRule.and(rules: unbound, title: title);
    case AutoCompleteRuleOr(:final rules, :final title):
      final unbound = _unboundAll(rules, isChoice);
      return identical(unbound, rules)
          ? rule
          : AutoCompleteRule.or(rules: unbound, title: title);
    case AutoCompleteRuleMultiple(:final rules, :final successes, :final title):
      final unbound = _unboundAll(rules, isChoice);
      return identical(unbound, rules)
          ? rule
          : AutoCompleteRule.multiple(
              rules: unbound,
              successes: successes,
              title: title,
            );
    case AutoCompleteRuleHealth() ||
        AutoCompleteRuleWorkout() ||
        AutoCompleteRuleHabit():
      return rule;
  }
}

/// The children with each unbound, or [rules] itself when none changed.
List<AutoCompleteRule> _unboundAll(
  List<AutoCompleteRule> rules,
  IsChoiceMeasurable isChoice,
) {
  var changed = false;
  final unbound = [
    for (final child in rules)
      () {
        final next = unboundChoiceMeasurables(child, isChoice);
        if (!identical(next, child)) changed = true;
        return next;
      }(),
  ];
  return changed ? unbound : rules;
}
