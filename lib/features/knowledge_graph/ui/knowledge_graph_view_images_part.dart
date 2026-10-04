part of 'knowledge_graph_view.dart';

/// Thumbnail loading for the graph canvas: request, drain, decode and dispose. The state write that installs decoded images stays in the State (the repo's extension-split rule).
extension _KnowledgeGraphImages on _KnowledgeGraphViewState {
  void _requestImageLoad(GraphVisualSpec visualSpec) {
    final targetExtent =
        (visualSpec.mediaDecodeLogicalExtent *
                MediaQuery.devicePixelRatioOf(context))
            .ceil();
    if (targetExtent <= _requestedImageTargetExtent) return;
    _requestedImageTargetExtent = targetExtent;
    if (!_imageLoadActive) {
      unawaited(_drainImageLoads());
    }
  }

  /// Decode task covers, entry images, and aggregate thumbnails off the main
  /// work. Larger requests are serialized and replace existing thumbnails only
  /// after the new batch is ready.
  Future<void> _drainImageLoads() async {
    _imageLoadActive = true;
    try {
      while (mounted &&
          _loadedImageTargetExtent < _requestedImageTargetExtent) {
        final targetExtent = _requestedImageTargetExtent;
        final loaded = await _loadImages(targetExtent);
        if (!mounted) {
          _disposeImages(loaded.images.values, retained: _images.values);
          return;
        }
        _installImages(
          loaded.images,
          loaded.signatures,
          loaded.evictions,
          targetExtent,
        );
        _loadedImageTargetExtent = targetExtent;
      }
    } finally {
      _imageLoadActive = false;
    }
  }

  Set<String> _scenarioImagePaths() => {
    for (final node in _scenario.nodes) ...[
      if (node.imagePath case final path? when path.isNotEmpty) path,
      if (node.coverImagePath case final path? when path.isNotEmpty) path,
      ...node.mediaPaths.where((path) => path.isNotEmpty),
    ],
  };

  Future<
    ({
      Map<String, ui.Image> images,
      Map<String, String?> signatures,
      Set<String> evictions,
    })
  >
  _loadImages(int targetExtent) async {
    final loaded = <String, ui.Image>{};
    final signatures = <String, String?>{};
    final evictions = <String>{};
    final loadImage = widget.imageLoader ?? decodeGraphImageFile;
    for (final path in _scenarioImagePaths()) {
      // Cached thumbnails survive remounts via the shared cache — only decode
      // what is missing, too small for the current device-pixel target, or
      // whose source file changed since it was decoded. An unavailable
      // signature falls back to the extent-only check (test loaders use
      // synthetic paths), EXCEPT when the entry was decoded from a real file
      // (it has a signature) and that file is now gone — then the entry is
      // evicted so a deleted photo falls back to the type glyph instead of
      // rendering its stale thumbnail forever.
      final signature = _KnowledgeGraphViewState._fileSignatureOf(path);
      if (signature == null && _thumbnails.signatureOf(path) != null) {
        evictions.add(path);
      } else {
        final cachedFresh =
            _thumbnails.decodedExtentOf(path) >= targetExtent &&
            (signature == null || signature == _thumbnails.signatureOf(path));
        if (cachedFresh) continue;
      }
      try {
        final image = await loadImage(path, targetExtent);
        if (!mounted) {
          // Disposed mid-decode — release what we decoded and bail.
          // coverage:ignore-start
          _disposeImages(
            [...loaded.values, image],
            retained: _images.values,
          );
          return (
            images: const <String, ui.Image>{},
            signatures: const <String, String?>{},
            evictions: const <String>{},
          );
          // coverage:ignore-end
        }
        loaded[path] = image;
        signatures[path] = signature;
      } on Object {
        // Missing/unreadable file — fall back to the type glyph.
      }
    }
    return (images: loaded, signatures: signatures, evictions: evictions);
  }

  void _disposeImages(
    Iterable<ui.Image> images, {
    Iterable<ui.Image> retained = const [],
  }) {
    final disposed = <ui.Image>[];
    for (final image in images) {
      final shouldDispose =
          !retained.any((candidate) => identical(candidate, image)) &&
          !disposed.any((candidate) => identical(candidate, image));
      if (shouldDispose) {
        image.dispose();
        disposed.add(image);
      }
    }
  }
}
