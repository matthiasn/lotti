import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/retired_tool_calls.dart';
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

/// The time entry a time-entry edit targets and the fields it sets, or `null`
/// for any other proposal and for one naming no usable entry.
///
/// Reads `update_time_entry` and — through [upgradeRetiredTaskAgentToolCall] —
/// the retired `update_running_timer`, so a proposal persisted under the old
/// name is superseded by, and supersedes, its successor like any other edit.
({String entryId, Set<String> fields})? timeEntryEdit(ChangeItem item) {
  final call = upgradeRetiredTaskAgentToolCall(item.toolName, item.args);
  if (call.toolName != TaskAgentToolNames.updateTimeEntry) return null;
  final entryId = call.args['entryId'];
  if (entryId is! String || entryId.trim().isEmpty) return null;
  return (
    entryId: entryId.trim(),
    fields: {
      for (final field in _timeEntryEditFields)
        if (call.args.containsKey(field)) field,
    },
  );
}

const _timeEntryEditFields = ['summary', 'startTime', 'endTime'];

/// Whether [newer] makes the older proposal [older] obsolete: both edit the
/// same time entry, they differ, and [newer] sets every field [older] would.
///
/// Field coverage rather than "same entry" alone: a newer text revision
/// replaces an older one, but must not swallow a pending correction of the
/// entry's end time. An identical re-proposal supersedes nothing — it is a
/// duplicate, and dedup keeps the original open instead of churning it.
bool supersedesTimeEntryEdit(ChangeItem newer, ChangeItem older) {
  final newerEdit = timeEntryEdit(newer);
  final olderEdit = timeEntryEdit(older);
  return newerEdit != null &&
      olderEdit != null &&
      newerEdit.entryId == olderEdit.entryId &&
      newerEdit.fields.containsAll(olderEdit.fields) &&
      ChangeItem.fingerprint(newer) != ChangeItem.fingerprint(older);
}

/// Whether [item] is a pending proposal made obsolete by one of this wake's
/// [proposed] items (see [supersedesTimeEntryEdit]).
///
/// An item that is itself among [proposed] never matches: it is a replacement
/// being kept, and [proposed] carries no order to tell which of two of its own
/// items came later.
bool isSupersededByProposals(ChangeItem item, List<ChangeItem> proposed) {
  if (item.status != ChangeItemStatus.pending) return false;
  final fingerprint = ChangeItem.fingerprint(item);
  if (proposed.any((p) => ChangeItem.fingerprint(p) == fingerprint)) {
    return false;
  }
  return proposed.any((p) => supersedesTimeEntryEdit(p, item));
}

/// Locates every pending item across [sets] that one of this wake's
/// [proposed] items supersedes (see [isSupersededByProposals]).
///
/// Each match carries the owning change set, the item's index within that set,
/// and the item itself so callers can mark the precise positions retracted.
List<({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})>
locateSupersededTimeEntryEdits(
  List<ChangeSetEntity> sets,
  List<ChangeItem> proposed,
) {
  final matches =
      <({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})>[];
  for (final set in sets) {
    for (var i = 0; i < set.items.length; i++) {
      final item = set.items[i];
      if (isSupersededByProposals(item, proposed)) {
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
              if (indexesBySetId[set.id]!.contains(i))
                set.items[i].withStatus(ChangeItemStatus.retracted)
              else
                set.items[i],
          ],
        ),
  ];
}

/// Returns a copy of [set] with every still-pending item retracted and the
/// set itself marked resolved — used when a newer set consolidates it.
ChangeSetEntity retireConsolidatedSet(ChangeSetEntity set) {
  return set.copyWith(
    items: [
      for (final item in set.items)
        if (item.status == ChangeItemStatus.pending)
          item.withStatus(ChangeItemStatus.retracted)
        else
          item,
    ],
    status: ChangeSetStatus.resolved,
    resolvedAt: clock.now(),
  );
}
