import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_leading.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';

/// The recording strip: one slim glass band across the bottom edge, on
/// every page away from where the take lives, while a take runs — the
/// leading glyph ([RecordingStripLeading]: the way back, or the live dot),
/// the live level filling the room between it and the controls, pause, and
/// Stop carrying the running time.
///
/// It wears the sticky action bar's glass ([DesignSystemGlassStrip]), edge
/// to edge with no capsule around it: a shrunk action bar, not a card. No
/// words: the level says the take is live.
///
/// Stop always saves; the receipt that follows offers Undo. The row
/// ([RecordingStripRow]) is the one the take's own task draws in its action
/// bar. Its body — anywhere outside its buttons — takes the user back to
/// where the take started; where there is nowhere to go back to, or the
/// user is already there, it opens the full recorder above it as a tray, as
/// a swipe up always does.
class RecordingStrip extends ConsumerWidget {
  const RecordingStrip({super.key});

  static const Key stripKey = ValueKey('recording-strip');
  static const Key rowKey = ValueKey('recording-strip-row');
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

  /// The surface of what opens over the strip's place: the island's glass.
  /// The receipt and the place held while a take saves are full capsules
  /// around their round controls (no [radius]); the taller tray takes a
  /// radius of its own. The strip itself is edge to edge ([build]).
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
    final tray = ref.read(recordingTrayControllerProvider.notifier);
    final safe = MediaQuery.paddingOf(context);

    Future<void> back() async {
      final origin = ref.read(audioRecorderControllerProvider).origin;
      final route = ref.read(navServiceProvider).activeRoute;
      // Nowhere left to go — the subject was deleted since — opens the
      // tray too, rather than leaving the tap without an answer.
      final went =
          origin != null &&
          !isOnRecordingOrigin(route, origin) &&
          await ref.read(recordingSessionProvider).returnToOrigin(origin);
      if (!went) tray.open();
    }

    return DesignSystemGlassStrip(
      key: stripKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: back,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < 0) tray.open();
        },
        child: Padding(
          // The safe areas inside the glass, as the action bar has them:
          // the glass runs into the home indicator's inset and a landscape
          // notch's, the row clear of them.
          padding: EdgeInsets.only(
            left: safe.left + tokens.spacing.step5,
            right: safe.right + tokens.spacing.step5,
            bottom: safe.bottom,
          ),
          child: const RecordingStripRow(),
        ),
      ),
    );
  }

  /// The strip's whole height on screen: its hairline, its row, and the
  /// bottom safe area it reaches into.
  static double extent(BuildContext context) =>
      DesignSystemGlassStrip.hairlineHeight +
      height(context) +
      MediaQuery.paddingOf(context).bottom;
}

/// The strip's one row, with nothing around it: the leading glyph, the
/// level over all the room it leaves, pause, and Stop carrying the running
/// time — [RecordingStrip.height] tall and at most the prose measure wide,
/// centred. The strip draws it on its glass; a
/// task's action bar draws it bare at its foot (`ActionBarRecording`), so
/// the take keeps the same row wherever it shows.
///
/// It watches the recorder through selectors: the status and the running
/// time in whole seconds. The level samples feed only the bars, so a level
/// tick never rebuilds the row.
class RecordingStripRow extends ConsumerWidget {
  const RecordingStripRow({super.key});

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
    final gap = SizedBox(width: tokens.spacing.step3);
    // At most the prose measure wide, centred: on a wide window the glass
    // runs edge to edge, but the row stays one reading width, under the
    // action bar's centred buttons.
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kProseMeasureWidth),
        child: SizedBox(
          key: RecordingStrip.rowKey,
          height: RecordingStrip.height(context),
          child: Row(
            children: [
              const RecordingStripLeading(compact: true),
              gap,
              const Expanded(
                child: RecordingStripBars(key: RecordingStrip.barsKey),
              ),
              gap,
              const RecordingPauseRing(key: RecordingStrip.pauseKey),
              gap,
              RecordingStopPill(
                key: RecordingStrip.stopKey,
                paused: paused,
                progress: progress,
                progressSemanticsLabel: spokenClockLabel(messages, progress),
                onTap: () => ref.read(recordingSessionProvider).stop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The strip's level: the recorder's own level line over all the room the
/// row leaves it, held still while the take is paused. The one part of the
/// strip — and of a task bar's recording row — that watches every sample.
class RecordingStripBars extends ConsumerWidget {
  const RecordingStripBars({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioRecorderControllerProvider);
    return LayoutBuilder(
      builder: (context, constraints) =>
          RecordingLevelLine(state: state, width: constraints.maxWidth),
    );
  }
}

/// Pause, or resume while the take is paused — then the filled accent disc,
/// the one thing to press. The strip's row and a task bar's recording row
/// both carry it.
class RecordingPauseRing extends ConsumerWidget {
  const RecordingPauseRing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final paused = ref.watch(
      audioRecorderControllerProvider.select(
        (state) => state.status == AudioRecorderStatus.paused,
      ),
    );
    final recorder = ref.read(audioRecorderControllerProvider.notifier);
    return RecordingRingButton(
      emphasized: paused,
      label: paused
          ? messages.audioRecordingResume
          : messages.audioRecordingPause,
      icon: paused ? LottiIconsFilled.play : LottiIconsFilled.pause,
      solid: true,
      onTap: () => paused ? recorder.resume() : recorder.pause(),
    );
  }
}
