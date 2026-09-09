import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/media/journal_image_resolver.dart';
import 'package:lotti/widgets/media/thumb_hash_backed_image.dart';
import 'package:material_ui/material_ui.dart';

/// Thumbnail for a [JournalImage] inside a list card.
///
/// Loads the image file at a fixed `height`. While the file is still
/// missing, an image that carries a ThumbHash shows its blurred stand-in in
/// the same box; one that does not takes no space at all.
///
/// Only the rendering lives here. Which of file, stand-in or nothing can be
/// drawn — and noticing when the file lands or changes on disk (a sync, an
/// import) — is [JournalImageFileResolver]'s: the card is handed its entry
/// by the list, so it needs the file half of the resolver alone.
class CardImageWidget extends StatelessWidget {
  const CardImageWidget({
    required this.journalImage,
    required this.height,
    super.key,
    this.fit = BoxFit.scaleDown,
  });

  final JournalImage journalImage;
  final int height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final size = height.toDouble();
    return JournalImageFileResolver(
      image: journalImage,
      builder: (context, resolved) {
        if (resolved.hasNothingToShow) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: size,
          height: size,
          child: ThumbHashBackedImage(
            key: ValueKey(resolved.path),
            thumbHash: resolved.thumbHash,
            image: resolved.fileExists
                ? cappedFileImage(
                    resolved.path,
                    size: size,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  )
                : null,
            fit: fit,
          ),
        );
      },
    );
  }
}
