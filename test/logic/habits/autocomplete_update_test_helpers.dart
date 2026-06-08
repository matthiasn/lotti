import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';

class GeneratedAutoCompleteRuleScenario {
  const GeneratedAutoCompleteRuleScenario({
    required this.depth,
    required this.seed,
    required this.pathIndex,
    required this.replacementSeed,
  });

  final int depth;
  final int seed;
  final int pathIndex;
  final int replacementSeed;

  AutoCompleteRule get rule => hBuildRule(depth: depth, seed: seed);

  AutoCompleteRule get replacement => hLeafRule(replacementSeed + 100000);

  List<List<int>> get validPaths => hRulePaths(rule);

  List<int> get targetPath => validPaths[pathIndex % validPaths.length];

  AutoCompleteRule? get expectedReplacement =>
      hReplaceExpected(rule, targetPath, replacement);

  AutoCompleteRule? get expectedRemoval =>
      hReplaceExpected(rule, targetPath, null);

  List<int> get missingPath => const [0, 99];

  @override
  String toString() {
    return 'GeneratedAutoCompleteRuleScenario('
        'depth: $depth, '
        'seed: $seed, '
        'targetPath: $targetPath, '
        'replacementSeed: $replacementSeed)';
  }
}

extension AnyGeneratedAutoCompleteRuleScenario on glados.Any {
  glados.Generator<GeneratedAutoCompleteRuleScenario>
  get autoCompleteRuleScenario => glados.CombinableAny(this).combine4(
    glados.IntAnys(this).intInRange(0, 4),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      int depth,
      int seed,
      int pathIndex,
      int replacementSeed,
    ) => GeneratedAutoCompleteRuleScenario(
      depth: depth,
      seed: seed,
      pathIndex: pathIndex,
      replacementSeed: replacementSeed,
    ),
  );
}

AutoCompleteRule hBuildRule({
  required int depth,
  required int seed,
}) {
  if (depth == 0) return hLeafRule(seed);

  return switch (seed % 7) {
    0 || 1 || 2 || 3 => hLeafRule(seed),
    4 => AutoCompleteRule.and(
      rules: hChildRules(depth: depth, seed: seed),
      title: 'and-$seed',
    ),
    5 => AutoCompleteRule.or(
      rules: hChildRules(depth: depth, seed: seed),
      title: 'or-$seed',
    ),
    _ => AutoCompleteRule.multiple(
      rules: hChildRules(depth: depth, seed: seed),
      successes: (seed % 3) + 1,
      title: 'multiple-$seed',
    ),
  };
}

List<AutoCompleteRule> hChildRules({
  required int depth,
  required int seed,
}) {
  final childCount = seed % 4;
  return [
    for (var index = 0; index < childCount; index++)
      hBuildRule(depth: depth - 1, seed: seed * 31 + index + 1),
  ];
}

AutoCompleteRule hLeafRule(int seed) {
  return switch (seed % 4) {
    0 => AutoCompleteRule.health(
      dataType: 'health-$seed',
      minimum: seed % 100,
      title: 'health-title-$seed',
    ),
    1 => AutoCompleteRule.workout(
      dataType: 'workout-$seed',
      maximum: seed % 200,
      title: 'workout-title-$seed',
    ),
    2 => AutoCompleteRule.measurable(
      dataTypeId: 'measurable-$seed',
      minimum: seed % 300,
      maximum: (seed % 300) + 10,
      title: 'measurable-title-$seed',
    ),
    _ => AutoCompleteRule.habit(
      habitId: 'habit-$seed',
      title: 'habit-title-$seed',
    ),
  };
}

List<List<int>> hRulePaths(AutoCompleteRule rule) {
  final paths = <List<int>>[
    [0],
  ];

  void visit(AutoCompleteRule current, List<int> prefix) {
    final children = hChildrenOf(current);
    if (children == null) return;

    for (final (index, child) in children.indexed) {
      final childPath = [...prefix, index];
      paths.add(childPath);
      visit(child, childPath);
    }
  }

  visit(rule, [0]);
  return paths;
}

List<AutoCompleteRule>? hChildrenOf(AutoCompleteRule rule) {
  if (rule is AutoCompleteRuleAnd) return rule.rules;
  if (rule is AutoCompleteRuleOr) return rule.rules;
  if (rule is AutoCompleteRuleMultiple) return rule.rules;
  return null;
}

AutoCompleteRule hCopyWithChildren(
  AutoCompleteRule rule,
  List<AutoCompleteRule> children,
) {
  if (rule is AutoCompleteRuleAnd) {
    return AutoCompleteRule.and(rules: children, title: rule.title);
  }
  if (rule is AutoCompleteRuleOr) {
    return AutoCompleteRule.or(rules: children, title: rule.title);
  }
  final multiple = rule as AutoCompleteRuleMultiple;
  return AutoCompleteRule.multiple(
    rules: children,
    successes: multiple.successes,
    title: multiple.title,
  );
}

AutoCompleteRule? hReplaceExpected(
  AutoCompleteRule rule,
  List<int> path,
  AutoCompleteRule? replacement,
) {
  if (path.length == 1 && path.first == 0) return replacement;
  if (path.isEmpty || path.first != 0) return rule;
  return hReplaceDescendant(rule, path.sublist(1), replacement);
}

AutoCompleteRule hReplaceDescendant(
  AutoCompleteRule rule,
  List<int> descendantPath,
  AutoCompleteRule? replacement,
) {
  if (descendantPath.isEmpty) return replacement ?? rule;

  final children = hChildrenOf(rule);
  final childIndex = descendantPath.first;
  if (children == null || childIndex < 0 || childIndex >= children.length) {
    return rule;
  }

  final updatedChild = descendantPath.length == 1
      ? replacement
      : hReplaceDescendant(
          children[childIndex],
          descendantPath.sublist(1),
          replacement,
        );
  final updatedChildren = <AutoCompleteRule>[];

  for (final (index, child) in children.indexed) {
    if (index == childIndex) {
      if (updatedChild != null) updatedChildren.add(updatedChild);
    } else {
      updatedChildren.add(child);
    }
  }

  return hCopyWithChildren(rule, updatedChildren);
}
