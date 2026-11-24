import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_layer.dart';
import 'package:material_ui/material_ui.dart';

/// Puts the recording strip ([RecordingStripLayer]) at the bottom edge of
/// [child] — the whole phone shell, or the desktop content column — and
/// moves everything else up to make room for it.
///
/// The strip sits at the very bottom, just above the safe area, on every
/// page, so Stop is always in the same place. Everything above it — the
/// launcher row, a page's sticky action bar, a scroll view's last row —
/// moves up by the strip's height through the bottom inset [child] reads:
/// [MediaQueryData.padding] and [MediaQueryData.viewPadding] grow by
/// [RecordingStripLayer.reservedHeight]. A page that already respects the
/// bottom safe area needs no change of its own.
///
/// The strip ignores the keyboard: it stays at the bottom edge under an
/// open keyboard rather than riding on top of it. [omitAudio] leaves it out
/// altogether, on a build with no recorder (Flatpak).
class RecordingStripShell extends ConsumerWidget {
  const RecordingStripShell({
    required this.omitAudio,
    required this.child,
    super.key,
  });

  final bool omitAudio;
  final Widget child;

  /// Distance from the bottom edge to the strip: the safe area, and never
  /// less than `spacing.step3`, so it does not sit on the window's edge.
  static double bottomOffset(BuildContext context) => math.max(
    MediaQuery.paddingOf(context).bottom,
    context.designTokens.spacing.step3,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (omitAudio) return child;
    final content = ref.watch(recordingStripContentProvider);
    final reserved = RecordingStripLayer.reservedHeight(context, content);
    final media = MediaQuery.of(context);
    final bottom = bottomOffset(context);
    final lifted = reserved == 0 ? media.padding.bottom : bottom + reserved;
    final gutter = context.designTokens.spacing.step5;
    return Stack(
      children: [
        // Always under this MediaQuery, whether the strip shows or not: a
        // child that moved in and out of it would be torn down and rebuilt,
        // routes and scroll positions with it, at every take.
        MediaQuery(
          data: media.copyWith(
            padding: media.padding.copyWith(bottom: lifted),
            viewPadding: media.viewPadding.copyWith(
              bottom: math.max(media.viewPadding.bottom, lifted),
            ),
          ),
          child: child,
        ),
        Positioned(
          left: media.padding.left + gutter,
          right: media.padding.right + gutter,
          bottom: bottom,
          child: const RecordingStripLayer(),
        ),
      ],
    );
  }
}
