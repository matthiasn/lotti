import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_ended_controller.g.dart';

/// Tracks entry IDs whose timer sessions have just ended (recording→stopped
/// transition with duration >= 1 minute). Survives widget rebuilds and
/// navigation because it lives in Riverpod state rather than widget `State`.
///
/// Entries are added when a timer stops and removed when a new recording
/// starts on the same entry or when a rating is saved.
@Riverpod(keepAlive: true)
class SessionEndedController extends _$SessionEndedController {
  @override
  Set<String> build() => {};

  void markSessionEnded(String entryId) {
    state = {...state, entryId};
  }

  void clearSessionEnded(String entryId) {
    if (!state.contains(entryId)) return;
    state = {...state}..remove(entryId);
  }
}
