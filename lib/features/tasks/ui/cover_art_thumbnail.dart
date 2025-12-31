import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';

/// Thumbnail widget for displaying task cover art.
///
/// Handles smart cropping:
/// - Wide images (aspect ratio > 1.1): Applies horizontal crop using cropX offset
/// - Square/tall images: Displays centered without horizontal cropping
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
  /// Only used for wide images.
  final double cropX;

  @override
  ConsumerState<CoverArtThumbnail> createState() => _CoverArtThumbnailState();
}

class _CoverArtThumbnailState extends ConsumerState<CoverArtThumbnail> {
  int retries = 0;

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(id: widget.imageId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    final file = File(getFullImagePath(entry));

    if (!isTestEnv && retries < 10 && !file.existsSync()) {
      Future<void>.delayed(const Duration(milliseconds: 200)).then((_) {
        if (mounted) {
          setState(() {
            retries++;
          });
        }
      });
    }

    if (!file.existsSync()) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    // Convert cropX (0.0-1.0) to alignment (-1.0 to 1.0)
    // 0.0 -> -1.0 (left), 0.5 -> 0.0 (center), 1.0 -> 1.0 (right)
    final alignmentX = (widget.cropX * 2) - 1;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment(alignmentX, 0),
          child: Image.file(
            file,
            key: Key('${file.path}-$retries'),
            cacheHeight: (widget.size * 3).toInt(),
          ),
        ),
      ),
    );
  }
}
