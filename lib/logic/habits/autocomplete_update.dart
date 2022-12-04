import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';

AutoCompleteRule? replaceAtRecursive({
  required AutoCompleteRule? rule,
  required AutoCompleteRule? replaceWith,
  required List<int> currentPath,
  required List<int> replaceAtPath,
}) {
  AutoCompleteRule? indexedChild(int idx, AutoCompleteRule rule) {
    return replaceAtRecursive(
      rule: rule,
      currentPath: [...currentPath, idx],
      replaceAtPath: replaceAtPath,
      replaceWith: replaceWith,
    );
  }

  List<AutoCompleteRule> mapRules(List<AutoCompleteRule> rules) {
    return rules
        .mapIndexed(indexedChild)
        .whereType<AutoCompleteRule>()
        .toList();
  }

  if (const ListEquality<int>().equals(currentPath, replaceAtPath)) {
    return replaceWith;
  }

  return rule?.map(
    health: (health) => health,
    workout: (workout) => workout,
    measurable: (measurable) => measurable,
    habit: (habit) => habit,
    and: (and) => and.copyWith(rules: mapRules(and.rules)),
    or: (or) => or.copyWith(rules: mapRules(or.rules)),
    multiple: (multiple) => multiple.copyWith(rules: mapRules(multiple.rules)),
  );
}

AutoCompleteRule? removeAt(
  AutoCompleteRule? rule, {
  required List<int> path,
}) {
  return replaceAtRecursive(
    rule: rule,
    currentPath: [0],
    replaceAtPath: path,
    replaceWith: null,
  );
}

AutoCompleteRule? replaceAt(
  AutoCompleteRule? rule, {
  required List<int> replaceAtPath,
  required AutoCompleteRule? replaceWith,
}) {
  return replaceAtRecursive(
    rule: rule,
    currentPath: [0],
    replaceAtPath: replaceAtPath,
    replaceWith: replaceWith,
  );
}
