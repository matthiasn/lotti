part of 'day_agent_models.dart';

/// What surface produced a [TimeBlock].
enum TimeBlockType {
  /// Agent-drafted block.
  ai,

  /// Real calendar event imported from the device calendar.
  cal,

  /// Buffer between focus blocks (transition / commute / decompression).
  buffer,

  /// User-placed manually.
  manual,
}

/// Visual state used by the Day timeline to distinguish drafted from
/// committed plans. Mirrors `Day.state` from the prototype: while a
/// plan is drafted, blocks render with a dashed outline.
enum TimeBlockState {
  drafted,
  committed,
  inProgress,
  completed,
  dropped,
}

/// Prefix used to encode a tracked [TimeBlock]'s id from the journal
/// entry id of the time recording it projects (`actual:<entryId>`).
/// The prefix keeps recorded-session ids distinct from drafted/agent
/// block ids, and lets the Day timeline recover the backing entry id
/// so tapping a tracked block can scroll the task detail page to it.
const actualTimeBlockIdPrefix = 'actual:';

/// A scheduled placement on a day. The agent emits these from
/// `drafted_day_plan`; every `ai` block carries a verbatim `reason`
/// string that the UI surfaces in the agenda why tooltip.
@immutable
class TimeBlock {
  const TimeBlock({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.type,
    required this.state,
    required this.category,
    this.taskId,
    this.reason,
    this.sessionIndex,
    this.sessionTotal,
    this.location,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final TimeBlockType type;
  final TimeBlockState state;
  final DayAgentCategory category;

  /// Null for buffers, real calendar events without a backing task,
  /// and unbound manual blocks.
  final String? taskId;

  /// The "why" string. **Mandatory** for `type == ai` — the agent
  /// must justify every placement it proposes. Optional for `cal` /
  /// `manual` / `buffer` (those have built-in justifications).
  final String? reason;

  final int? sessionIndex;
  final int? sessionTotal;
  final String? location;

  Duration get duration => end.difference(start);

  /// The journal entry id of the time recording this block projects, or
  /// null when the block is not a tracked recording (drafted/agent/cal
  /// blocks keep their own ids). Derived from the [actualTimeBlockIdPrefix]
  /// encoding applied when projecting real entries onto the timeline.
  String? get trackedEntryId => id.startsWith(actualTimeBlockIdPrefix)
      ? id.substring(actualTimeBlockIdPrefix.length)
      : null;

  TimeBlock copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    TimeBlockType? type,
    TimeBlockState? state,
    DayAgentCategory? category,
    String? taskId,
    String? reason,
    int? sessionIndex,
    int? sessionTotal,
    String? location,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      type: type ?? this.type,
      state: state ?? this.state,
      category: category ?? this.category,
      taskId: taskId ?? this.taskId,
      reason: reason ?? this.reason,
      sessionIndex: sessionIndex ?? this.sessionIndex,
      sessionTotal: sessionTotal ?? this.sessionTotal,
      location: location ?? this.location,
    );
  }
}

/// Aggregations shared by the tracked-time surfaces ([TimeBlock] lists on
/// the "Today so far" card, the agenda stat strip, and the tracked legend).
extension TimeBlockListTotals on List<TimeBlock> {
  /// Sum of the blocks' durations in minutes.
  int get totalMinutes =>
      fold(0, (sum, block) => sum + block.duration.inMinutes);

  /// Completed sessions, de-duplicated by backing task (standalone
  /// sessions fall back to the block id).
  int get completedCount => where(
    (block) => block.state == TimeBlockState.completed,
  ).map((block) => block.taskId ?? block.id).toSet().length;
}

/// A coloured energy band shown behind the Day timeline.
/// The agent emits these so the band positions stay coherent with
/// scheduling decisions ("Pushed to 2pm because of your 9am meeting").
@immutable
class EnergyBand {
  const EnergyBand({
    required this.start,
    required this.end,
    required this.level,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final EnergyLevel level;

  /// Short overline shown at the band's top-left, e.g. "HIGH ENERGY".
  final String label;
}

enum EnergyLevel {
  high,
  low,
  secondWind,
}
