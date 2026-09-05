import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/file_watcher_mixin.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/thumbhash.dart';
import 'package:lotti/widgets/media/thumb_hash_backed_image.dart';
import 'package:material_ui/material_ui.dart';

/// Thumbnail for a [JournalImage] inside a list card.
///
/// Loads the image file at a fixed `height` and uses [FileWatcherMixin] so the
/// thumbnail refreshes if the underlying file changes on disk (e.g. after a
/// sync/import). While the file is still missing, an image that carries a
/// ThumbHash shows its blurred stand-in in the same box; one that does not
/// takes no space at all.
class CardImageWidget extends StatefulWidget {
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
  State<CardImageWidget> createState() => _CardImageWidgetState();
}

class _CardImageWidgetState extends State<CardImageWidget>
    with FileWatcherMixin {
  @override
  void didUpdateWidget(CardImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journalImage.id != widget.journalImage.id) {
      resetFileWatcher();
    }
  }

  @override
  void dispose() {
    disposeFileWatcher();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = getFullImagePath(widget.journalImage);
    setupFileWatcher(path);
    final thumbHash = ThumbHash.tryParse(widget.journalImage.data.thumbHash);

    if (!fileExists && thumbHash == null) {
      return const SizedBox.shrink();
    }

    final size = widget.height.toDouble();
    ImageProvider? imageProvider;
    if (fileExists) {
      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
      final cap = size > 0
          ? (size * devicePixelRatio).round().clamp(1, 10000)
          : null;
      final fileImage = FileImage(File(path));
      // Use ResizeImage.fit so capping both axes preserves aspect ratio
      // instead of squashing non-square source images into a square decode.
      imageProvider = cap == null
          ? fileImage
          : ResizeImage(
              fileImage,
              width: cap,
              height: cap,
              policy: ResizeImagePolicy.fit,
            );
    }
    return SizedBox(
      width: size,
      height: size,
      child: ThumbHashBackedImage(
        key: ValueKey(path),
        thumbHash: thumbHash,
        image: imageProvider,
        fit: widget.fit,
      ),
    );
  }
}
