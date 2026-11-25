import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';

/// The subjects whose own page is on screen with a place for their takes —
/// a task's action bar — by subject id, counted, since two such bars for one
/// subject can overlap for a frame while one page replaces another.
///
/// A take for a subject listed here is drawn in place: the recording strip
/// and the sidebar's way back stand down for it. A bar enters while its page
/// is the one on screen, whether or not anything records, so a take started
/// there never shows on the strip, not even for a frame.
final recordingHomesProvider =
    NotifierProvider<RecordingHomes, Map<String, int>>(
      RecordingHomes.new,
      name: 'recordingHomesProvider',
    );

class RecordingHomes extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  /// A home for [subjectId]'s takes came on screen.
  void enter(String subjectId) {
    state = {...state, subjectId: (state[subjectId] ?? 0) + 1};
  }

  /// A home for [subjectId]'s takes left the screen.
  void leave(String subjectId) {
    final count = state[subjectId];
    if (count == null) return;
    state = count <= 1
        ? ({...state}..remove(subjectId))
        : {...state, subjectId: count - 1};
  }
}

/// Whether the running take — recording or paused — is one that nothing
/// draws in place: no check-in shows it (`inlineHostVisible`) and no home of
/// its subject is on screen. The take the recording strip and the sidebar's
/// activity carry, with the way back. False where the recorder could not be
/// built (its audio stack failed to load): nothing records then.
bool takeAwayFromHome(T Function<T>(ProviderListenable<T> provider) watch) {
  final homes = watch(recordingHomesProvider);
  try {
    return watch(
      audioRecorderControllerProvider.select(
        (state) =>
            state.isTakeActive &&
            !state.inlineHostVisible &&
            !homes.containsKey(state.linkedId),
      ),
    );
  } on Object {
    return false;
  }
}
