/// A task's cover art on a plaza surface, with one callback once the
/// picture has landed or failed, so the surface's texture can be captured
/// again: a network image decodes after the first capture.
library;

import 'package:flutter/material.dart';

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
  /// error fallback), and again only for a new [url].
  final VoidCallback? onLoaded;

  @override
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  bool _notified = false;

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _notified = false;
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
    return Opacity(
      opacity: widget.opacity,
      child: Image.network(
        widget.url,
        width: double.infinity,
        fit: BoxFit.cover,
        frameBuilder: (_, child, frame, _) {
          if (frame != null) _loaded();
          return child;
        },
        errorBuilder: (_, _, _) {
          _loaded();
          return const SizedBox();
        },
      ),
    );
  }
}
