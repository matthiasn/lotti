import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:material_ui/material_ui.dart';

part 'task.freezed.dart';
part 'task.g.dart';

/// Priority levels for tasks, aligned with Linear-style P0..P3
enum TaskPriority {
  p0Urgent,
  p1High,
  p2Medium,
  p3Low,
}

/// Parse a DB/display string (e.g., 'P0', 'P1', 'P2', 'P3') to TaskPriority.
TaskPriority taskPriorityFromString(
  String value, {
  TaskPriority fallback = TaskPriority.p2Medium,
}) {
  switch (value.trim().toUpperCase()) {
    case 'P0':
      return TaskPriority.p0Urgent;
    case 'P1':
      return TaskPriority.p1High;
    case 'P2':
      return TaskPriority.p2Medium;
    case 'P3':
      return TaskPriority.p3Low;
    default:
      return fallback;
  }
}

extension TaskPriorityExt on TaskPriority {
  /// Short label used in compact UI and AI context strings, e.g., 'P0'.
  String get short => 'P$rank';

  /// Human-readable, localized priority label (Urgent / High / Medium / Low).
  /// Used where the opaque 'P0'..'P3' code would leave users guessing the
  /// urgency direction; [short] stays for compact badges and AI prompts.
  String localizedLabel(BuildContext context) {
    return switch (this) {
      TaskPriority.p0Urgent => context.messages.taskPriorityUrgent,
      TaskPriority.p1High => context.messages.taskPriorityHigh,
      TaskPriority.p2Medium => context.messages.taskPriorityMedium,
      TaskPriority.p3Low => context.messages.taskPriorityLow,
    };
  }

  /// Numerical rank used for ordering (lower is higher priority).
  int get rank => index; // 0..3

  /// Color aligned with task status theme tokens.
  Color colorForBrightness(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return switch (this) {
      TaskPriority.p0Urgent => isLight ? taskStatusDarkRed : taskStatusRed,
      TaskPriority.p1High => isLight ? taskStatusDarkOrange : taskStatusOrange,
      TaskPriority.p2Medium => isLight ? taskStatusDarkBlue : taskStatusBlue,
      TaskPriority.p3Low => Colors.grey,
    };
  }
}

@freezed
sealed class TaskStatus with _$TaskStatus {
  const factory TaskStatus.open({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskOpen;

  const factory TaskStatus.inProgress({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskInProgress;

  const factory TaskStatus.groomed({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskGroomed;

  const factory TaskStatus.blocked({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    required String reason,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskBlocked;

  const factory TaskStatus.onHold({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    required String reason,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskOnHold;

  const factory TaskStatus.done({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskDone;

  const factory TaskStatus.rejected({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskRejected;

  factory TaskStatus.fromJson(Map<String, dynamic> json) =>
      _$TaskStatusFromJson(json);
}

@freezed
abstract class TaskData with _$TaskData {
  const factory TaskData({
    required TaskStatus status,
    required DateTime dateFrom,
    required DateTime dateTo,
    required List<TaskStatus> statusHistory,
    required String title,
    DateTime? due,
    Duration? estimate,
    List<String>? checklistIds,
    String? languageCode,

    /// Who last set the language — `user` (via UI) or `agent` (tool call).
    ///
    /// Defaults to [ChangeSource.user] so that existing tasks with a language
    /// already set are treated as user-set (safe default — never overwrite).
    @Default(ChangeSource.user)
    @JsonKey(unknownEnumValue: ChangeSource.user)
    ChangeSource languageSource,

    /// Set of label IDs the user explicitly removed and does not want suggested by AI.
    /// Stored as a Set in memory; serialized as an array in JSON.
    Set<String>? aiSuppressedLabelIds,
    @Default(TaskPriority.p2Medium) TaskPriority priority,

    /// ID of a linked JournalImage to use as visual mnemonic / cover art.
    /// Displayed in task list thumbnails and detail view SliverAppBar.
    String? coverArtId,

    /// Horizontal offset for square thumbnail crop from 2:1 cover art.
    /// 0.0 = left edge, 0.5 = center (default), 1.0 = right edge.
    @Default(0.5) double coverArtCropX,

    /// Inference profile ID inherited from the category at task creation.
    /// Enables speech-to-text and image analysis independently of any agent.
    String? profileId,

    /// The effect keys of the confirmed agent changes that set one of this
    /// task's fields, each written in the same version as the value it set
    /// (ADR 0098). A second application of the same change — confirmed on
    /// another device before the two synced, or confirmed again after a
    /// reopen — finds its key here and does nothing, even where the user has
    /// since put the field back to the value the change was proposed
    /// against. Only grows: every write over a stored task keeps the stored
    /// keys ([TaskDataOnStored.onStored]).
    Set<String>? appliedChangeEffects,

    /// Whether the user turned pull request tracking on for this task, which
    /// gives it its Pull requests section even with none linked. Only ever
    /// turns on: every write over a stored task keeps it
    /// ([TaskDataOnStored.onStored]), and resolving a conflict keeps it when
    /// either side has it ([TaskDataOnStored.withTrackingOf]).
    @Default(false) bool tracksPullRequests,
  }) = _TaskData;

  factory TaskData.fromJson(Map<String, dynamic> json) =>
      _$TaskDataFromJson(json);
}

/// Writing a task's data over the version stored in the journal.
extension TaskDataOnStored on TaskData {
  /// This data as written over [stored]: the checklist list stays the stored
  /// one — `ChecklistRepository.updateTaskChecklistIds` owns it — and the
  /// applied change effects and pull request tracking are joined
  /// ([withEffectsOf], [withTrackingOf]).
  TaskData onStored(TaskData stored) => withEffectsOf(
    stored,
  ).withTrackingOf(stored).copyWith(checklistIds: stored.checklistIds);

  /// This data tracking pull requests when it or [other] does. Tracking only
  /// turns on, so joining is an `or`: a screen's copy read before tracking
  /// was turned on, or the side of a conflict the user kept, cannot turn it
  /// off again, and two devices turning it on at once agree.
  TaskData withTrackingOf(TaskData other) =>
      tracksPullRequests || !other.tracksPullRequests
      ? this
      : copyWith(tracksPullRequests: true);

  /// This data recording every change [other] records as applied, too. The
  /// record only grows ([TaskData.appliedChangeEffects]): whatever a write
  /// keeps of the fields — a screen's copy read before a change was applied,
  /// or one side of a resolved conflict — it keeps every record, so no
  /// applied change can apply again (ADR 0098).
  TaskData withEffectsOf(TaskData other) {
    final effects = {
      ...?other.appliedChangeEffects,
      ...?appliedChangeEffects,
    };
    return copyWith(appliedChangeEffects: effects.isEmpty ? null : effects);
  }

  /// This data with its status set to [next], recorded in the status history
  /// when it changes the status. A status equal to the current one by its
  /// database string leaves the data as it is: whoever sets a status — the
  /// user, the task agent or the day agent's triage — records it here, so
  /// the history holds every status the task was set to
  /// (`specs/tla/TaskFieldWrites.tla`, HistoryComplete).
  TaskData withStatus(TaskStatus next) => next.toDbString == status.toDbString
      ? this
      : copyWith(status: next, statusHistory: [...statusHistory, next]);

  /// This data with its status history holding every status [other]'s
  /// holds, too, each once (by id), in the order they were set — by id
  /// where two were set at the same instant, so both directions of a join
  /// order the history the same way. Resolving a
  /// conflict keeps one side's fields, but a status either side was set to
  /// was set, so the history keeps both sides'
  /// (`specs/tla/TaskFieldWrites.tla`, HistoryComplete).
  TaskData withHistoryOf(TaskData other) {
    final seen = {for (final s in statusHistory) s.id};
    final joined = [
      ...statusHistory,
      ...other.statusHistory.where((s) => seen.add(s.id)),
    ];
    if (joined.length == statusHistory.length) return this;
    return copyWith(
      statusHistory: joined
        ..sort((a, b) {
          final byTime = a.createdAt.compareTo(b.createdAt);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        }),
    );
  }
}

TaskStatus taskStatusFromString(String status) {
  TaskStatus newStatus;
  final now = DateTime.now();

  if (status == 'DONE') {
    newStatus = TaskStatus.done(
      id: uuid.v1(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else if (status == 'GROOMED') {
    newStatus = TaskStatus.groomed(
      id: uuid.v1(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else if (status == 'IN PROGRESS') {
    newStatus = TaskStatus.inProgress(
      id: uuid.v1(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else if (status == 'BLOCKED') {
    newStatus = TaskStatus.blocked(
      id: uuid.v1(),
      createdAt: now,
      reason: 'needs a reason',
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else if (status == 'ON HOLD') {
    newStatus = TaskStatus.onHold(
      id: uuid.v1(),
      createdAt: now,
      reason: 'needs a reason',
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else if (status == 'REJECTED') {
    newStatus = TaskStatus.rejected(
      id: uuid.v1(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else {
    newStatus = TaskStatus.open(
      id: uuid.v1(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  }
  return newStatus;
}

extension TaskStatusExtension on TaskStatus {
  String localizedLabel(BuildContext context) {
    return switch (this) {
      TaskOpen() => context.messages.taskStatusOpen,
      TaskGroomed() => context.messages.taskStatusGroomed,
      TaskInProgress() => context.messages.taskStatusInProgress,
      TaskBlocked() => context.messages.taskStatusBlocked,
      TaskOnHold() => context.messages.taskStatusOnHold,
      TaskDone() => context.messages.taskStatusDone,
      TaskRejected() => context.messages.taskStatusRejected,
    };
  }

  String get toDbString => switch (this) {
    TaskOpen() => 'OPEN',
    TaskGroomed() => 'GROOMED',
    TaskInProgress() => 'IN PROGRESS',
    TaskBlocked() => 'BLOCKED',
    TaskOnHold() => 'ON HOLD',
    TaskDone() => 'DONE',
    TaskRejected() => 'REJECTED',
  };

  Color colorForBrightness(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    return switch (this) {
      TaskOpen() => isLight ? taskStatusDarkOrange : taskStatusOrange,
      TaskGroomed() =>
        isLight ? taskStatusDarkGreen : taskStatusLightGreenAccent,
      TaskInProgress() => isLight ? taskStatusDarkBlue : taskStatusBlue,
      TaskBlocked() => isLight ? taskStatusDarkRed : taskStatusRed,
      TaskOnHold() => isLight ? taskStatusDarkRed : taskStatusRed,
      TaskDone() => isLight ? taskStatusDarkGreen : taskStatusGreen,
      TaskRejected() => isLight ? taskStatusDarkRed : taskStatusRed,
    };
  }
}
