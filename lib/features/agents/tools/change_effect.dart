import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/logic/services/metadata_service.dart';

/// What a confirmed change item's dispatch knows about its own effect, so
/// that applying the item twice — confirmed on two devices before they sync —
/// changes the journal once (ADR 0075, `specs/tla/ChangeSetLifecycle.tla`).
///
/// - [key] names the effect: the same on every device and for every decision
///   of the item (`ChangeItemEffect.effectKeyIn`). A tool that creates an
///   entity derives the entity's id from it ([entityId]), finds the entity
///   already there on the second application, and does nothing.
/// - [base] holds the task fields the proposal was made against
///   (`ChangeItem.base`). A tool that sets a field applies only while the
///   task still holds them ([changedField]), so a late second application
///   cannot overwrite an edit made after the first.
/// - A tool that sets a field also records [key] on the task in the same
///   write ([recordOn]), and applies only while the task does not record it
///   ([recordedOn]): a value restored to the base after the first
///   application passes the value compare, but not this one (ADR 0098).
/// - [targetBase] does what [base] does for a tool that edits another entity — a
///   checklist item, a time entry, a project (`ChangeItem.targetBase`,
///   ADR 0097): the tool compares it with that entity ([changedIn]).
///
/// The dispatch carries them as reserved arguments. Only
/// `ChangeSetConfirmationService` writes them ([addTo]), replacing whatever a
/// proposal's arguments carried under those names, and the dispatcher strips
/// them before any handler reads the arguments ([takeFrom]).
class ChangeEffect {
  const ChangeEffect({required this.key, this.base, this.targetBase});

  /// The reserved argument carrying [key].
  static const keyArg = '_effectKey';

  /// The reserved argument carrying [base].
  static const baseArg = '_base';

  /// The reserved argument carrying [targetBase].
  static const targetBaseArg = '_targetBase';

  static const List<String> _reserved = [keyArg, baseArg, targetBaseArg];

  final String key;
  final Map<String, dynamic>? base;
  final Map<String, dynamic>? targetBase;

  /// [args] carrying this effect, and nothing else under the reserved names.
  Map<String, dynamic> addTo(Map<String, dynamic> args) {
    final withEffect = Map<String, dynamic>.of(args)
      ..remove(baseArg)
      ..remove(targetBaseArg)
      ..[keyArg] = key;
    if (base case final base?) withEffect[baseArg] = base;
    if (targetBase case final targetBase?) {
      withEffect[targetBaseArg] = targetBase;
    }
    return withEffect;
  }

  /// Splits the effect [addTo] put into [args] from the tool's own arguments.
  /// The effect is `null` when [args] name none — a dispatch that is not the
  /// confirmation of a change item.
  static ({ChangeEffect? effect, Map<String, dynamic> args}) takeFrom(
    Map<String, dynamic> args,
  ) {
    if (!_reserved.any(args.containsKey)) {
      return (effect: null, args: args);
    }
    final key = args[keyArg];
    Map<String, dynamic>? asMap(Object? value) =>
        value is Map ? Map<String, dynamic>.from(value) : null;
    return (
      effect: key is String && key.isNotEmpty
          ? ChangeEffect(
              key: key,
              base: asMap(args[baseArg]),
              targetBase: asMap(args[targetBaseArg]),
            )
          : null,
      args: Map<String, dynamic>.of(args)
        ..removeWhere((name, _) => _reserved.contains(name)),
    );
  }

  /// The `uuidV5Input` of the entity this effect creates in [role] — a name
  /// for each entity one effect creates, such as `task` or `checklist-item:0`.
  String entityInput(String role) => 'change-effect:$key:$role';

  /// The id of the entity this effect creates in [role], as
  /// `MetadataService.generateId` derives it from [entityInput].
  String entityId(String role) =>
      MetadataService.deterministicId(entityInput(role));

  /// Whether the entity this effect creates in [role] is already in [db] —
  /// written here, or synced from a device that applied the same item —
  /// counting one deleted since: the effect happened, and a second
  /// application must not bring back what the user removed.
  Future<bool> created(JournalDb db, String role) async {
    final id = entityId(role);
    final found = await db.journalEntityMapForIdsIncludingDeleted([id]);
    return found.containsKey(id);
  }

  /// Whether [task] records this effect as applied
  /// ([TaskData.appliedChangeEffects]): a field it set was set once, here or
  /// on a device the task synced from, and applying it again would overwrite
  /// whatever the field holds since — the base value the user restored
  /// included, which the value compare of [changedField] cannot tell from an
  /// untouched field (ADR 0098).
  bool recordedOn(Task task) =>
      task.data.appliedChangeEffects?.contains(key) ?? false;

  /// [task] recording this effect as applied, for the tool to write in the
  /// same version as the field it sets, so the record syncs with the value.
  Task recordOn(Task task) => task.copyWith(
    data: task.data.copyWith(
      appliedChangeEffects: {...?task.data.appliedChangeEffects, key},
    ),
  );

  /// The first field of [base] whose value in [current] differs from the one
  /// the proposal was made against, or `null` when every field still holds
  /// it (or nothing was recorded). [current] is keyed as [base].
  String? changedField(Map<String, Object?> current) =>
      _firstChanged(base, current);

  /// The first field of [targetBase] whose value in [current] — the edited
  /// entity's fields, keyed as [targetBase] — differs from the one the
  /// proposal was made against, or `null` when every field still holds it
  /// (or nothing was recorded). A field that moved on was applied already,
  /// on another device that confirmed the same item, or edited since.
  String? changedIn(Map<String, Object?> current) =>
      _firstChanged(targetBase, current);

  static String? _firstChanged(
    Map<String, dynamic>? recorded,
    Map<String, Object?> current,
  ) {
    for (final MapEntry(:key, :value) in (recorded ?? const {}).entries) {
      if (current[key] != value) return key;
    }
    return null;
  }

  /// The success a tool reports when [changedIn] (or [changedField]) found
  /// [field] of [what] moved on: nothing is written, and it is not a
  /// failure, which would put the item back to pending, or retract it over a
  /// confirm that did land elsewhere.
  static ToolExecutionResult notApplied(String what, String field) =>
      ToolExecutionResult(
        success: true,
        output:
            "Nothing applied: the $what's $field is no longer the value "
            'this change was proposed against — it was applied already, or '
            'edited since — so it stays as it is.',
      );
}

/// The key under which the fields of an entity record when [field] last
/// changed, for an entity that keeps such a stamp. A stamp moves on every
/// write of the field, so a base that records it sees an edit the value
/// alone cannot — the user restoring the value the proposal was made against
/// (ADR 0097).
String changedAtKey(String field) => '$field@';

/// The fields of the checklist item [data] `update_checklist_item` sets,
/// keyed as its arguments, with the stamps the item keeps of their last
/// change ([changedAtKey]): `checkedAt` for the check, `titleSetAt` for
/// the title. What `ChangeItem.targetBase` records for it.
Map<String, Object?> checklistItemFields(ChecklistItemData data) => {
  'title': data.title,
  changedAtKey('title'): data.titleSetAt?.toIso8601String(),
  'isChecked': data.isChecked,
  changedAtKey('isChecked'): data.checkedAt?.toIso8601String(),
};

/// The fields of the time entry [entry] `update_time_entry` sets, keyed as
/// its arguments: the range as the journal holds it, and the text. A time
/// entry keeps no stamp of their last change, so a base of these values
/// cannot see the user restoring one of them.
Map<String, Object?> timeEntryFields(JournalEntity entry) => {
  'startTime': entry.meta.dateFrom.toIso8601String(),
  'endTime': entry.meta.dateTo.toIso8601String(),
  'summary': switch (entry) {
    JournalEntry(:final entryText) => entryText?.plainText,
    _ => null,
  },
};

/// The field `update_project_status` sets on a project whose status is
/// [status]: the status, as the canonical word the tool's arguments carry,
/// and the id of the status entry, which every status change mints anew
/// ([changedAtKey]) — and an Undo puts back.
Map<String, Object?> projectFields(ProjectStatus status) => {
  'status': canonicalProjectStatusOf(status),
  changedAtKey('status'): status.id,
};

/// The `ChangeItem.targetBase` of a proposal with [args] against an entity
/// whose fields are [fields]: the fields [args] sets, and their stamps, as
/// the entity holds them. `null` when [args] sets none of them.
Map<String, dynamic>? targetBaseFor(
  Map<String, dynamic> args,
  Map<String, Object?> fields,
) {
  bool sets(String key) =>
      args.containsKey(key) ||
      (key.endsWith('@') && args.containsKey(key.substring(0, key.length - 1)));
  final recorded = <String, dynamic>{
    for (final MapEntry(:key, :value) in fields.entries)
      if (sets(key)) key: value,
  };
  return recorded.isEmpty ? null : recorded;
}

/// The task field [toolName] sets, keyed as in `TaskMetadataSnapshot`, or
/// `null` for a tool that sets none of them. The field a proposal records
/// in `ChangeItem.base`.
String? taskFieldSetBy(String toolName) => switch (toolName) {
  TaskAgentToolNames.setTaskTitle => 'title',
  TaskAgentToolNames.setTaskStatus => 'status',
  TaskAgentToolNames.updateTaskPriority => 'priority',
  TaskAgentToolNames.updateTaskEstimate => 'estimateMinutes',
  TaskAgentToolNames.updateTaskDueDate => 'dueDate',
  TaskAgentToolNames.setTaskLanguage => 'languageCode',
  _ => null,
};
