import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/state/recording_return.dart';
import 'package:lotti/features/speech/state/recording_start_guard.dart';
import 'package:lotti/features/speech/state/recording_subject.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/providers/service_providers.dart';

/// The origin of a take starting now, through [read] (a `Ref`'s or a
/// `WidgetRef`'s): the route on screen, and the scroll offset its page
/// reported, if it reports one.
///
/// Null where the app's navigation is not wired up — a recorder mounted on
/// its own, in a widgetbook story or on a test bench. Such a take has no
/// way back, which the strip shows as a subject with no arrow.
RecordingOrigin? captureRecordingOrigin(
  T Function<T>(ProviderListenable<T> provider) read, {
  String? subjectId,
}) {
  final String route;
  try {
    route = read(navServiceProvider).activeRoute;
  } on ProviderException {
    return null;
  }
  return RecordingOrigin(
    route: route,
    subjectId: subjectId,
    scrollOffset: read(recordingOriginScrollProvider).offsetFor(route),
  );
}

final recordingSessionProvider = Provider<RecordingSession>(
  RecordingSession.new,
  name: 'recordingSessionProvider',
);

/// A take started here, and what its caller asked to happen once it is
/// committed.
typedef _Take = ({Completer<String?> done, bool openCreatedEntry});

/// The one way a microphone starts a take: on the recording strip, at once,
/// with no sheet in between.
///
/// [start] applies the rule every way of starting shares
/// ([decideRecordingStart]), captures where the take started
/// ([RecordingOrigin]) and starts the app-wide recorder. Its future
/// completes when the take is *committed* — with the audio entry's id — or
/// with `null` when it is discarded, undone or never started. [stop] saves
/// the take and puts up the receipt; [discard] throws it away; and
/// [returnToOrigin] takes the user back to where it started.
class RecordingSession {
  RecordingSession(this._ref);

  final Ref _ref;
  _Take? _take;

  /// Set by [openReceipt] for the commit it causes: a voice note opened
  /// from its receipt opens its entry whatever its caller asked for.
  bool _openingReceipt = false;

  AudioRecorderController get _recorder =>
      _ref.read(audioRecorderControllerProvider.notifier);
  RecordingTrayController get _tray =>
      _ref.read(recordingTrayControllerProvider.notifier);

  /// Starts a take linked to [linkedId] and filed under [categoryId].
  ///
  /// - A take already running for [linkedId] is not started again: the
  ///   tray opens over it, and the future is that take's own, when it was
  ///   started here.
  /// - A take running for anything else is left alone: the tray opens on
  ///   the *Stop that recording* card, and the future is `null`.
  /// - A start the recorder refuses opens the tray on its failure card.
  ///
  /// A receipt still on screen is committed first. [origin] defaults to the
  /// route on screen, with the scroll offset its page reported.
  /// [transcriptionHandledByCaller] keeps the recorder's own automation off
  /// this take; the caller transcribes it once it hears the id. A take with
  /// no [linkedId] opens its entry when committed, unless
  /// [openCreatedEntry] is false — for a caller that links it itself.
  Future<String?> start({
    String? linkedId,
    String? categoryId,
    bool transcriptionHandledByCaller = false,
    bool openCreatedEntry = true,
    RecordingOrigin? origin,
  }) async {
    switch (decideRecordingStart(
      _ref.read(audioRecorderControllerProvider),
      linkedId: linkedId,
    )) {
      case RecordingStartDecision.busy:
        _tray.openWithFailure(InlineRecordingFailure.recorderBusy);
        return null;
      case RecordingStartDecision.attach:
        _tray.open();
        return _take?.done.future;
      case RecordingStartDecision.start:
        break;
    }
    _ref.read(recordingReceiptControllerProvider.notifier).commit();
    _tray.fold();
    final take = (
      done: Completer<String?>(),
      openCreatedEntry: openCreatedEntry,
    );
    _take = take;
    _recorder.setCategoryId(categoryId);
    final failure = await _recorder.record(
      linkedId: linkedId,
      transcriptionHandledByCaller: transcriptionHandledByCaller,
      origin: origin ?? captureRecordingOrigin(_ref.read, subjectId: linkedId),
    );
    if (failure != null) {
      _settle(take, null);
      _tray.openWithFailure(failureOfStart(failure));
    }
    return take.done.future;
  }

  /// Stops and saves the running take and puts up its receipt; the take is
  /// committed when the receipt is. A take that could not be saved opens
  /// the tray on the *not saved* card.
  Future<void> stop() async {
    final running = _ref.read(audioRecorderControllerProvider);
    if (!running.isTakeActive) return;
    final take = _take;
    _take = null;
    _tray.fold();
    // Read before stopping: stop forgets it with the take.
    final handledByCaller = _recorder.transcriptionHandledByCaller;
    final entryId = await _recorder.stop(deferAutomation: true);
    if (entryId == null) {
      if (take != null) _settle(take, null);
      _tray.openWithFailure(InlineRecordingFailure.notSaved);
      return;
    }
    final subjectId = running.linkedId;
    final subject = subjectId == null
        ? null
        : await _ref.read(recordingSubjectProvider(subjectId).future);
    _ref
        .read(recordingReceiptControllerProvider.notifier)
        .show(
          entryId: entryId,
          duration: running.progress,
          subjectId: subjectId,
          subjectTitle: recordingSubjectTitle(subject),
          origin: running.origin,
          // The recorder's own automation transcribes only a take linked to
          // a subject that is still there, with Transcribe left on; a
          // caller that transcribes the take itself says so on its own.
          transcribing:
              subject != null &&
              !handledByCaller &&
              running.enableSpeechRecognition != false,
          onSettled: (committed) {
            if (take != null) _settle(take, committed);
            if (committed != null &&
                subjectId == null &&
                (_openingReceipt || (take?.openCreatedEntry ?? false))) {
              _ref.read(navServiceProvider).beamToNamed('/journal/$committed');
            }
          },
        );
  }

  /// The receipt's *Open*: commits the take on screen and goes to what it
  /// was saved to — back to where a subject's take started, or into a voice
  /// note's own entry.
  Future<void> openReceipt() async {
    final receipt = _ref.read(recordingReceiptControllerProvider);
    if (receipt == null) return;
    _openingReceipt = true;
    try {
      _ref.read(recordingReceiptControllerProvider.notifier).commit();
    } finally {
      _openingReceipt = false;
    }
    final origin = receipt.origin;
    if (receipt.subjectId != null && origin != null) {
      await returnToOrigin(origin);
    }
  }

  /// Throws the running take away, after the tray's ✕ was confirmed.
  Future<void> discard() async {
    final take = _take;
    _take = null;
    _tray.fold();
    if (take != null) _settle(take, null);
    await _recorder.cancel();
  }

  /// Takes the user back to where [origin]'s take started; false when there
  /// is nowhere left to go.
  ///
  /// The origin route first, with its scroll offset owed to the page; else,
  /// when that route no longer resolves (its tab was switched off), the
  /// subject's own page by its kind. A subject deleted since leaves nowhere
  /// to go. Arriving at a subject highlights its live record button once.
  Future<bool> returnToOrigin(RecordingOrigin origin) async {
    final nav = _ref.read(navServiceProvider);
    final subjectId = origin.subjectId;
    final subject = subjectId == null
        ? null
        : await _ref.read(recordingSubjectProvider(subjectId).future);
    if (subjectId != null && subject == null) return false;
    final fallback = subject == null ? null : recordingSubjectRoute(subject);
    final String target;
    if (nav.canBeamTo(origin.route)) {
      target = origin.route;
      final offset = origin.scrollOffset;
      if (offset != null) {
        _ref.read(recordingOriginScrollProvider).requestRestore(target, offset);
      }
    } else if (fallback != null && nav.canBeamTo(fallback)) {
      target = fallback;
    } else {
      return false;
    }
    nav.beamToNamed(target);
    if (subjectId != null) {
      _ref.read(recordingArrivalProvider.notifier).arrive(subjectId);
    }
    return true;
  }

  void _settle(_Take take, String? entryId) {
    if (!take.done.isCompleted) take.done.complete(entryId);
  }
}
