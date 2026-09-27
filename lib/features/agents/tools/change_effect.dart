import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
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
///
/// The dispatch carries both as reserved arguments. Only
/// `ChangeSetConfirmationService` writes them ([addTo]), replacing whatever a
/// proposal's arguments carried under those names, and the dispatcher strips
/// them before any handler reads the arguments ([takeFrom]).
class ChangeEffect {
  const ChangeEffect({required this.key, this.base});

  /// The reserved argument carrying [key].
  static const keyArg = '_effectKey';

  /// The reserved argument carrying [base].
  static const baseArg = '_base';

  final String key;
  final Map<String, dynamic>? base;

  /// [args] carrying this effect, and nothing else under the reserved names.
  Map<String, dynamic> addTo(Map<String, dynamic> args) {
    final withEffect = Map<String, dynamic>.of(args)
      ..remove(baseArg)
      ..[keyArg] = key;
    if (base case final base?) withEffect[baseArg] = base;
    return withEffect;
  }

  /// Splits the effect [addTo] put into [args] from the tool's own arguments.
  /// The effect is `null` when [args] name none — a dispatch that is not the
  /// confirmation of a change item.
  static ({ChangeEffect? effect, Map<String, dynamic> args}) takeFrom(
    Map<String, dynamic> args,
  ) {
    if (!args.containsKey(keyArg) && !args.containsKey(baseArg)) {
      return (effect: null, args: args);
    }
    final key = args[keyArg];
    final base = args[baseArg];
    return (
      effect: key is String && key.isNotEmpty
          ? ChangeEffect(
              key: key,
              base: base is Map ? Map<String, dynamic>.from(base) : null,
            )
          : null,
      args: Map<String, dynamic>.of(args)
        ..remove(keyArg)
        ..remove(baseArg),
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
  String? changedField(Map<String, Object?> current) {
    for (final MapEntry(:key, :value) in (base ?? const {}).entries) {
      if (current[key] != value) return key;
    }
    return null;
  }
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
