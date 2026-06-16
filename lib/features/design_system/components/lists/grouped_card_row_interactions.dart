/// The resolved seam geometry for a single row in a grouped card stack.
///
/// [topOverlap]/[bottomOverlap] are the pixel amounts a row's background bleeds
/// into its neighbour to hide the seam between connected cards, and
/// [showDividerBelow] requests a thin divider in place of an overlap (used
/// between two equal-priority rows). Computed by
/// [buildGroupedCardRowInteractions].
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

/// Computes per-row [GroupedCardRowInteraction]s for a stack of grouped cards.
///
/// Given each row's grouping [priorities] and which adjacent rows are
/// [connectedBelow] (one entry per edge), it decides where a seam-hiding
/// [overlap] is applied — biasing the overlap onto the lower-priority row — and
/// where two equal zero-priority rows get a divider instead. Returns one
/// interaction per row, in order.
List<GroupedCardRowInteraction> buildGroupedCardRowInteractions({
  required List<int> priorities,
  required List<bool> connectedBelow,
  double overlap = 1,
}) {
  if (priorities.isEmpty) {
    return const <GroupedCardRowInteraction>[];
  }

  assert(
    connectedBelow.length == priorities.length - 1,
    'connectedBelow must describe every edge between adjacent rows.',
  );

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
