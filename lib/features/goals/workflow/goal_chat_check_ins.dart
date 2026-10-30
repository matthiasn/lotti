/// What the user said in the goal chat, compacted like a check-in (ADR 0146).
///
/// Before this, a chat turn reached the agent only as the last few turns of
/// dialogue and through `search_goal_memory`: an injury or a change of plan
/// told in the chat fell out of every wake once the conversation moved on,
/// while the same words recorded as a check-in were carried for years by the
/// summaries and span digests. Short turns ("thanks", "ok, later") stay out —
/// they are conversation, not substance.
library;

import 'package:lotti/features/goals/model/goal_checkin_source.dart';
import 'package:lotti/features/goals/service/goal_chat_history_service.dart';

/// The fewest words a chat turn needs to be compacted as a check-in.
const goalChatCheckInMinWords = 12;

/// The user's substantive turns in [dialogue], as compaction sources keyed by
/// their message id.
List<GoalCheckInSource> goalChatCheckInSources(
  Iterable<GoalChatHistoryEntry> dialogue,
) => [
  for (final entry in dialogue)
    if (entry.role == GoalChatHistoryRole.user &&
        entry.text.split(RegExp(r'\s+')).length >= goalChatCheckInMinWords)
      GoalCheckInSource(
        entryId: entry.id,
        recordedAt: entry.createdAt,
        text: entry.text,
      ),
];

/// [userVoice] with each entry distilled from a chat turn in [chatEntryIds]
/// marked `via: chat`, so the agent knows it already answered those words.
List<Map<String, Object?>> goalMarkChatVoice(
  List<Map<String, Object?>> userVoice,
  Set<String> chatEntryIds,
) => [
  for (final entry in userVoice)
    if (chatEntryIds.contains(entry['sourceEntryId']))
      {...entry, 'via': 'chat'}
    else
      entry,
];
