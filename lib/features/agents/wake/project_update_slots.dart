import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';

/// The update slots of a project agent: the instants at which its stale
/// report may be refreshed on its own (`specs/tla/ProjectWakeGovernor.tla`).
///
/// A day is cut into slots of the agent's update interval, anchored at 06:00
/// local time — hourly slots start on the hour, a daily one at 06:00, an
/// eight-hour one at 06:00, 14:00 and 22:00. Every offered interval divides a
/// day, so the grid is the same every day. A slot is identified by its start,
/// so two devices that arm "the next slot" for the same agent arm the same
/// record.
abstract final class ProjectUpdateSlots {
  /// The interval of an agent with no stored preference.
  static const defaultIntervalMinutes = 60;

  /// The intervals the project page offers: one, two, four and eight hours,
  /// and a day.
  static const List<int> choices = [60, 120, 240, 480, 1440];

  /// Minutes after local midnight the grid is anchored at.
  static const int anchorMinutes = 6 * 60;

  /// Workspace-key prefix of a project-update slot record.
  static const workspacePrefix = 'project_update';

  /// The trigger token a slot wake carries, so the workflow can tell an
  /// automatic slot update from an explicit one.
  static const triggerToken = 'project_update_slot';
}

/// The effective update interval of an agent configured with [config]: a
/// stored value outside the offered choices falls back to hourly.
int effectiveUpdateIntervalMinutes(AgentConfig config) {
  final stored = config.updateIntervalMinutes;
  return stored != null && ProjectUpdateSlots.choices.contains(stored)
      ? stored
      : ProjectUpdateSlots.defaultIntervalMinutes;
}

/// The start of the first slot strictly after [after], in [after]'s zone.
DateTime nextProjectUpdateSlot(DateTime after, {required int intervalMinutes}) {
  assert(
    Duration.minutesPerDay % intervalMinutes == 0,
    'an update interval must divide a day',
  );
  // Wall-clock time of day, not elapsed time since midnight: on a day the
  // clocks change the two differ, and the grid follows the clock.
  final sinceMidnight = Duration(
    hours: after.hour,
    minutes: after.minute,
    seconds: after.second,
    milliseconds: after.millisecond,
    microseconds: after.microsecond,
  );
  // Slots before the anchor on the same day continue the previous day's
  // grid, which is the same grid because the interval divides a day.
  final sinceAnchor =
      sinceMidnight - const Duration(minutes: ProjectUpdateSlots.anchorMinutes);
  final interval = Duration(minutes: intervalMinutes).inMicroseconds;
  // Floor division: the slot the instant falls in, also before the anchor.
  var index = sinceAnchor.inMicroseconds ~/ interval;
  if (sinceAnchor.isNegative && sinceAnchor.inMicroseconds % interval != 0) {
    index -= 1;
  }
  final minutes =
      ProjectUpdateSlots.anchorMinutes + (index + 1) * intervalMinutes;
  return after.isUtc
      ? DateTime.utc(after.year, after.month, after.day, 0, minutes)
      : DateTime(after.year, after.month, after.day, 0, minutes);
}

/// The workspace key of the slot starting at [slotStart]: the slot's UTC
/// instant, so devices in one zone derive the same key.
String projectUpdateWorkspaceKey(DateTime slotStart) =>
    '${ProjectUpdateSlots.workspacePrefix}:'
    '${slotStart.toUtc().toIso8601String()}';

/// Whether a scheduled-wake workspace is a project-update slot.
bool isProjectUpdateWorkspace(String? workspaceKey) =>
    workspaceKey != null &&
    workspaceKey.startsWith('${ProjectUpdateSlots.workspacePrefix}:');

/// The record id of [agentId]'s slot starting at [slotStart].
String projectUpdateSlotRecordId(String agentId, DateTime slotStart) =>
    scheduledWakeRecordId(
      agentId,
      workspaceKey: projectUpdateWorkspaceKey(slotStart),
    );
