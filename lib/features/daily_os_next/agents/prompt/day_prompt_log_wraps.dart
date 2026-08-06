import 'dart:convert';

import 'package:lotti/features/agents/workflow/prompt_log_wrap.dart';
import 'package:lotti/features/agents/workflow/prompt_record.dart';
import 'package:lotti/features/daily_os_next/agents/prompt/day_agent_prompt_sections.dart';

/// Re-renders a day wake's log inside its `<day_log>` tagged section,
/// neutralizing forged boundaries exactly as the live wake did.
String renderDayLogSectionWrap({
  required String head,
  required String log,
  required String tail,
}) =>
    '$head$dayLogSectionOpenMarker'
    '${neutralizePromptTags(log)}'
    '$dayLogSectionCloseMarker$tail';

/// Re-encodes a day wake's log as the LEGACY `"dayLog"` JSON field line.
///
/// Kept so v2 records persisted before the tagged-plaintext conversion still
/// reconstruct for the history UI.
String renderDayLogJsonLineWrap({
  required String head,
  required String log,
  required String tail,
}) => '$head  "dayLog": ${jsonEncode(log)},\n$tail';

/// The day agent's prompt-log splices, for
/// [promptLogWrapRenderersProvider].
///
/// Daily OS owns these payload formats, so it owns their reconstruction. The
/// composition root merges this map into the registry that
/// `WakePromptReconstructor` reads.
const dayPromptLogWrapRenderers = <String, PromptLogWrapRenderer>{
  promptRecordWrapDayLogSection: renderDayLogSectionWrap,
  promptRecordWrapDayLogJsonLine: renderDayLogJsonLineWrap,
};
