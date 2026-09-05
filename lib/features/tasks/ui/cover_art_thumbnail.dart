import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/file_watcher_mixin.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/thumbhash.dart';
import 'package:lotti/widgets/media/thumb_hash_backed_image.dart';
import 'package:material_ui/material_ui.dart';

/// Thumbnail widget for displaying task cover art.
///
/// Before the image file is on disk — a demo cover still downloading, AI
/// cover art still being written — the square shows the image's ThumbHash
/// stand-in when it has one, and stays empty when it does not; the file
/// watcher then swaps the picture in with a fade.
class CoverArtThumbnail extends ConsumerStatefulWidget {
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
  ConsumerState<CoverArtThumbnail> createState() => _CoverArtThumbnailState();
}

class _CoverArtThumbnailState extends ConsumerState<CoverArtThumbnail>
    with FileWatcherMixin {
  @override
  void didUpdateWidget(CoverArtThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) {
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
    final provider = entryControllerProvider(widget.imageId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    final path = getFullImagePath(entry);
    setupFileWatcher(path);
    final thumbHash = ThumbHash.tryParse(entry.data.thumbHash);

    if (!fileExists && thumbHash == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    ImageProvider? imageProvider;
    if (fileExists) {
      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
      final cap = widget.size > 0
          ? (widget.size * devicePixelRatio).round().clamp(1, 10000)
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

    final alignmentX = (widget.cropX * 2) - 1;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ThumbHashBackedImage(
        key: ValueKey(path),
        thumbHash: thumbHash,
        image: imageProvider,
        alignment: Alignment(alignmentX, 0),
      ),
    );
  }
}
