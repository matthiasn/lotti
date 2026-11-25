import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/speech/ui/widgets/recording/strip/recording_strip_layer.dart';
import 'package:material_ui/material_ui.dart';

/// Puts the recording strip ([RecordingStripLayer]) on the bottom edge of
/// [child] — the whole phone shell, or the desktop content column — and
/// moves everything else up to make room for it.
///
/// The strip runs along the very bottom, its glass reaching into the safe
/// area, on every page the take does not live on, so Stop is always in the
/// same place. Everything above it — the launcher row, a page's sticky
/// action bar, a scroll view's last row — moves up through the bottom inset
/// [child] reads: [MediaQueryData.padding] and [MediaQueryData.viewPadding]
/// become [RecordingStripLayer.lift]. A page that already respects the
/// bottom safe area needs no change of its own.
///
/// [showsTake] false leaves the running take to the desktop sidebar's
/// activity, which carries it while the sidebar is open; the receipt and
/// the tray still show here. The strip ignores the keyboard: it stays at the
/// bottom edge under an open keyboard rather than riding on top of it.
/// [omitAudio] leaves it out altogether, on a build with no recorder
/// (Flatpak).
class RecordingStripShell extends ConsumerWidget {
  const RecordingStripShell({
    required this.omitAudio,
    required this.child,
    this.showsTake = true,
    super.key,
  });

  final bool omitAudio;

  /// Whether the strip of a running take is drawn here.
  final bool showsTake;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (omitAudio) return child;
    final content = RecordingStripLayer.visible(
      ref.watch(recordingStripContentProvider),
      showsTake: showsTake,
    );
    final media = MediaQuery.of(context);
    final lifted = content == RecordingStripContent.none
        ? media.padding.bottom
        : RecordingStripLayer.lift(context, content);
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
          left: 0,
          right: 0,
          bottom: 0,
          child: RecordingStripLayer(showsTake: showsTake),
        ),
      ],
    );
  }
}
