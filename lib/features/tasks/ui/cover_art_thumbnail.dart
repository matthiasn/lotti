import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/file_watcher_mixin.dart';
import 'package:lotti/utils/image_utils.dart';

/// Thumbnail widget for displaying task cover art.
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
    final provider = entryControllerProvider(id: widget.imageId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    final path = getFullImagePath(entry);
    setupFileWatcher(path);

    if (!fileExists) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    final alignmentX = (widget.cropX * 2) - 1;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment(alignmentX, 0),
          child: Image.file(
            File(path),
            cacheHeight: (widget.size * 3).toInt(),
          ),
        ),
      ),
    );
  }
}
