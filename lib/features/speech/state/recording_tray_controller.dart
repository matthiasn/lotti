import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/speech/state/recording_start_guard.dart';

/// Whether the recording strip's tray — the full recorder drawn above the
/// strip — is open, and the failure it was opened to explain, if any.
typedef RecordingTrayState = ({bool open, InlineRecordingFailure? failure});

const RecordingTrayState _folded = (open: false, failure: null);

final recordingTrayControllerProvider =
    NotifierProvider<RecordingTrayController, RecordingTrayState>(
      RecordingTrayController.new,
      name: 'recordingTrayControllerProvider',
    );

/// Opens and folds the recording strip's tray.
///
/// A start that failed has no sheet to rest on, so the tray opens for it,
/// carrying the failure card: *Open settings* for a refused microphone,
/// *Stop that recording* for a take that holds the recorder elsewhere.
class RecordingTrayController extends Notifier<RecordingTrayState> {
  @override
  RecordingTrayState build() => _folded;

  /// Opens the tray over the running take, without a failure card.
  void open() => state = (open: true, failure: null);

  /// Opens the tray on [failure]'s card.
  void openWithFailure(InlineRecordingFailure failure) =>
      state = (open: true, failure: failure);

  /// Folds the tray back into the strip and forgets any failure.
  void fold() => state = _folded;

  /// Opens a folded tray and folds an open one.
  void toggle() => state.open ? fold() : open();
}
