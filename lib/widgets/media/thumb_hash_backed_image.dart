import 'package:lotti/features/design_system/theme/motion_tokens.dart';
import 'package:lotti/utils/thumbhash.dart';
import 'package:lotti/widgets/media/thumb_hash_image.dart';
import 'package:material_ui/material_ui.dart';

/// A picture over its ThumbHash stand-in.
///
/// Three moments, one widget:
///
/// * **The file is not on disk yet** ([image] is null): only the stand-in
///   paints, filling the box the caller gave it exactly as the picture will,
///   so nothing moves when the picture lands. No hash, nothing painted.
/// * **The file has landed and is decoding**: the stand-in stays underneath
///   and the first decoded frame fades in over it — [MotionDurations.medium1],
///   or at once when the platform asks for reduced motion.
/// * **Later provider swaps** — a resize bucket crossing hands the [Image] a
///   new [ResizeImage] — keep the last frame on screen (gapless playback)
///   and do not fade again: a picture that has been seen stays seen.
///
/// Give it a [key] tied to the picture's identity (its path) so a *different*
/// picture in the same slot starts over from its own stand-in.
///
/// Give it **tight constraints** — a `SizedBox` of the slot's size, an
/// expanded `Stack` — as every caller does. The layers are a pass-through
/// [Stack] sized by the picture, and a picture without a frame yet has no
/// size of its own under loose constraints, which would leave the stand-in
/// zero-sized for exactly the window it exists for.
class ThumbHashBackedImage extends StatefulWidget {
  const ThumbHashBackedImage({
    required this.thumbHash,
    required this.image,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.errorBuilder,
    super.key,
  });

  /// The stand-in, or null when the picture has none.
  final ThumbHash? thumbHash;

  /// The picture, or null while its file is not on disk yet.
  final ImageProvider? image;

  /// How the picture — and its stand-in — fill the box.
  final BoxFit fit;

  /// Which part of the picture to keep when [fit] crops.
  final AlignmentGeometry alignment;

  /// Forwarded to the picture's [Image.errorBuilder].
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<ThumbHashBackedImage> createState() => _ThumbHashBackedImageState();
}

class _ThumbHashBackedImageState extends State<ThumbHashBackedImage> {
  /// Set once the picture has painted a frame. Read and written inside the
  /// picture's frame builder, which runs during the picture's own build — a
  /// plain field rather than [setState], because the build in progress
  /// already uses the new value and nothing outside it depends on it.
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final thumbHash = widget.thumbHash;
    final image = widget.image;
    final placeholder = thumbHash == null
        ? null
        : Image(
            image: ThumbHashImage(thumbHash),
            fit: _placeholderFit(widget.fit),
            alignment: widget.alignment,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          );
    if (image == null) {
      return placeholder ?? const SizedBox.shrink();
    }
    final picture = Image(
      image: image,
      fit: widget.fit,
      alignment: widget.alignment,
      gaplessPlayback: true,
      errorBuilder: widget.errorBuilder,
      frameBuilder: placeholder == null ? null : _reveal,
    );
    if (placeholder == null) {
      return picture;
    }
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: placeholder),
        picture,
      ],
    );
  }

  Widget _reveal(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (frame != null || wasSynchronouslyLoaded) {
      _revealed = true;
    }
    return AnimatedOpacity(
      opacity: _revealed ? 1 : 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : MotionDurations.medium1,
      curve: MotionCurves.emphasizedDecelerate,
      child: child,
    );
  }
}

/// The stand-in raster is [thumbHashRasterExtent] pixels across. Under
/// [BoxFit.scaleDown] it would sit in the box at its own size while the
/// picture — always larger than a thumbnail — scales down to fit, so the
/// stand-in takes [BoxFit.contain], which is what scale-down comes to for the
/// picture.
BoxFit _placeholderFit(BoxFit fit) =>
    fit == BoxFit.scaleDown ? BoxFit.contain : fit;
