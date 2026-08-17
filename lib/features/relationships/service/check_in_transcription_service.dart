import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart';

const _logTag = 'CheckInTranscriptionService';

/// How long a spoken check-in waits for its transcript before the sheet gives
/// up and hands the field back to the user.
///
/// Transcription is a provider round-trip over a whole recording, so this is
/// generous by design; the failure it guards against is a run that dies
/// without writing, not a slow model. The user can type in the meantime —
/// nothing here blocks the form.
const checkInTranscriptTimeout = Duration(minutes: 5);

/// A transcript wait in progress.
///
/// [result] resolves to the transcript, or `null` when the wait times out, is
/// cancelled, or the run it was waiting on never produced text. [cancel]
/// exists so a dismissed sheet stops listening immediately instead of holding
/// a database listener and re-reading on every write for the rest of the
/// timeout.
class CheckInTranscriptWait {
  CheckInTranscriptWait._(this.result, this._cancel);

  /// Builds a wait around a caller-supplied future, so a fake transcription
  /// service can hand the sheet something it drives directly.
  @visibleForTesting
  CheckInTranscriptWait.forTesting({
    required this.result,
    required void Function() onCancel,
  }) : _cancel = onCancel;

  final Future<String?> result;
  final void Function() _cancel;

  void cancel() => _cancel();
}

/// Gets a transcript for a spoken check-in.
///
/// Two jobs, because they are one decision: whether anything *can* transcribe
/// for a person, and getting the words once they have spoken.
///
/// The recorder fires the automatic transcription path on stop, so when that
/// path is live this only has to wait for it. When it is not — the common
/// case, since the automatic path is gated on a category switch that exists
/// for *unattended* inference — the request the user just made is run
/// explicitly instead. Either way exactly one run happens, so a spoken
/// check-in is never billed twice.
///
/// The check-in stays user-authored (ADR 0038): this only *offers* the words.
/// Nothing it returns is saved without the user pressing save.
class CheckInTranscriptionService {
  const CheckInTranscriptionService(
    this._journalDb,
    this._updateNotifications,
    this._automation,
    this._runner,
  );

  final JournalDb _journalDb;
  final UpdateNotifications _updateNotifications;
  final ProfileAutomationService _automation;
  final SkillInferenceRunner _runner;

  /// Whether a spoken check-in can produce a transcript for [subjectId].
  ///
  /// True when the automatic path will run on its own, or when an explicit
  /// request can resolve a transcription model. False means no model is
  /// configured at all — the only case worth refusing the gesture for.
  Future<bool> canTranscribe(String subjectId) async {
    final automatic = await _automation.hasAutomatedSkillType(
      subjectId: subjectId,
      skillType: SkillType.transcription,
    );
    if (automatic) return true;
    return _automation.canTranscribeOnRequest(subjectId: subjectId);
  }

  /// The transcript for [audioEntryId], running one explicitly when the
  /// recorder's automatic path will not.
  ///
  /// The wait is started *before* the run so a transcript written between the
  /// two is not missed. A run that resolves no model cancels the wait rather
  /// than leaving the caller on a spinner until the timeout.
  CheckInTranscriptWait transcribe({
    required String audioEntryId,
    required String subjectId,
    Duration timeout = checkInTranscriptTimeout,
  }) {
    final wait = _awaitTranscript(audioEntryId, timeout: timeout);
    unawaited(
      _runWhenAutomationWillNot(
        audioEntryId: audioEntryId,
        subjectId: subjectId,
        onNothingToRun: wait.cancel,
      ),
    );
    return wait;
  }

  /// Runs transcription explicitly unless the recorder's automatic path is
  /// already going to. Never throws: a failed run is indistinguishable from a
  /// silent one to the caller, and both end as "type it yourself".
  Future<void> _runWhenAutomationWillNot({
    required String audioEntryId,
    required String subjectId,
    required void Function() onNothingToRun,
  }) async {
    try {
      final automatic = await _automation.hasAutomatedSkillType(
        subjectId: subjectId,
        skillType: SkillType.transcription,
      );
      if (automatic) return;

      final result = await _automation.requestTranscription(
        subjectId: subjectId,
      );
      if (!result.handled) {
        onNothingToRun();
        return;
      }
      // No `linkedTaskId`: a person is not a task, and that parameter feeds
      // the consumption record's task field as well as the prompt context.
      await _runner.runTranscription(
        audioEntryId: audioEntryId,
        automationResult: result,
      );
    } catch (exception, stackTrace) {
      developer.log(
        'Requested transcription failed for $audioEntryId',
        name: _logTag,
        error: exception,
        stackTrace: stackTrace,
      );
      onNothingToRun();
    }
  }

  /// Watches for the transcript landing on [audioEntryId].
  ///
  /// Subscribes before the first read so a transcript that lands between the
  /// two is not missed, then re-reads on every notification carrying the entry
  /// id. Blank transcripts are treated as "not yet": the runner only writes
  /// `entryText` once it has a non-empty response, so an empty string means
  /// the audio entry's own creation notification, not a finished run.
  CheckInTranscriptWait _awaitTranscript(
    String audioEntryId, {
    required Duration timeout,
  }) {
    final completer = Completer<String?>();
    late final StreamSubscription<Set<String>> subscription;
    Timer? deadline;

    void finish(String? transcript) {
      if (completer.isCompleted) return;
      completer.complete(transcript);
    }

    Future<void> check() async {
      final transcript = await _readTranscript(audioEntryId);
      if (transcript != null) finish(transcript);
    }

    subscription = _updateNotifications.updateStream.listen((affectedIds) {
      if (affectedIds.contains(audioEntryId)) unawaited(check());
    });
    deadline = Timer(timeout, () => finish(null));

    unawaited(check());

    final result = completer.future.whenComplete(() {
      deadline?.cancel();
      // Not awaited, matching the relationships providers: the listener is
      // detached synchronously and nothing here depends on the cancel future.
      unawaited(subscription.cancel());
    });

    return CheckInTranscriptWait._(result, () => finish(null));
  }

  Future<String?> _readTranscript(String audioEntryId) async {
    final entity = await _journalDb.journalEntityById(audioEntryId);
    if (entity is! JournalAudio) return null;
    final text = entity.entryText?.plainText.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}

final checkInTranscriptionServiceProvider =
    Provider<CheckInTranscriptionService>(
      checkInTranscriptionService,
      name: 'checkInTranscriptionServiceProvider',
    );
CheckInTranscriptionService checkInTranscriptionService(Ref ref) =>
    CheckInTranscriptionService(
      ref.watch(journalDbProvider),
      getIt<UpdateNotifications>(),
      ref.watch(profileAutomationServiceProvider),
      ref.watch(skillInferenceRunnerProvider),
    );
