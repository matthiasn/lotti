import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_receipt.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_tray.dart';
import 'package:material_ui/material_ui.dart';

/// What the recording strip's place shows.
enum RecordingStripContent {
  /// Nothing records, nothing was just saved.
  none,

  /// The slim strip over a running take.
  strip,

  /// The full recorder, opened over the take or for a failed start.
  tray,

  /// The receipt of a take just saved.
  receipt,
}

/// What the strip's place shows now — the one rule the layer draws and the
/// shell reserves room by.
///
/// The receipt first, while it lasts; then the tray, when it is open over a
/// take or for a failure; then the strip, while a take runs that no
/// check-in screen is drawing in place.
final recordingStripContentProvider = Provider<RecordingStripContent>((ref) {
  if (ref.watch(recordingReceiptControllerProvider) != null) {
    return RecordingStripContent.receipt;
  }
  bool take;
  try {
    take = ref.watch(
      audioRecorderControllerProvider.select(
        (state) => state.isTakeActive && !state.inlineHostVisible,
      ),
    );
  } on Object {
    // The recorder could not be built (its audio stack failed to load):
    // nothing records, so there is nothing to show — rather than taking the
    // shell down with it.
    take = false;
  }
  final tray = ref.watch(recordingTrayControllerProvider);
  if (tray.open && (take || tray.failure != null)) {
    return RecordingStripContent.tray;
  }
  return take ? RecordingStripContent.strip : RecordingStripContent.none;
}, name: 'recordingStripContentProvider');

/// The shell's one entry point to the recording strip: it shows the strip,
/// its tray or its receipt in the strip's place, or nothing, rising into
/// view and falling away in the motion tokens' rhythm — at once under
/// reduced motion.
///
/// The shell positions it — on a phone directly above whatever owns the
/// bottom edge, on a wide window at the foot of the content column — and
/// pads the pages by [reservedHeight]. It caps itself at the prose measure
/// and centres there, so on a wide window it reads as part of the page
/// rather than a bar across it. The tray folds when a text field takes the
/// focus, so it never stands over the field being typed in.
class RecordingStripLayer extends ConsumerStatefulWidget {
  const RecordingStripLayer({super.key});

  static const Key layerKey = ValueKey('recording-strip-layer');

  /// How long the strip takes to rise or fall.
  static const Duration motion = MotionDurations.medium1;

  /// Air between the strip and what it sits above.
  static double gap(BuildContext context) => context.designTokens.spacing.step3;

  /// The room the pages give the strip's place while it shows [content]:
  /// the strip's own height and its [gap]. The tray opens over the page
  /// without asking for more.
  static double reservedHeight(
    BuildContext context,
    RecordingStripContent content,
  ) => content == RecordingStripContent.none
      ? 0
      : RecordingStrip.height(context) + gap(context);

  @override
  ConsumerState<RecordingStripLayer> createState() =>
      _RecordingStripLayerState();
}

class _RecordingStripLayerState extends ConsumerState<RecordingStripLayer> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_foldOnTextFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_foldOnTextFocus);
    super.dispose();
  }

  void _foldOnTextFocus() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null || !mounted) return;
    final typing =
        focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
    if (typing && ref.read(recordingTrayControllerProvider).open) {
      ref.read(recordingTrayControllerProvider.notifier).fold();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(recordingStripContentProvider);
    final receipt = ref.watch(recordingReceiptControllerProvider);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : RecordingStripLayer.motion;
    final child = switch (content) {
      RecordingStripContent.none => const SizedBox.shrink(
        key: ValueKey('recording-strip-none'),
      ),
      RecordingStripContent.strip => const RecordingStrip(
        key: ValueKey('recording-strip-content-strip'),
      ),
      RecordingStripContent.tray => const RecordingStripTray(
        key: ValueKey('recording-strip-content-tray'),
      ),
      RecordingStripContent.receipt => RecordingReceiptRow(
        key: ValueKey('recording-strip-content-receipt-${receipt!.entryId}'),
        receipt: receipt,
      ),
    };
    return Align(
      key: RecordingStripLayer.layerKey,
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kProseMeasureWidth),
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: MotionCurves.emphasizedDecelerate,
          switchOutCurve: MotionCurves.standard,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.bottomCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
