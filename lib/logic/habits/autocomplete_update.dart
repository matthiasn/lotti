import 'package:collection/collection.dart';
import 'package:lotti/classes/entity_definitions.dart';

AutoCompleteRule? removeAtRecursive({
  required AutoCompleteRule? rule,
  required List<int> currentPath,
  required List<int> deleteAtPath,
}) {
  AutoCompleteRule? indexedChild(int idx, AutoCompleteRule rule) {
    return removeAtRecursive(
      rule: rule,
      currentPath: [...currentPath, idx],
      deleteAtPath: deleteAtPath,
    );
  }

  List<AutoCompleteRule> mapRules(List<AutoCompleteRule> rules) {
    return rules
        .mapIndexed(indexedChild)
        .whereType<AutoCompleteRule>()
        .toList();
  }

  if (const ListEquality<int>().equals(currentPath, deleteAtPath)) {
    return null;
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

AutoCompleteRule? removeAt(AutoCompleteRule? rule, List<int> deleteAtPath) {
  return removeAtRecursive(
    rule: rule,
    currentPath: [0],
    deleteAtPath: deleteAtPath,
  );
}
