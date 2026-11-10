import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';

/// [draft]'s agenda items in the order of the day, each with its start.
///
/// An item starts when the earliest of its linked blocks does; dropped
/// blocks no longer hold a time, and ids that name no block are ignored.
/// Items are sorted by that start, ties keep plan order, and items with no
/// start at all sort last, also in plan order.
List<({AgendaItem item, DateTime? start})> agendaItemsByStart(
  DraftPlan draft,
) {
  final starts = <String, DateTime>{
    for (final block in draft.blocks)
      if (block.state != TimeBlockState.dropped) block.id: block.start,
  };
  DateTime? startOf(AgendaItem item) {
    DateTime? earliest;
    for (final id in item.linkedBlockIds) {
      final start = starts[id];
      if (start != null && (earliest == null || start.isBefore(earliest))) {
        earliest = start;
      }
    }
    return earliest;
  }

  final indexed = [
    for (final (index, item) in draft.agendaItems.indexed)
      (index: index, item: item, start: startOf(item)),
  ]..sort((a, b) => _compareStarts(a.start, b.start) ?? a.index - b.index);
  return [for (final e in indexed) (item: e.item, start: e.start)];
}

/// Earlier first, a missing start last; null when the two tie.
int? _compareStarts(DateTime? a, DateTime? b) {
  if (a == null && b == null) return null;
  if (a == null) return 1;
  if (b == null) return -1;
  final byStart = a.compareTo(b);
  return byStart == 0 ? null : byStart;
}
