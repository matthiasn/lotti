import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'notification_entity.freezed.dart';
part 'notification_entity.g.dart';

/// The pseudo subject every sync-conflict row is linked to — the conflicts
/// list has no entity id of its own, and the producer retracts superseded
/// rows by linked entity.
const String syncConflictsSubjectId = 'sync-conflicts';

/// The wire discriminators of the union.
///
/// Also the `kind` every producer derives its episode ids from and retracts
/// by, so the two can never drift apart: a producer names its kind here, and
/// [NotificationEntityFields.type] answers the same string for the row it
/// writes.
abstract final class NotificationKinds {
  static const String taskSuggestion = 'taskSuggestion';
  static const String taskOverdue = 'taskOverdue';
  static const String relationshipCheckIn = 'relationshipCheckIn';
  static const String habitAutoCompleted = 'habitAutoCompleted';
  static const String goalOffTrack = 'goalOffTrack';
  static const String dayPlanOutcome = 'dayPlanOutcome';
  static const String syncConflict = 'syncConflict';
}

@freezed
sealed class NotificationEntity with _$NotificationEntity {
  const factory NotificationEntity.taskSuggestion({
    required NotificationMeta meta,
    required String linkedTaskId,
    required int suggestionCount,
    required String title,
    required String body,
  }) = TaskSuggestionNotification;

  const factory NotificationEntity.taskOverdue({
    required NotificationMeta meta,
    required String linkedTaskId,
    required String title,
    required String body,
  }) = TaskOverdueNotification;

  /// A check-in reminder for a tracked person (ADR 0039 Decision 1).
  ///
  /// Armed ahead of the due day by the relationship agent's deterministic
  /// tier, so the OS alarm is already scheduled when the app closes — the
  /// one thing the in-app banner channel structurally cannot do. The row is
  /// the durable record; the OS notification is a projection of it.
  ///
  /// [title] and [body] are baked at write time by the arming device and
  /// then sync as-is, so a two-device/two-locale setup shows the armer's
  /// language on both. Deliberate: the alternative is re-rendering copy on
  /// read, which the two task variants do not do either.
  const factory NotificationEntity.relationshipCheckIn({
    required NotificationMeta meta,
    required String linkedRelationshipId,
    required String title,
    required String body,
  }) = RelationshipCheckInNotification;

  /// One or more habits the auto-completion engine checked off on [dayKey]
  /// (`yyyy-MM-dd`, the local calendar day the completions count for).
  ///
  /// Written the moment the engine completes, so it is due on arrival; the
  /// row is the durable record and the OS banner its projection, the same
  /// split as the other variants. Several habits completed by one import
  /// share a row so the user gets one notification, not one per habit.
  ///
  /// [title] and [body] are baked in the completing device's locale (see the
  /// check-in variant for why).
  const factory NotificationEntity.habitAutoCompleted({
    required NotificationMeta meta,
    required List<String> linkedHabitIds,
    required String dayKey,
    required String title,
    required String body,
  }) = HabitAutoCompletedNotification;

  /// A goal that has slipped — off track, or at risk and worsening — as its
  /// deterministic tier judged it (ADR 0073).
  ///
  /// One row per slip: the episode is the day the goal transitioned into
  /// that state, armed for the next alert hour by the goal agent's Phase A
  /// and retracted the moment the goal is back on track. [linkedGoalAgentId]
  /// is the agent, which is what the goal detail route is keyed by.
  ///
  /// [title] and [body] are baked in the arming device's locale (see the
  /// check-in variant for why).
  const factory NotificationEntity.goalOffTrack({
    required NotificationMeta meta,
    required String linkedGoalAgentId,
    required String title,
    required String body,
  }) = GoalOffTrackNotification;

  /// The outcome of a Daily OS plan job — a draft or a set of changes that
  /// finished, or gave up, while the app was in the background.
  ///
  /// **Device-local** (see [NotificationEntityFields.isDeviceLocal]): the job
  /// ledger it reports on never leaves this device, and "open Lotti to try
  /// again" is only true here. [dayId] is the day the job planned; one row
  /// per outcome, and a later outcome for the same day retracts the earlier.
  const factory NotificationEntity.dayPlanOutcome({
    required NotificationMeta meta,
    required String dayId,
    required bool succeeded,
    required String title,
    required String body,
  }) = DayPlanOutcomeNotification;

  /// Sync conflicts newly detected on this device — one row per burst,
  /// carrying the total still unresolved.
  ///
  /// **Device-local**: a conflict is this device's disagreement with a peer,
  /// and the list the row opens is this device's. [conflictCount] is what the
  /// body says; the row is linked to [syncConflictsSubjectId] so a later burst
  /// can retract the earlier one.
  const factory NotificationEntity.syncConflict({
    required NotificationMeta meta,
    required int conflictCount,
    required String title,
    required String body,
  }) = SyncConflictNotification;

  factory NotificationEntity.fromJson(Map<String, dynamic> json) =>
      _$NotificationEntityFromJson(json);
}

@freezed
abstract class NotificationMeta with _$NotificationMeta {
  const factory NotificationMeta({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime scheduledFor,
    required VectorClock vectorClock,
    required String originatingHostId,
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
    String? category,
  }) = _NotificationMeta;

  factory NotificationMeta.fromJson(Map<String, dynamic> json) =>
      _$NotificationMetaFromJson(json);
}

extension NotificationEntityFields on NotificationEntity {
  NotificationMeta get meta => switch (this) {
    TaskSuggestionNotification(:final meta) => meta,
    TaskOverdueNotification(:final meta) => meta,
    RelationshipCheckInNotification(:final meta) => meta,
    HabitAutoCompletedNotification(:final meta) => meta,
    GoalOffTrackNotification(:final meta) => meta,
    DayPlanOutcomeNotification(:final meta) => meta,
    SyncConflictNotification(:final meta) => meta,
  };

  String get id => meta.id;

  String get type => switch (this) {
    TaskSuggestionNotification() => NotificationKinds.taskSuggestion,
    TaskOverdueNotification() => NotificationKinds.taskOverdue,
    RelationshipCheckInNotification() => NotificationKinds.relationshipCheckIn,
    HabitAutoCompletedNotification() => NotificationKinds.habitAutoCompleted,
    GoalOffTrackNotification() => NotificationKinds.goalOffTrack,
    DayPlanOutcomeNotification() => NotificationKinds.dayPlanOutcome,
    SyncConflictNotification() => NotificationKinds.syncConflict,
  };

  /// Whether the row stays on the device that wrote it.
  ///
  /// Most rows sync: a suggestion, a reminder or a slipped goal is true on
  /// every device, and dealing with it on one must clear it on the others.
  /// A row about *this device's own processing* is not — a plan job runs in a
  /// device-local ledger and can only be retried here, and a conflict is
  /// this device's disagreement with a peer. Such a row is never enqueued,
  /// and neither are its lifecycle marks: a peer receiving a state update for
  /// a row it never got keeps the event pending forever, waiting for a base
  /// row that is never coming. Exhaustive so a new variant has to choose.
  bool get isDeviceLocal => switch (this) {
    TaskSuggestionNotification() => false,
    TaskOverdueNotification() => false,
    RelationshipCheckInNotification() => false,
    HabitAutoCompletedNotification() => false,
    GoalOffTrackNotification() => false,
    DayPlanOutcomeNotification() => true,
    SyncConflictNotification() => true,
  };

  String? get linkedEntityId => switch (this) {
    TaskSuggestionNotification(:final linkedTaskId) => linkedTaskId,
    TaskOverdueNotification(:final linkedTaskId) => linkedTaskId,
    RelationshipCheckInNotification(:final linkedRelationshipId) =>
      linkedRelationshipId,
    // A grouped row links several habits; the row itself leads to the
    // habits page, so no single id is "the" linked entity.
    HabitAutoCompletedNotification() => null,
    GoalOffTrackNotification(:final linkedGoalAgentId) => linkedGoalAgentId,
    DayPlanOutcomeNotification(:final dayId) => dayId,
    SyncConflictNotification() => syncConflictsSubjectId,
  };

  /// The same row with new words. Every variant carries a title and a body,
  /// but the sealed union has no shared `copyWith` for them, so this is the
  /// one place a re-wording touches each variant.
  NotificationEntity copyWithCopy({
    required String title,
    required String body,
  }) => switch (this) {
    TaskSuggestionNotification(
      :final meta,
      :final linkedTaskId,
      :final suggestionCount,
    ) =>
      NotificationEntity.taskSuggestion(
        meta: meta,
        linkedTaskId: linkedTaskId,
        suggestionCount: suggestionCount,
        title: title,
        body: body,
      ),
    TaskOverdueNotification(:final meta, :final linkedTaskId) =>
      NotificationEntity.taskOverdue(
        meta: meta,
        linkedTaskId: linkedTaskId,
        title: title,
        body: body,
      ),
    RelationshipCheckInNotification(:final meta, :final linkedRelationshipId) =>
      NotificationEntity.relationshipCheckIn(
        meta: meta,
        linkedRelationshipId: linkedRelationshipId,
        title: title,
        body: body,
      ),
    HabitAutoCompletedNotification(
      :final meta,
      :final linkedHabitIds,
      :final dayKey,
    ) =>
      NotificationEntity.habitAutoCompleted(
        meta: meta,
        linkedHabitIds: linkedHabitIds,
        dayKey: dayKey,
        title: title,
        body: body,
      ),
    GoalOffTrackNotification(:final meta, :final linkedGoalAgentId) =>
      NotificationEntity.goalOffTrack(
        meta: meta,
        linkedGoalAgentId: linkedGoalAgentId,
        title: title,
        body: body,
      ),
    DayPlanOutcomeNotification(:final meta, :final dayId, :final succeeded) =>
      NotificationEntity.dayPlanOutcome(
        meta: meta,
        dayId: dayId,
        succeeded: succeeded,
        title: title,
        body: body,
      ),
    SyncConflictNotification(:final meta, :final conflictCount) =>
      NotificationEntity.syncConflict(
        meta: meta,
        conflictCount: conflictCount,
        title: title,
        body: body,
      ),
  };

  NotificationEntity copyWithMeta(NotificationMeta meta) => switch (this) {
    TaskSuggestionNotification(
      :final linkedTaskId,
      :final suggestionCount,
      :final title,
      :final body,
    ) =>
      NotificationEntity.taskSuggestion(
        meta: meta,
        linkedTaskId: linkedTaskId,
        suggestionCount: suggestionCount,
        title: title,
        body: body,
      ),
    TaskOverdueNotification(:final linkedTaskId, :final title, :final body) =>
      NotificationEntity.taskOverdue(
        meta: meta,
        linkedTaskId: linkedTaskId,
        title: title,
        body: body,
      ),
    RelationshipCheckInNotification(
      :final linkedRelationshipId,
      :final title,
      :final body,
    ) =>
      NotificationEntity.relationshipCheckIn(
        meta: meta,
        linkedRelationshipId: linkedRelationshipId,
        title: title,
        body: body,
      ),
    HabitAutoCompletedNotification(
      :final linkedHabitIds,
      :final dayKey,
      :final title,
      :final body,
    ) =>
      NotificationEntity.habitAutoCompleted(
        meta: meta,
        linkedHabitIds: linkedHabitIds,
        dayKey: dayKey,
        title: title,
        body: body,
      ),
    GoalOffTrackNotification(
      :final linkedGoalAgentId,
      :final title,
      :final body,
    ) =>
      NotificationEntity.goalOffTrack(
        meta: meta,
        linkedGoalAgentId: linkedGoalAgentId,
        title: title,
        body: body,
      ),
    DayPlanOutcomeNotification(
      :final dayId,
      :final succeeded,
      :final title,
      :final body,
    ) =>
      NotificationEntity.dayPlanOutcome(
        meta: meta,
        dayId: dayId,
        succeeded: succeeded,
        title: title,
        body: body,
      ),
    SyncConflictNotification(:final conflictCount, :final title, :final body) =>
      NotificationEntity.syncConflict(
        meta: meta,
        conflictCount: conflictCount,
        title: title,
        body: body,
      ),
  };
}
