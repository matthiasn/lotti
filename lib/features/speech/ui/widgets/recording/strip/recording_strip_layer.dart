import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recording_homes.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_receipt.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_tray.dart';
import 'package:material_ui/material_ui.dart';

/// What the recording strip's place shows.
enum RecordingStripContent {
  /// Nothing records, nothing was just saved.
  none,

  /// The slim strip of a running take.
  strip,

  /// The full recorder, opened over the take or for a failed start.
  tray,

  /// The receipt of a take just saved.
  receipt,

  /// A take being stopped and saved: the strip's place held, inert, until
  /// its receipt is up.
  saving,
}

/// What the strip's place shows now — the one rule the layer draws and the
/// shell reserves room by.
///
/// The receipt first, while it lasts; then the strip's place held while a
/// take is saved; then the tray, when it is open over a
/// take or for a failure; then the strip, while a take runs that nothing
/// draws in place — no check-in, and no home of its subject on screen
/// ([takeAwayFromHome]).
final recordingStripContentProvider = Provider<RecordingStripContent>((ref) {
  if (ref.watch(recordingReceiptControllerProvider) != null) {
    return RecordingStripContent.receipt;
  }
  if (ref.watch(recordingSavingProvider)) return RecordingStripContent.saving;
  // A recorder that could not be built counts as nothing recording, so it
  // never takes the shell down.
  final take = takeAwayFromHome(ref.watch);
  final tray = ref.watch(recordingTrayControllerProvider);
  if (tray.open && (take || tray.failure != null)) {
    return RecordingStripContent.tray;
  }
  return take ? RecordingStripContent.strip : RecordingStripContent.none;
}, name: 'recordingStripContentProvider');

/// The shell's one entry point to the recording strip: it shows the strip,
/// its tray or its receipt in the strip's place, or nothing, arriving and
/// leaving in the motion tokens' rhythm — at once under reduced motion.
///
/// The shell puts it on the bottom edge — of the phone shell, or of the
/// desktop content column — and pads the pages by [lift]. The strip, and
/// the place it holds while its take saves, run edge to edge with the
/// bottom safe area inside them, like a sticky action bar. The tray and the
/// receipt are cards: inset by the gutter, above the safe area, capped at
/// the prose measure and centred, so on a wide window they read as part of
/// the page rather than a bar across it. The tray folds when a text field
/// takes the focus, so it never stands over the field being typed in.
///
/// [showsTake] false leaves the running take to someone else — the desktop
/// sidebar's activity — and draws only what opens over it: the tray and the
/// receipt.
class RecordingStripLayer extends ConsumerStatefulWidget {
  const RecordingStripLayer({this.showsTake = true, super.key});

  /// Whether the strip, and its held place while a take saves, are drawn.
  final bool showsTake;

  static const Key layerKey = ValueKey('recording-strip-layer');

  /// How long the strip takes to rise or fall.
  static const Duration motion = MotionDurations.medium1;

  /// Air between a card and what it sits above.
  static double gap(BuildContext context) => context.designTokens.spacing.step3;

  /// Distance from the bottom edge to a card: the safe area, and never less
  /// than `spacing.step3`, so it does not sit on the window's edge.
  static double bottomOffset(BuildContext context) => math.max(
    MediaQuery.paddingOf(context).bottom,
    context.designTokens.spacing.step3,
  );

  /// What the strip's place shows of [content] when the running take is
  /// drawn elsewhere ([showsTake] false): the tray and the receipt only.
  static RecordingStripContent visible(
    RecordingStripContent content, {
    required bool showsTake,
  }) =>
      !showsTake &&
          (content == RecordingStripContent.strip ||
              content == RecordingStripContent.saving)
      ? RecordingStripContent.none
      : content;

  /// The bottom inset the pages keep clear while the place shows [content]:
  /// the strip's whole extent, safe area included; or a card's height, its
  /// [gap] and its [bottomOffset]. The tray opens over the page without
  /// asking for more than the strip did. Zero when nothing shows.
  static double lift(BuildContext context, RecordingStripContent content) =>
      switch (content) {
        RecordingStripContent.none => 0,
        RecordingStripContent.strip ||
        RecordingStripContent.saving => RecordingStrip.extent(context),
        RecordingStripContent.tray || RecordingStripContent.receipt =>
          bottomOffset(context) + RecordingStrip.height(context) + gap(context),
      };

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

  /// A card in the strip's place: inset by the gutter and the side safe
  /// areas, above the bottom one, at most the prose measure wide.
  Widget _card(
    BuildContext context, {
    required Key key,
    required Widget child,
  }) {
    final media = MediaQuery.of(context);
    final gutter = context.designTokens.spacing.step5;
    return Padding(
      key: key,
      padding: EdgeInsets.only(
        left: media.padding.left + gutter,
        right: media.padding.right + gutter,
        bottom: RecordingStripLayer.bottomOffset(context),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kProseMeasureWidth),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = RecordingStripLayer.visible(
      ref.watch(recordingStripContentProvider),
      showsTake: widget.showsTake,
    );
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
      RecordingStripContent.tray => _card(
        context,
        key: const ValueKey('recording-strip-content-tray'),
        child: const RecordingStripTray(),
      ),
      // Held, inert and empty, so nothing moves under a second tap.
      RecordingStripContent.saving => AbsorbPointer(
        key: const ValueKey('recording-strip-content-saving'),
        child: DesignSystemGlassStrip(
          child: SizedBox(
            height:
                RecordingStrip.height(context) +
                MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ),
      RecordingStripContent.receipt => _card(
        context,
        key: ValueKey('recording-strip-content-receipt-${receipt!.entryId}'),
        child: RecordingReceiptRow(receipt: receipt),
      ),
    };
    // Its own Material: the shell puts the strip above the Scaffold, where
    // text would otherwise fall back to the debug underline.
    return Material(
      key: RecordingStripLayer.layerKey,
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: MotionCurves.emphasizedDecelerate,
        switchOutCurve: MotionCurves.standard,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomCenter,
          children: [...previous, ?current],
        ),
        // Inert until it has fully risen: the receipt arrives where Stop
        // just was, and a second tap meant for Stop must not land on Undo.
        transitionBuilder: (child, animation) => AnimatedBuilder(
          animation: animation,
          builder: (context, child) => IgnorePointer(
            ignoring: animation.status != AnimationStatus.completed,
            child: child,
          ),
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
