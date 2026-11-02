import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/tts/engine/speech_text.dart';

/// A turn the user spoke, whose reply she speaks back: the conversation it
/// was spoken in, and when — her reply is the first of hers after it.
typedef FrontSpokenTurn = ({String conversationId, DateTime spokenAt});

/// The utterance id her voice speaks a [conversationId]'s replies under, so
/// her lips follow only her own words in the conversation on screen.
String frontVoiceSourceId(String conversationId) =>
    '$_frontVoicePrefix$conversationId';

const _frontVoicePrefix = 'front-chat:';

/// What she says aloud for a spoken [turn], as [thread] shows it: whether
/// her answer has landed, and its words.
///
/// Her answer is her first reply after the turn, then the answer of each of
/// the turn's doors — a journal answer, an owner's answer, a specialist's
/// mirrored reply — in segment order. A journal question usually ends with
/// a dispatch alone, no reply of hers, so a reply was never enough: the
/// answer in its door went unspoken and she kept thinking. It has landed
/// once the turn holds a reply or a door, every door is walked, and every
/// goal or person a door handed the words to has replied: that door is done
/// as soon as the turn is handed over, its reply mirrored later. An answer
/// shown only while private entries are is not said aloud. Citation numbers
/// are left out, and Markdown is said as its words — a task she links is
/// said by its title ([withoutMarkdown]): they are for reading.
({bool landed, String text}) frontSpokenAnswer(
  FrontChatThread thread,
  FrontSpokenTurn turn,
) {
  bool after(AgentChatMessage m) => !m.createdAt.isBefore(turn.spokenAt);
  final asked = thread.messages
      .where((m) => m.role == AgentChatRole.user && after(m))
      .firstOrNull;
  final reply = thread.messages
      .where((m) => m.role == AgentChatRole.agent && after(m))
      .firstOrNull;
  final doors = asked == null
      ? const <FrontDoorEntry>[]
      : thread.doorsByMessageId[asked.id] ?? const <FrontDoorEntry>[];
  bool answered(FrontDoorEntry door) =>
      door.record.status == FrontDoorStatus.done &&
      (door.record.outcome is! FrontDoorChatTurn ||
          door.specialistReply != null);
  final landed = (reply != null || doors.isNotEmpty) && doors.every(answered);
  final parts = [
    ?reply?.text,
    for (final door in doors)
      switch (door.record.outcome) {
        FrontDoorAnswer(private: false, :final text) => text,
        _ => door.specialistReply,
      },
  ];
  final text = parts
      .whereType<String>()
      .map((part) => withoutMarkdown(part.replaceAll(_citation, '')).trim())
      .where((part) => part.isNotEmpty)
      .join('\n\n');
  return (landed: landed, text: text);
}

final _citation = RegExp(r'\s*\[\d+\]');

/// Whether [sourceId] is her voice in one of the conversations.
bool isFrontVoiceSourceId(String sourceId) =>
    sourceId.startsWith(_frontVoicePrefix);

/// The spoken turn still waiting for her spoken reply, or null. A spoken
/// question gets a spoken answer; a typed one only a written answer, so a
/// typed turn clears it (the owner's decision 3).
final NotifierProvider<FrontSpokenTurnNotifier, FrontSpokenTurn?>
frontSpokenTurnProvider =
    NotifierProvider<FrontSpokenTurnNotifier, FrontSpokenTurn?>(
      FrontSpokenTurnNotifier.new,
      name: 'frontSpokenTurnProvider',
    );

class FrontSpokenTurnNotifier extends Notifier<FrontSpokenTurn?> {
  @override
  FrontSpokenTurn? build() => null;

  /// A turn spoken in [conversationId], now.
  void spoke(String conversationId) =>
      state = (conversationId: conversationId, spokenAt: clock.now());

  /// Her reply is on its way to the voice, or no longer wanted.
  void settle() => state = null;
}
