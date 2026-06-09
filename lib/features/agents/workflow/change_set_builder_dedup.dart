part of 'change_set_builder.dart';

/// Returns items from [proposed] that do not already exist in [existing],
/// comparing on `toolName` and `args` only (ignoring `humanSummary`).
///
/// [rejectedFingerprints] are merged into the dedup set so that items
/// rejected in previously-resolved change sets are still blocked.
/// [rejectedDisplayKeys] does the same for verbatim user-facing summaries.
List<ChangeItem> _deduplicateItems(
  List<ChangeItem> proposed,
  List<ChangeItem> existing, {
  Set<String> rejectedFingerprints = const {},
  Set<String> rejectedDisplayKeys = const {},
}) {
  if (existing.isEmpty &&
      rejectedFingerprints.isEmpty &&
      rejectedDisplayKeys.isEmpty) {
    return proposed;
  }
  final existingHashes = {
    ...existing.map(ChangeItem.fingerprint),
    ...rejectedFingerprints,
  };
  final existingDisplayKeys = {
    ...rejectedDisplayKeys,
    for (final item in existing)
      if (ChangeItem.displayDuplicateKey(item) case final String key) key,
  };
  return proposed.where((item) {
    if (existingHashes.contains(ChangeItem.fingerprint(item))) {
      return false;
    }
    final displayKey = ChangeItem.displayDuplicateKey(item);
    return displayKey == null || !existingDisplayKeys.contains(displayKey);
  }).toList();
}

ChangeSetEntity _retireConsolidatedSet(ChangeSetEntity set) {
  return set.copyWith(
    items: [
      for (final item in set.items)
        item.status == ChangeItemStatus.pending
            ? item.copyWith(status: ChangeItemStatus.retracted)
            : item,
    ],
    status: ChangeSetStatus.resolved,
    resolvedAt: clock.now(),
  );
}

bool _isRunningTimerUpdate(ChangeItem item) =>
    item.toolName == TaskAgentToolNames.updateRunningTimer;

String? _runningTimerId(ChangeItem item) => _runningTimerIdFromArgs(item.args);

String? _runningTimerIdFromArgs(Map<String, dynamic> args) {
  final timerId = args['timerId'];
  if (timerId is! String) return null;
  final trimmed = timerId.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _isRunningTimerUpdateForTimer(
  ChangeItem item,
  String? timerId,
) => _isRunningTimerUpdate(item) && _runningTimerId(item) == timerId;

Set<String?> _runningTimerIds(Iterable<ChangeItem> items) => {
  for (final item in items)
    if (_isRunningTimerUpdate(item)) _runningTimerId(item),
};

List<({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})>
_locatePendingRunningTimerUpdates(
  List<ChangeSetEntity> sets,
  Set<String?> timerIds,
) {
  final matches =
      <({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})>[];
  for (final set in sets) {
    for (var i = 0; i < set.items.length; i++) {
      final item = set.items[i];
      if (_isRunningTimerUpdate(item) &&
          item.status == ChangeItemStatus.pending &&
          timerIds.contains(_runningTimerId(item))) {
        matches.add((changeSet: set, itemIndex: i, item: item));
      }
    }
  }
  return matches;
}

List<ChangeSetEntity> _markItemsRetracted(
  List<ChangeSetEntity> sets,
  List<({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})> matches,
) {
  final indexesBySetId = <String, Set<int>>{};
  for (final match in matches) {
    indexesBySetId
        .putIfAbsent(match.changeSet.id, () => <int>{})
        .add(match.itemIndex);
  }

  return [
    for (final set in sets)
      if (!indexesBySetId.containsKey(set.id))
        set
      else
        set.copyWith(
          items: [
            for (var i = 0; i < set.items.length; i++)
              indexesBySetId[set.id]!.contains(i)
                  ? set.items[i].copyWith(status: ChangeItemStatus.retracted)
                  : set.items[i],
          ],
        ),
  ];
}
