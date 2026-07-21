import 'dart:async';
import 'dart:io';

import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart'
    show AttributedTranscriptionException;
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';

enum DayProcessingRunResult { idle, succeeded, deferred, failed }

typedef DayAudioTranscribe = Future<String> Function(String audioPath);
typedef DayTranscriptAttach =
    Future<bool> Function(DayProcessingJob job, String transcript);

/// Claims and executes device-local Daily OS derived work.
class DayProcessingOutboxProcessor {
  DayProcessingOutboxProcessor({
    required this.repository,
    required this.transcribe,
    required this.attachTranscript,
    Future<bool> Function()? isOnline,
    double Function()? randomUnit,
  }) : _isOnline = isOnline ?? (() async => true),
       _randomUnit = randomUnit ?? (() => 0.5);

  final DayProcessingOutboxRepository repository;
  final DayAudioTranscribe transcribe;
  final DayTranscriptAttach attachTranscript;
  final Future<bool> Function() _isOnline;
  final double Function() _randomUnit;

  Future<DayProcessingRunResult> processNext() async {
    final claim = await repository.claimNext();
    if (claim == null) return DayProcessingRunResult.idle;
    var job = claim.job;
    try {
      if (!File(job.audioPath).existsSync()) {
        await repository.markFailure(
          jobId: job.id,
          claimToken: claim.token,
          failureClass: DayProcessingFailureClass.missingAsset,
          error: 'Saved audio is not available locally yet',
        );
        return DayProcessingRunResult.deferred;
      }
      if (!await _isOnline()) {
        await repository.markFailure(
          jobId: job.id,
          claimToken: claim.token,
          failureClass: DayProcessingFailureClass.network,
          error: 'Offline',
        );
        return DayProcessingRunResult.deferred;
      }

      var transcript = job.resultTranscript;
      if (transcript == null || transcript.trim().isEmpty) {
        transcript = (await transcribe(job.audioPath)).trim();
        if (transcript.isEmpty) {
          throw const FormatException('Transcription returned no text');
        }
        job = await repository.markTranscriptReady(
          jobId: job.id,
          claimToken: claim.token,
          transcript: transcript,
        );
      }

      final attached = await attachTranscript(job, transcript);
      if (!attached) {
        await repository.markFailure(
          jobId: job.id,
          claimToken: claim.token,
          failureClass: DayProcessingFailureClass.local,
          error: 'Journal transcript commit was not accepted',
          retryDelay: const Duration(seconds: 1),
        );
        return DayProcessingRunResult.deferred;
      }
      await repository.markSucceeded(
        jobId: job.id,
        claimToken: claim.token,
      );
      return DayProcessingRunResult.succeeded;
    } catch (error) {
      final failure = classifyDayProcessingFailure(error);
      await repository.markFailure(
        jobId: job.id,
        claimToken: claim.token,
        failureClass: failure.failureClass,
        error: error.toString(),
        retryAfter: failure.retryAfter,
        retryDelay: _retryDelay(job.attempts),
      );
      return failure.failureClass == DayProcessingFailureClass.deterministic ||
              failure.failureClass == DayProcessingFailureClass.setupRequired ||
              failure.failureClass == DayProcessingFailureClass.missingAsset
          ? DayProcessingRunResult.failed
          : DayProcessingRunResult.deferred;
    }
  }

  Future<int> drain({int maxJobs = 32}) async {
    var processed = 0;
    while (processed < maxJobs) {
      final result = await processNext();
      if (result == DayProcessingRunResult.idle) break;
      processed += 1;
    }
    return processed;
  }

  Duration _retryDelay(int attempts) {
    const baseMilliseconds = 5000;
    const capMilliseconds = 15 * 60 * 1000;
    final exponent = attempts.clamp(0, 20);
    final maximum = (baseMilliseconds * (1 << exponent)).clamp(
      baseMilliseconds,
      capMilliseconds,
    );
    final unit = _randomUnit().clamp(0.0, 1.0);
    return Duration(milliseconds: (maximum * unit).round());
  }
}

typedef DayProcessingFailure = ({
  DayProcessingFailureClass failureClass,
  Duration? retryAfter,
});

DayProcessingFailure classifyDayProcessingFailure(Object error) {
  // Attribution wraps the real provider failure; classify the cause.
  if (error is AttributedTranscriptionException) {
    return classifyDayProcessingFailure(error.cause);
  }
  if (error is SocketException) {
    return (
      failureClass: DayProcessingFailureClass.network,
      retryAfter: null,
    );
  }
  if (error is TimeoutException) {
    return (
      failureClass: DayProcessingFailureClass.timeout,
      retryAfter: null,
    );
  }
  if (error is FormatException) {
    return (
      failureClass: DayProcessingFailureClass.deterministic,
      retryAfter: null,
    );
  }
  if (error is TranscriptionException) {
    if (error.originalError case final SocketException _) {
      return (
        failureClass: DayProcessingFailureClass.network,
        retryAfter: null,
      );
    }
    final status = error.statusCode;
    if (status == 401 || status == 403) {
      return (
        failureClass: DayProcessingFailureClass.setupRequired,
        retryAfter: null,
      );
    }
    if (status == 429) {
      return (
        failureClass: DayProcessingFailureClass.providerBusy,
        retryAfter: null,
      );
    }
    if (status == 408 ||
        status == 409 ||
        status == 425 ||
        (status != null && status >= 500)) {
      return (
        failureClass: DayProcessingFailureClass.timeout,
        retryAfter: null,
      );
    }
    if (status != null && status >= 400) {
      return (
        failureClass: DayProcessingFailureClass.deterministic,
        retryAfter: null,
      );
    }
  }
  // Model/provider configuration gaps surface as plain exceptions from
  // model resolution, before any HTTP status exists — waiting for the
  // network cannot fix them, only Settings can.
  final lower = error.toString().toLowerCase();
  if (lower.contains('no audio-capable model') ||
      lower.contains('provider not found') ||
      lower.contains('not configured') ||
      lower.contains('credential')) {
    return (
      failureClass: DayProcessingFailureClass.setupRequired,
      retryAfter: null,
    );
  }
  return (
    failureClass: DayProcessingFailureClass.timeout,
    retryAfter: null,
  );
}
