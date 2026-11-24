import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';

/// How long a receipt stays on screen before its take is committed.
const recordingReceiptWindow = Duration(seconds: 5);

/// What the receipt says about a take that was just stopped and saved.
@immutable
class RecordingReceipt {
  const RecordingReceipt({
    required this.entryId,
    required this.duration,
    required this.deadline,
    this.subjectId,
    this.subjectTitle,
    this.origin,
  });

  /// The audio entry the take became.
  final String entryId;

  /// How long the take ran.
  final Duration duration;

  /// When the receipt commits on its own.
  final DateTime deadline;

  /// What the take was linked to; null for a voice note.
  final String? subjectId;

  /// That subject's title, read when the take stopped; null for a voice
  /// note, or for a subject deleted mid-take — either way the receipt reads
  /// *Voice note saved*.
  final String? subjectTitle;

  /// Where the take started, for the receipt's *Open*.
  final RecordingOrigin? origin;

  @override
  bool operator ==(Object other) =>
      other is RecordingReceipt &&
      other.entryId == entryId &&
      other.duration == duration &&
      other.deadline == deadline &&
      other.subjectId == subjectId &&
      other.subjectTitle == subjectTitle &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(
    entryId,
    duration,
    deadline,
    subjectId,
    subjectTitle,
    origin,
  );
}

final recordingReceiptControllerProvider =
    NotifierProvider<RecordingReceiptController, RecordingReceipt?>(
      RecordingReceiptController.new,
      name: 'recordingReceiptControllerProvider',
    );

/// The receipt that replaces the recording strip for
/// [recordingReceiptWindow] after Stop: *Saved to …* with **Undo**, and
/// **Open** away from where the take started.
///
/// A take is *committed* when its receipt times out, when it is opened, or
/// when a new take starts. Only then does the take's automatic
/// transcription run and its caller hear the entry's id, so an Undo never
/// pays for inference and a caller never links a recording about to be
/// deleted. Undo deletes the entry instead, and the caller hears `null`.
///
/// Nothing is deleted without Undo: if the app dies inside the window the
/// entry stays, untranscribed, and shows *Not transcribed · Retry*.
class RecordingReceiptController extends Notifier<RecordingReceipt?> {
  Timer? _timer;
  ValueChanged<String?>? _onSettled;

  @override
  RecordingReceipt? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Shows a receipt for [entryId], committing any receipt still on screen
  /// first. [onSettled] hears the id at commit, or `null` after Undo.
  void show({
    required String entryId,
    required Duration duration,
    String? subjectId,
    String? subjectTitle,
    RecordingOrigin? origin,
    ValueChanged<String?>? onSettled,
  }) {
    commit();
    _onSettled = onSettled;
    state = RecordingReceipt(
      entryId: entryId,
      duration: duration,
      deadline: clock.now().add(recordingReceiptWindow),
      subjectId: subjectId,
      subjectTitle: subjectTitle,
      origin: origin,
    );
    _timer = Timer(recordingReceiptWindow, commit);
  }

  /// Commits the receipt on screen, if any: its take's automatic prompts
  /// start, in the background, and its caller hears the id.
  void commit() {
    final (receipt, settle) = _claim();
    if (receipt == null) return;
    ref
        .read(audioRecorderControllerProvider.notifier)
        .commitAutomation(receipt.entryId);
    settle?.call(receipt.entryId);
  }

  /// Deletes the take on screen, and tells its caller it is gone.
  ///
  /// A deletion that did not land leaves the entry where it is, so it is
  /// committed after all rather than left owing its transcript.
  Future<void> undo() async {
    final (receipt, settle) = _claim();
    if (receipt == null) return;
    final recorder = ref.read(audioRecorderControllerProvider.notifier);
    final deleted = await ref
        .read(journalRepositoryProvider)
        .deleteJournalEntity(receipt.entryId);
    if (deleted) {
      recorder.dropAutomation(receipt.entryId);
      settle?.call(null);
      return;
    }
    recorder.commitAutomation(receipt.entryId);
    settle?.call(receipt.entryId);
  }

  /// Takes the receipt off the screen synchronously, so a second tap, or
  /// the timer firing behind an Undo, finds nothing left to settle.
  (RecordingReceipt?, ValueChanged<String?>?) _claim() {
    _timer?.cancel();
    _timer = null;
    final receipt = state;
    final settle = _onSettled;
    _onSettled = null;
    if (receipt != null) state = null;
    return (receipt, settle);
  }
}
