import 'package:lotti/classes/notification_producer.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// The agent's own words on an alert the deterministic tier armed — the LLM
/// tier's one contribution to the OS channel, and an opt-in one (ADR 0066).
///
/// A wake that authored a banner brief hands it here once the brief is
/// persisted. When the user allows agent-worded alerts, the brief's headline
/// becomes the open alert's title and its tagline — or, failing that, its
/// call to action — the body, fitted to lock-screen room. The brief is what
/// the banner dock renders, sanitised already, so the alert reads exactly
/// like the banner would. Nothing is minted: a subject without an armed
/// alert gets none, and an alert that already fired keeps the words it fired
/// with. Best-effort, like every sink call: the wake has committed by now.
class AgentAlertCopy {
  AgentAlertCopy({
    required this._alerts,
    required this._isAllowed,
    required this._logger,
  });

  /// The production shape: the user's say is the `notify_agent_copy` flag
  /// in [journalDb], read at the moment of the wake.
  AgentAlertCopy.fromFlags({
    required NotificationEpisodeRestater alerts,
    required JournalDb journalDb,
    required DomainLogger logger,
  }) : this(
         alerts: alerts,
         isAllowed: () => journalDb.getConfigFlag(notifyAgentCopyFlag),
         logger: logger,
       );

  final NotificationEpisodeRestater _alerts;

  /// The user's say — the `notify_agent_copy` flag, read at the moment of
  /// the wake so a switch flipped today binds today's wake.
  final Future<bool> Function() _isAllowed;
  final DomainLogger _logger;

  /// The room a title has on a lock screen before it is cut.
  static const int titleLimit = 80;

  /// The room a body has before it is cut.
  static const int bodyLimit = 140;

  /// The alert copy a [brief] yields: the headline as title, the tagline or
  /// else the call to action as body — each collapsed to one line and cut
  /// at a word boundary past its limit. `null` when the headline is blank,
  /// which is nothing worth re-wording an alert for.
  static ({String title, String? body})? fromBrief(NudgeBrief brief) {
    final title = fit(brief.headline, titleLimit);
    if (title.isEmpty) return null;
    final body = fit(brief.tagline ?? brief.cta ?? '', bodyLimit);
    return (title: title, body: body.isEmpty ? null : body);
  }

  /// [text] as one line of at most [limit] characters: whitespace runs
  /// collapse to a space, and a longer text is cut at the last word boundary
  /// before the limit and closed with an ellipsis.
  static String fit(String text, int limit) {
    final line = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.length <= limit) return line;
    final room = line.substring(0, limit - 1);
    final cut = room.lastIndexOf(' ');
    return '${cut > 0 ? room.substring(0, cut) : room}…';
  }

  /// Re-words [subjectId]'s armed alert with [brief], if the user allows it.
  Future<void> restate({
    required String subjectId,
    required NudgeBrief brief,
  }) async {
    try {
      if (!await _isAllowed()) return;
      final copy = fromBrief(brief);
      if (copy == null) return;
      await _alerts.restate(subjectId, title: copy.title, body: copy.body);
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.notifications,
        error,
        stackTrace: stackTrace,
        subDomain: 'agentAlertCopy.restate',
      );
    }
  }
}
