import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The single refine⇄capture voice state machine, shared by the modal
/// content and the standalone side panel so the two surfaces cannot
/// drift (they previously held diverging copies of this logic).
///
/// Wires the [CaptureController] stream into the refine controller:
/// partial transcripts stream in while listening/transcribing, the final
/// transcript lands as a review, and capture errors cancel listening.
void listenCaptureForRefine(
  WidgetRef ref,
  DraftPlan draft,
) {
  ref.listen<CaptureState>(captureControllerProvider, (previous, next) {
    final refineNotifier = ref.read(refineControllerProvider(draft).notifier);
    if (next.phase == CapturePhase.listening ||
        next.phase == CapturePhase.transcribing) {
      if (next.partialTranscript.trim().isNotEmpty) {
        refineNotifier.updateActiveTranscript(next.partialTranscript);
      }
      return;
    }
    if (next.phase == CapturePhase.captured) {
      refineNotifier.reviewTranscript(next.transcript);
      return;
    }
    if (next.phase == CapturePhase.error) {
      refineNotifier.cancelListening();
    }
  });
}

/// Orb tap behavior per refine phase.
void handleRefineVoiceTap({
  required RefineState refineState,
  required RefineController refineNotifier,
  required CaptureController captureNotifier,
}) {
  switch (refineState.phase) {
    case RefinePhase.idle:
    case RefinePhase.reviewing:
    case RefinePhase.diffReady:
      captureNotifier.reset();
      captureNotifier.skipRealtimeTranscriptVerificationForNextCapture();
      refineNotifier.beginListening(
        resetTranscript: refineState.phase != RefinePhase.diffReady,
      );
      unawaited(captureNotifier.toggle());
    case RefinePhase.listening:
      unawaited(captureNotifier.toggle());
    case RefinePhase.thinking:
    case RefinePhase.accepted:
      break;
  }
}

/// Maps the refine phase (plus the live capture phase) onto the orb's
/// visual [CapturePhase].
///
/// While the refine controller still says `listening` but capture has
/// already moved on to `transcribing`, the orb must show the transcribing
/// treatment — the idle mapping used previously left a dead-looking,
/// fully-armed mic during finalization.
CapturePhase refineOrbPhaseFor(RefinePhase phase, CapturePhase capturePhase) {
  switch (phase) {
    case RefinePhase.idle:
    case RefinePhase.accepted:
      return CapturePhase.idle;
    case RefinePhase.thinking:
      return CapturePhase.transcribing;
    case RefinePhase.reviewing:
      return CapturePhase.captured;
    case RefinePhase.listening:
      return switch (capturePhase) {
        CapturePhase.listening => CapturePhase.listening,
        CapturePhase.transcribing => CapturePhase.transcribing,
        _ => CapturePhase.idle,
      };
    case RefinePhase.diffReady:
      return CapturePhase.captured;
  }
}

/// Screen-reader label for the orb per refine phase.
String refineVoiceLabel(BuildContext context, RefinePhase phase) {
  switch (phase) {
    case RefinePhase.idle:
    case RefinePhase.diffReady:
      return context.messages.dailyOsNextCaptureVoiceButtonStart;
    case RefinePhase.reviewing:
      return context.messages.dailyOsNextCaptureVoiceButtonReset;
    case RefinePhase.listening:
      return context.messages.dailyOsNextCaptureVoiceButtonStop;
    case RefinePhase.thinking:
    case RefinePhase.accepted:
      return context.messages.dailyOsNextCaptureVoiceButtonReset;
  }
}
