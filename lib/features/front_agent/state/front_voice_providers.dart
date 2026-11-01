import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A turn the user spoke, whose reply she speaks back: the conversation it
/// was spoken in, and when — her reply is the first of hers after it.
typedef FrontSpokenTurn = ({String conversationId, DateTime spokenAt});

/// The utterance id her voice speaks a [conversationId]'s replies under, so
/// her lips follow only her own words in the conversation on screen.
String frontVoiceSourceId(String conversationId) =>
    '$_frontVoicePrefix$conversationId';

const _frontVoicePrefix = 'front-chat:';

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
