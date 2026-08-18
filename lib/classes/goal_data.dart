import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/goal_criterion.dart';

part 'goal_data.freezed.dart';
part 'goal_data.g.dart';

/// Payload of a `JournalEntity.goal` — a long-term goal the user authored,
/// and the container its check-ins hang from.
///
/// **Why this lives in the journal database.** A goal's criteria are written
/// entirely in terms of other journal-side definitions: `habitId` names a
/// `HabitDefinition`, `dataTypeId` a `MeasurableDataType`, `categoryId` a
/// `CategoryDefinition`, `labelId` a `LabelDefinition`. Every referent of a
/// goal is a definition in the journal database, which the backup catalog
/// declares `required: true` and "the primary journal, task, definition, and
/// link authority" — while the agent database it used to live in is
/// `required: false`. A goal was the one member of its own family stored on
/// the disposable side, so restoring a profile without the agent database
/// silently lost goals the user had written. It no longer can.
///
/// The goal agent — the coach that evaluates this definition, keeps a
/// standing report and speaks through banners — remains agent-side and
/// optional, bound to this entry by an `AgentLink.agentGoal`, exactly as an
/// event agent binds to its `JournalEvent`. Losing it costs the user their
/// coach, never their goal or their check-ins.
///
/// **Two row shapes, one type.** A goal is one stable entry whose id never
/// changes, so the links to its check-ins survive every revision of the
/// criteria. Each revision additionally writes an immutable *snapshot* row
/// carrying the criteria as they stood, with [snapshotOf] naming the goal it
/// belongs to; [specVersionId] on the goal points at the snapshot standing
/// for the current definition. Snapshots are what `goalProgress` registers and
/// daily reflections pin themselves to, so a verdict passed under old criteria
/// is never re-read as a judgement of the current ones.
@freezed
abstract class GoalData with _$GoalData {
  const factory GoalData({
    /// The goal's short name, as the user wrote it ("Blood pressure").
    required String title,

    /// The speakable form: "Average 10,000 steps a day over a rolling week."
    required String statement,

    /// The criteria tree success is defined in. Its leaves reference habit,
    /// measurable, category and label definitions by their stable ids.
    required GoalCriterion criteria,

    /// Monotonic ordinal of the current definition, 1-based. Increments on
    /// every accepted revision.
    required int specVersion,

    /// Id of the snapshot row holding this exact definition. Registers and
    /// reflections pin to it, so their verdicts stay attributable to the
    /// criteria that produced them.
    required String specVersionId,

    /// When the goal starts counting; null means "from creation".
    DateTime? startDate,

    /// Optional deadline. Once passed, the track policy resolves to
    /// achieved/off-track instead of granting grace.
    DateTime? targetDate,

    /// Why this definition was chosen, when a revision recorded a reason.
    String? rationale,

    /// Set **only on an immutable spec snapshot**, naming the goal entry it
    /// belongs to; null on the goal itself. Denormalized into the journal
    /// row's `subtype` (the `HabitCompletionData.habitId` precedent) so a
    /// goal's version history is an indexed `type + subtype` lookup rather
    /// than a scan, and so a snapshot emits its goal as a precise wake token.
    String? snapshotOf,
  }) = _GoalData;

  factory GoalData.fromJson(Map<String, dynamic> json) =>
      _$GoalDataFromJson(json);
}

extension GoalDataExtension on GoalData {
  /// Whether this row is an immutable record of a past or present definition
  /// rather than the goal itself. Snapshots are never listed as goals.
  bool get isSpecSnapshot => snapshotOf != null;
}
