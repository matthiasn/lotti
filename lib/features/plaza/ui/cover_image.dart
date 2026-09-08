/// A task's cover art on a plaza surface, with one callback once the
/// picture has landed or failed, so the surface's texture can be captured
/// again: a network image decodes after the first capture.
library;

import 'dart:io';

import 'package:lotti/features/tasks/ui/file_watcher_mixin.dart';
import 'package:material_ui/material_ui.dart';

class CoverImage extends StatefulWidget {
  const CoverImage({
    required this.url,
    this.opacity = 1,
    this.onLoaded,
    super.key,
  });

  final String url;

  /// Dimmed on a finished shop.
  final double opacity;

  /// Called once, after the frame that paints the decoded image (or the
  /// error fallback), and again when a missing local file arrives or [url]
  /// changes.
  final VoidCallback? onLoaded;

  @override
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage>
    with FileWatcherMixin<CoverImage> {
  bool _notified = false;
  bool _waitingForFile = false;
  int _revision = 0;

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _notified = false;
      _waitingForFile = false;
      disposeFileWatcher();
    }
  }

  @override
  void dispose() {
    disposeFileWatcher();
    super.dispose();
  }

  void _loaded() {
    if (_notified || widget.onLoaded == null) return;
    _notified = true;
    // Capture after this frame paints the decoded image (or the fallback).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoaded?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(widget.url);
    final file = uri?.scheme == 'file' ? File.fromUri(uri!) : null;
    if (_waitingForFile && fileExists) {
      _waitingForFile = false;
      _notified = false;
      _revision++;
      disposeFileWatcher();
    }
    return Opacity(
      opacity: widget.opacity,
      child: Image(
        key: ValueKey((widget.url, _revision)),
        image: file != null ? FileImage(file) : NetworkImage(widget.url),
        width: double.infinity,
        fit: BoxFit.cover,
        frameBuilder: (_, child, frame, _) {
          if (frame != null) _loaded();
          return child;
        },
        errorBuilder: (_, _, _) {
          if (file != null && !file.existsSync()) {
            // A live failed completer can otherwise win the next lookup even
            // after the file arrives and a fresh Image widget is mounted.
            PaintingBinding.instance.imageCache.evict(FileImage(file));
            _waitingForFile = true;
            setupFileWatcher(file.path);
          }
          _loaded();
          return const SizedBox();
        },
      ),
    );
  }
}
