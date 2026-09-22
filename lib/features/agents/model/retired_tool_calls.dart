/// Rewrites a call to a retired task tool into the tool that absorbed it,
/// arguments included; any other call is returned unchanged.
///
/// `update_running_timer {timerId, summary}` became
/// `update_time_entry {entryId, summary}`. Rewriting the text of a time entry
/// is the same edit whether or not its timer is still ticking, and whichever
/// device it ticks on — the separate tool made a proposal written on one
/// device fail when confirmed on another, or after a restart.
///
/// Applied wherever a call is interpreted: a model call, so an echoed old
/// name is still deferred for confirmation rather than executed; a dispatch,
/// so a persisted proposal still applies; the supersede check, so a newer
/// text revision replaces a persisted one for the same entry; and the
/// change-set model and the proposal ledger, so a display duplicate and a
/// sticky rejection recorded under the old name still match the successor.
///
/// The names are spelled out here rather than taken from `TaskAgentToolNames`
/// because the model layer does not depend on the tool registry; the
/// registry's test pins the successor to a live, deferred tool.
({String toolName, Map<String, dynamic> args}) upgradeRetiredTaskAgentToolCall(
  String toolName,
  Map<String, dynamic> args,
) {
  if (toolName != _retiredRunningTimerTool) {
    return (toolName: toolName, args: args);
  }
  final upgraded = Map<String, dynamic>.of(args)..remove('timerId');
  if (args.containsKey('timerId')) {
    upgraded.putIfAbsent('entryId', () => args['timerId']);
  }
  return (toolName: _timeEntryTool, args: upgraded);
}

const _retiredRunningTimerTool = 'update_running_timer';
const _timeEntryTool = 'update_time_entry';
