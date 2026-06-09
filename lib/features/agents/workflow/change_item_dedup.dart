import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Returns items from [proposed] that do not already exist in [existing],
/// comparing on `toolName` and `args` only (ignoring `humanSummary`).
///
/// [rejectedFingerprints] are merged into the dedup set so that items
/// rejected in previously-resolved change sets are still blocked.
/// [rejectedDisplayKeys] does the same for verbatim user-facing summaries.
///
/// The first occurrence of any structural fingerprint or display key wins:
/// later [proposed] items that match an already-seen item in [existing] (or in
/// the merged rejection sets) are dropped, while the relative order of the kept
/// items is preserved.
List<ChangeItem> deduplicateItems(
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

/// Whether [item] is an `update_running_timer` proposal.
bool isRunningTimerUpdate(ChangeItem item) =>
    item.toolName == TaskAgentToolNames.updateRunningTimer;

/// Extracts the trimmed `timerId` from an [item]'s args, or `null` when the
/// item carries no usable timer id.
String? runningTimerId(ChangeItem item) => runningTimerIdFromArgs(item.args);

/// Parses the `timerId` value out of a tool-call [args] map.
///
/// Returns the trimmed id when it is a non-empty string, and `null` when the
/// key is missing, not a string, or only whitespace.
String? runningTimerIdFromArgs(Map<String, dynamic> args) {
  final timerId = args['timerId'];
  if (timerId is! String) return null;
  final trimmed = timerId.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Whether [item] is an `update_running_timer` proposal targeting [timerId].
bool isRunningTimerUpdateForTimer(
  ChangeItem item,
  String? timerId,
) => isRunningTimerUpdate(item) && runningTimerId(item) == timerId;

/// Collects the distinct running-timer ids referenced by the
/// `update_running_timer` proposals in [items] (including a single `null`
/// entry for any timer-less updates).
Set<String?> runningTimerIds(Iterable<ChangeItem> items) => {
  for (final item in items)
    if (isRunningTimerUpdate(item)) runningTimerId(item),
};

/// Locates every pending `update_running_timer` item across [sets] whose timer
/// id is contained in [timerIds].
///
/// Each match carries the owning change set, the item's index within that set,
/// and the item itself so callers can mark the precise positions retracted.
List<({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})>
locatePendingRunningTimerUpdates(
  List<ChangeSetEntity> sets,
  Set<String?> timerIds,
) {
  final matches =
      <({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})>[];
  for (final set in sets) {
    for (var i = 0; i < set.items.length; i++) {
      final item = set.items[i];
      if (isRunningTimerUpdate(item) &&
          item.status == ChangeItemStatus.pending &&
          timerIds.contains(runningTimerId(item))) {
        matches.add((changeSet: set, itemIndex: i, item: item));
      }
    }
  }
  return matches;
}

/// Returns a copy of [sets] where the items identified by [matches] are marked
/// [ChangeItemStatus.retracted].
///
/// Sets without any matched item are returned unchanged (same instance);
/// matched sets are rebuilt with only the targeted indexes retracted.
List<ChangeSetEntity> markItemsRetracted(
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
