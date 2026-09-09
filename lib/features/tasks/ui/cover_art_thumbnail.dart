import 'package:lotti/widgets/media/journal_image_resolver.dart';
import 'package:lotti/widgets/media/thumb_hash_backed_image.dart';
import 'package:material_ui/material_ui.dart';

/// Thumbnail widget for displaying task cover art.
///
/// Before the image file is on disk — a demo cover still downloading, AI
/// cover art still being written — the square shows the image's ThumbHash
/// stand-in when it has one, and stays empty when it does not; the resolver's
/// file watcher then swaps the picture in with a fade.
///
/// Only the rendering lives here. Which of file, stand-in or nothing can be
/// drawn — and noticing when that changes — is [JournalImageResolver]'s.
class CoverArtThumbnail extends StatelessWidget {
  const CoverArtThumbnail({
    required this.imageId,
    required this.size,
    this.cropX = 0.5,
    super.key,
  });

  final String imageId;
  final double size;

  /// Horizontal crop offset (0.0 = left, 0.5 = center, 1.0 = right).
  final double cropX;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: JournalImageResolver(
        imageId: imageId,
        builder: (context, resolved) {
          if (resolved == null || resolved.hasNothingToShow) {
            return const SizedBox.shrink();
          }
          return ThumbHashBackedImage(
            key: ValueKey(resolved.path),
            thumbHash: resolved.thumbHash,
            image: resolved.fileExists
                ? cappedFileImage(
                    resolved.path,
                    size: size,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  )
                : null,
            alignment: Alignment((cropX * 2) - 1, 0),
          );
        },
      ),
    );
  }
}
