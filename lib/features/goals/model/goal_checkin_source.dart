import 'package:flutter/foundation.dart';

/// One check-in ready to be compacted: the user's words, and when they said
/// them.
///
/// A plain shape rather than a journal entity, so the goal workflow — which
/// runs headless in the agent tier — can be handed check-ins without taking a
/// dependency on the journal stack, and tested without one.
@immutable
class GoalCheckInSource {
  const GoalCheckInSource({
    required this.entryId,
    required this.recordedAt,
    required this.text,
  });

  final String entryId;
  final DateTime recordedAt;

  /// The transcript, or the typed note. A check-in with no words yet is not
  /// offered here — the recording is saved before it is transcribed, and
  /// compacting silence would produce a summary of nothing.
  final String text;
}

/// Resolves the check-ins linked to a goal that carry words.
typedef GoalCheckInSourceReader =
    Future<List<GoalCheckInSource>> Function(String agentId);
