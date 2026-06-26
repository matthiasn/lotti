import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/file_watcher_mixin.dart';
import 'package:lotti/utils/image_utils.dart';

/// Background widget for displaying task cover art in SliverAppBar.
class CoverArtBackground extends ConsumerStatefulWidget {
  const CoverArtBackground({
    required this.imageId,
    super.key,
  });

  final String imageId;

  @override
  ConsumerState<CoverArtBackground> createState() => _CoverArtBackgroundState();
}

class _CoverArtBackgroundState extends ConsumerState<CoverArtBackground>
    with FileWatcherMixin {
  @override
  void didUpdateWidget(CoverArtBackground oldWidget) {
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
      return const SizedBox.shrink();
    }

    final path = getFullImagePath(entry);
    setupFileWatcher(path);

    if (!fileExists) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
            // ResizeImage asserts width/height > 0; SliverAppBar collapse
            // can briefly drive the constraint to 0 mid-animation, so guard
            // and clamp the rounded value to a sensible band. Use
            // ResizeImagePolicy.fit so capping both axes preserves the
            // source aspect ratio instead of squashing the bitmap.
            final cacheWidth =
                constraints.hasBoundedWidth && constraints.maxWidth > 0
                ? (constraints.maxWidth * devicePixelRatio).round().clamp(
                    1,
                    10000,
                  )
                : null;
            final cacheHeight =
                constraints.hasBoundedHeight && constraints.maxHeight > 0
                ? (constraints.maxHeight * devicePixelRatio).round().clamp(
                    1,
                    10000,
                  )
                : null;
            final fileImage = FileImage(File(path));
            ImageProvider imageProvider = fileImage;
            if (cacheWidth != null || cacheHeight != null) {
              imageProvider = ResizeImage(
                fileImage,
                width: cacheWidth,
                height: cacheHeight,
                policy: ResizeImagePolicy.fit,
              );
            }
            return Image(
              image: imageProvider,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                // Evict the actual provider (ResizeImage or bare FileImage)
                // — ResizeImageKey includes dimensions + policy so a fresh
                // FileImage would miss the cache entry.
                imageCache.evict(imageProvider);
                return const SizedBox.shrink();
              },
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Color(0x99000000),
                Colors.transparent,
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ],
    );
  }
}
