import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
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

/// Where a spoken check-in's words come from, as the two names the user
/// can recognise from AI settings.
typedef CheckInTranscriptionRoute = ({String model, String provider});

/// Gets a transcript for a spoken check-in.
///
/// Two jobs, because they are one decision: whether anything *can* transcribe
/// for a person, and getting the words once they have spoken.
///
/// Uses only the system's selected default inference profile and its
/// transcription slot. The recording sheet disables its automatic trigger for
/// this capture, so this explicit request owns the one transcription run.
/// There is no subject/category resolution or model-discovery fallback.
///
/// The check-in stays user-authored (ADR 0038): this only *offers* the words.
/// Nothing it returns is saved without the user pressing save.
class CheckInTranscriptionService {
  const CheckInTranscriptionService(
    this._journalDb,
    this._updateNotifications,
    this._profileResolver,
    this._runner,
  );

  final JournalDb _journalDb;
  final UpdateNotifications _updateNotifications;
  final ProfileResolver _profileResolver;
  final SkillInferenceRunner _runner;

  /// Whether the selected system default has a usable transcription slot.
  Future<bool> canTranscribe() async => await _resolveProfile() != null;

  /// The names of the model and the provider a transcript would come
  /// from, for the composer's saved-audio line — or null when nothing can
  /// transcribe. Names only: never a key, an endpoint or a channel.
  Future<CheckInTranscriptionRoute?> route() async {
    final profile = await _resolveProfile();
    final model = profile?.transcriptionModel;
    final provider = profile?.transcriptionProvider;
    if (profile == null || model == null || provider == null) return null;
    return (model: model.name, provider: provider.name);
  }

  Future<ResolvedProfile?> _resolveProfile() async {
    final profile = await _profileResolver.resolveDefaultProfile();
    if (profile?.transcriptionModelId == null ||
        profile?.transcriptionProvider == null) {
      return null;
    }
    return profile;
  }

  /// Waits for [audioEntryId]'s transcript and starts one explicit request.
  ///
  /// Listening starts before inference so a fast result cannot be missed.
  /// Missing default configuration and inference errors end the wait promptly.
  CheckInTranscriptWait transcribe({
    required String audioEntryId,
    Duration timeout = checkInTranscriptTimeout,
  }) {
    final wait = _awaitTranscript(audioEntryId, timeout: timeout);
    unawaited(
      _runTranscription(
        audioEntryId: audioEntryId,
        onFailure: wait.cancel,
      ),
    );
    return wait;
  }

  /// Runs the system default's transcription slot without any fallback.
  Future<void> _runTranscription({
    required String audioEntryId,
    required void Function() onFailure,
  }) async {
    try {
      final profile = await _resolveProfile();
      if (profile == null) {
        onFailure();
        return;
      }
      // This is a manual request: no automated skill assignment or task id.
      // In particular, it must not start a profile's automatic summary skill.
      await _runner.runTranscription(
        audioEntryId: audioEntryId,
        automationResult: AutomationResult(
          handled: true,
          resolvedProfile: profile,
          skill: findBuiltInSkill(skillTranscribeContextId),
        ),
        onError: (_) => onFailure(),
      );
    } catch (exception, stackTrace) {
      developer.log(
        'Requested transcription failed for $audioEntryId',
        name: _logTag,
        error: exception,
        stackTrace: stackTrace,
      );
      onFailure();
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
      if (completer.isCompleted) return;
      try {
        final transcript = await _readTranscript(audioEntryId);
        if (transcript != null) finish(transcript);
      } catch (exception, stackTrace) {
        developer.log(
          'Could not read the check-in transcript',
          name: _logTag,
          error: exception,
          stackTrace: stackTrace,
        );
        finish(null);
      }
    }

    subscription = _updateNotifications.updateStream.listen(
      (affectedIds) {
        if (affectedIds.contains(audioEntryId)) unawaited(check());
      },
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Check-in transcript notifications failed',
          name: _logTag,
          error: error,
          stackTrace: stackTrace,
        );
        finish(null);
      },
      onDone: () => finish(null),
    );
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
      ref.watch(profileResolverProvider),
      ref.watch(skillInferenceRunnerProvider),
    );
