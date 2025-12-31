import 'dart:async';
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
  StreamSubscription<FileSystemEvent>? _watcher;
  String? _watchedPath;
  bool _fileExists = false;

  void _setupWatcher(String path) {
    // Skip in tests where file watching isn't needed
    if (isTestEnv) {
      _fileExists = File(path).existsSync();
      return;
    }

    // Already watching this path
    if (_watchedPath == path) return;

    // Clean up previous watcher
    _watcher?.cancel();
    _watcher = null;
    _watchedPath = path;

    final file = File(path);
    if (file.existsSync()) {
      _fileExists = true;
      return;
    }

    _fileExists = false;

    // Watch parent directory for file creation
    final dir = file.parent;
    if (!dir.existsSync()) return;

    _watcher = dir.watch().listen((event) {
      if (event.path == path && mounted) {
        _watcher?.cancel();
        _watcher = null;
        setState(() => _fileExists = true);
      }
    });
  }

  @override
  void didUpdateWidget(CoverArtThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) {
      _watchedPath = null; // Force re-setup on next build
    }
  }

  @override
  void dispose() {
    _watcher?.cancel();
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
    _setupWatcher(path);

    if (!_fileExists) {
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
            File(path),
            cacheHeight: (widget.size * 3).toInt(),
          ),
        ),
      ),
    );
  }
}
