class GroupedCardRowInteraction {
  const GroupedCardRowInteraction({
    this.topOverlap = 0,
    this.bottomOverlap = 0,
    this.showDividerBelow = false,
  });

  final double topOverlap;
  final double bottomOverlap;
  final bool showDividerBelow;
}

List<GroupedCardRowInteraction> buildGroupedCardRowInteractions({
  required List<int> priorities,
  required List<bool> connectedBelow,
  double overlap = 1,
}) {
  assert(
    connectedBelow.length == priorities.length - 1,
    'connectedBelow must describe every edge between adjacent rows.',
  );

  if (priorities.isEmpty) {
    return const <GroupedCardRowInteraction>[];
  }

  final topOverlaps = List<double>.filled(priorities.length, 0);
  final bottomOverlaps = List<double>.filled(priorities.length, 0);
  final showDividerBelow = List<bool>.filled(priorities.length, false);

  for (var index = 0; index < connectedBelow.length; index++) {
    if (!connectedBelow[index]) {
      continue;
    }

    final upperPriority = priorities[index];
    final lowerPriority = priorities[index + 1];

    if (upperPriority == 0 && lowerPriority == 0) {
      showDividerBelow[index] = true;
      continue;
    }

    if (lowerPriority > upperPriority) {
      topOverlaps[index + 1] = overlap;
    } else {
      bottomOverlaps[index] = overlap;
    }
  }

  return List<GroupedCardRowInteraction>.generate(
    priorities.length,
    (index) => GroupedCardRowInteraction(
      topOverlap: topOverlaps[index],
      bottomOverlap: bottomOverlaps[index],
      showDividerBelow: showDividerBelow[index],
    ),
    growable: false,
  );
}
