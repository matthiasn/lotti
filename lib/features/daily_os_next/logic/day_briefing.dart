import 'package:collection/collection.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';

/// What the companion says about a day, as facts: the Day page composes the
/// localized sentences from them, so this stays pure and needs no locale.
///
/// Only blocks that are work count: buffers are the space between blocks,
/// and a dropped block is no longer planned.
class DayBriefing {
  const DayBriefing._({
    required this.hasPlan,
    required this.blockCount,
    required this.next,
    required this.nothingLeftToday,
    required this.longest,
    required this.freeMinutes,
  });

  /// The briefing for [draft] as of [now]. [hasPlan] is false when the day
  /// has no plan at all, and then the briefing is only an invitation to
  /// check in.
  factory DayBriefing.of({
    required DraftPlan draft,
    required bool hasPlan,
    required DateTime now,
  }) {
    final blocks =
        draft.blocks
            .where(
              (b) =>
                  b.type != TimeBlockType.buffer &&
                  b.state != TimeBlockState.dropped,
            )
            .toList()
          ..sortBy((b) => b.start);
    // On a past day every block has started, so nothing is next.
    final next = blocks.firstWhereOrNull((b) => b.start.isAfter(now));
    // "Nothing left" is news only today; a past day is simply over.
    final today = _dateOnly(draft.dayDate) == _dateOnly(now);
    return DayBriefing._(
      hasPlan: hasPlan,
      blockCount: blocks.length,
      next: next,
      nothingLeftToday: today && blocks.isNotEmpty && next == null,
      // With one block, "the longest" is the only one: not worth saying.
      longest: blocks.length < 2
          ? null
          : blocks.reduce((a, b) => b.duration > a.duration ? b : a),
      freeMinutes: draft.capacityMinutes - draft.scheduledMinutes,
    );
  }

  /// Whether the day has a plan; without one, nothing else here is said.
  final bool hasPlan;

  /// The planned blocks: not buffers, not dropped.
  final int blockCount;

  /// The first block that starts after now, or null when none is left or
  /// the day is over.
  final TimeBlock? next;

  /// True on today, once every planned block has started.
  final bool nothingLeftToday;

  /// The longest planned block, the earliest of equals; null with fewer
  /// than two blocks.
  final TimeBlock? longest;

  /// The day's capacity minus what is scheduled; zero or less is a full
  /// day.
  final int freeMinutes;

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
}
