import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_leading.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The recording strip: one slim row that stays on screen, on every page,
/// while a take runs — the leading glyph ([RecordingStripLeading]: the way
/// back, or the live dot), the live level filling the room between it and
/// the controls, pause, and Stop carrying the running time.
///
/// No words: a title cut to a few letters said little, and the level says
/// the take is live. The tray, opened from the row, names what it is for.
///
/// Stop always saves; the receipt that follows offers Undo. The row's body
/// — anywhere outside its buttons — opens the full recorder above it as a
/// tray, as does a swipe up.
///
/// It watches the recorder through selectors: the status and the running
/// time in whole seconds. The level samples feed only the bars, so a level
/// tick never rebuilds the row.
class RecordingStrip extends ConsumerWidget {
  const RecordingStrip({super.key});

  static const Key stripKey = ValueKey('recording-strip');
  static const Key barsKey = ValueKey('recording-strip-bars');
  static const Key pauseKey = ValueKey('recording-strip-pause');
  static const Key stopKey = ValueKey('recording-strip-stop');

  /// The strip's height — the receipt's too: room for the controls with
  /// `spacing.step2` above and below — 56 at the default text size —
  /// growing with the text scale the way the island's capsule does, so the
  /// receipt's caption and title never clip.
  static double height(BuildContext context) {
    final tokens = context.designTokens;
    final scaler = MediaQuery.textScalerOf(context);
    final lines = tokens.typography.lineHeight;
    final text =
        scaler.scale(lines.caption).ceilToDouble() +
        scaler.scale(lines.bodySmall).ceilToDouble();
    return math.max(tokens.spacing.step9, text) + tokens.spacing.step2 * 2;
  }

  /// The strip's surface: the island's glass. The strip and the receipt are
  /// full capsules around their round controls (no [radius]); the taller
  /// tray takes a radius of its own.
  static Widget surface(
    BuildContext context, {
    required Widget child,
    Key? key,
    double? radius,
  }) {
    final tokens = context.designTokens;
    final corner = BorderRadius.circular(
      radius ?? height(context) / 2,
    );
    return DsGlassChipSurface(
      key: key,
      radius: corner,
      blurred: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dsGlassChipFill(tokens),
          borderRadius: corner,
        ),
        child: DecoratedBox(
          // The hairline over the fill, as on every glass chip.
          decoration: BoxDecoration(
            border: dsGlassChipBorder(tokens),
            borderRadius: corner,
          ),
          position: DecorationPosition.foreground,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final status = ref.watch(
      audioRecorderControllerProvider.select((state) => state.status),
    );
    // Whole seconds, which is all Stop shows: the recorder advances the
    // progress with every level sample, and the row must not rebuild for
    // each of them.
    final progress = Duration(
      seconds: ref.watch(
        audioRecorderControllerProvider.select(
          (state) => state.progress.inSeconds,
        ),
      ),
    );
    final paused = status == AudioRecorderStatus.paused;
    final recorder = ref.read(audioRecorderControllerProvider.notifier);
    final tray = ref.read(recordingTrayControllerProvider.notifier);
    final gap = SizedBox(width: tokens.spacing.step3);

    return surface(
      context,
      key: stripKey,
      child: Semantics(
        // The body opens the tray; the buttons inside keep their own taps.
        onTapHint: messages.recordingStripOpenRecorder,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tray.open,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < 0) tray.open();
          },
          child: SizedBox(
            height: height(context),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
              child: Row(
                children: [
                  const RecordingStripLeading(compact: true),
                  gap,
                  const Expanded(child: _StripBars(key: barsKey)),
                  gap,
                  RecordingRingButton(
                    key: pauseKey,
                    emphasized: paused,
                    label: paused
                        ? messages.audioRecordingResume
                        : messages.audioRecordingPause,
                    icon: paused
                        ? LottiIconsFilled.play
                        : LottiIconsFilled.pause,
                    solid: true,
                    onTap: () => paused ? recorder.resume() : recorder.pause(),
                  ),
                  gap,
                  RecordingStopPill(
                    key: stopKey,
                    paused: paused,
                    progress: progress,
                    progressSemanticsLabel: spokenClockLabel(
                      messages,
                      progress,
                    ),
                    onTap: () => ref.read(recordingSessionProvider).stop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip's level: the recorder's own level line over all the room the
/// row leaves it, held still while the take is paused. The one part of the
/// strip that watches every sample.
class _StripBars extends ConsumerWidget {
  const _StripBars({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioRecorderControllerProvider);
    return LayoutBuilder(
      builder: (context, constraints) =>
          RecordingLevelLine(state: state, width: constraints.maxWidth),
    );
  }
}
